-module (comments_api).
-export ([create_comment/1, delete_comment/1, edit_comment/1, vote_comment/1]).

-spec create_comment(errm_http:request()) -> {ok, errm_http:response()}.
create_comment(Req) ->
  Params = maps:get(params, Req, #{}),
  PostId = maps:get(<<"post_id">>, Params, undefined),
  case bin_to_int(PostId) of
    IntId when is_integer(IntId) ->
      case validate_comment_request(Req) of
        {error, Status, Message} ->
          response_utils:error(Status, Message);
        {ok, Username, ContentMarkdown, ParentId} ->
          insert_comment(IntId, Username, ContentMarkdown, ParentId)
      end;
    I ->
      logger:error("Invalid post id: ~p", [I]),
      response_utils:error(400, "Invalid post id")
  end.

-spec delete_comment(errm_http:request()) -> {ok, errm_http:response()}.
delete_comment(Req) ->
  Params = maps:get(params, Req, #{}),
  CommentId = maps:get(<<"comment_id">>, Params, undefined),
  PostId = maps:get(<<"post_id">>, Params, undefined),

  case {CommentId, PostId} of
    {undefined, undefined} -> response_utils:error(400, "No comment id or post id provided");
    {undefined, _} -> response_utils:error(400, "No comment id provided");
    {_, undefined} -> response_utils:error(400, "No post id provided");
    {CId, PId} when is_binary(CId), is_binary(PId) ->
      case {bin_to_int(CId), bin_to_int(PId)} of
        {{error, _},   {error, _}}                           -> response_utils:error(400, "Invalid post_id, and comment id");
        {{error, _},   IntPId} when is_integer(IntPId) -> response_utils:error(400, "Invalid comment id");
        {{error, _},   _}                                    -> response_utils:error(400, "Invalid post id");
        {IntCId, IntPId} when is_integer(IntCId), is_integer(IntPId) ->
          case blog_middlewares:is_admin(Req) of
            true ->
              {Username, Content} = blog_notifications:delete_identity(Req),
              sql_delete_comment(IntPId, IntCId, Username, Content);
            false -> response_utils:error(401, "Unauthorized")
          end
      end
  end.

-spec edit_comment(errm_http:request()) -> {ok, errm_http:response()}.
edit_comment(Req) ->
  Params = maps:get(params, Req, #{}),
  CommentId = maps:get(<<"comment_id">>, Params, undefined),
  PostId = maps:get(<<"post_id">>, Params, undefined),

  case {CommentId, PostId} of
    {undefined, undefined} -> response_utils:error(400, "No comment id or post id provided");
    {undefined, _} -> response_utils:error(400, "No comment id provided");
    {_, undefined} -> response_utils:error(400, "No post id provided");
    {CId, PId} when is_binary(CId), is_binary(PId) ->
      case {bin_to_int(CId), bin_to_int(PId)} of
        {{error, _},   {error, _}}                           -> response_utils:error(400, "Invalid comment id, and post id");
        {{error, _},   IntPId} when is_integer(IntPId) -> response_utils:error(400, "Invalid comment id");
        {{error, _},   _}                                    -> response_utils:error(400, "Invalid post id");
        {IntCId, IntPId} when is_integer(IntCId), is_integer(IntPId) ->
          case blog_middlewares:is_admin(Req) of
            true -> handle_update(Req, IntPId, IntCId);
            false -> response_utils:error(401, "Unauthorized")
          end
      end
  end.

-spec vote_comment(errm_http:request()) -> {ok, errm_http:response()}.
vote_comment(Req) ->
  Params = maps:get(params, Req, #{}),
  CommentId = maps:get(<<"comment_id">>, Params, undefined),
  PostId = maps:get(<<"post_id">>, Params, undefined),
  case {bin_to_int(CommentId), bin_to_int(PostId)} of
    {IntCId, IntPId} when is_integer(IntCId), is_integer(IntPId) ->
      sql_vote_comment(IntPId, IntCId, blog_ip:client_ip(Req));
    _ ->
      response_utils:error(400, "Invalid comment or post id")
  end.

validate_comment_request(Req) ->
  case maps:get(headers, Req, #{}) of
    #{<<"content-type">> := <<"application/json">>} ->
      case maps:get(body, Req, <<>>) of
        <<>> -> {error, 400, "No body provided"};
        Body ->
          case errm_json:decode(Body) of
            {ok, Data} when is_map(Data) ->
              Username = maps:get(<<"username">>, Data, undefined),
              ContentMarkdown = maps:get(<<"content_markdown">>, Data, undefined),
              ParentId = maps:get(<<"parent_id">>, Data, null),
              case {Username, ContentMarkdown} of
                {undefined, _} -> {error, 400, "No username provided"};
                {_, undefined} -> {error, 400, "No content provided"};
                {U, C} when is_binary(U), is_binary(C) ->
                  validate_lengths(U, C, ParentId);
                _ -> {error, 400, "Invalid JSON fields"}
              end;
            {error, Reason} ->
              logger:error("Error reading json: ~p", [Reason]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ -> {error, 400, "Invalid content type"}
  end.

handle_update(Req, PostId, CommentId) ->
  case validate_comment_request(Req) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    {ok, Username, ContentMarkdown, _ParentId} ->
      sql_update_comment(PostId, Username, ContentMarkdown, CommentId)
  end.

insert_comment(PostId, Username, ContentMarkdown, ParentId) ->
  case sql_check_post_exists(PostId) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    ok ->
      case resolve_parent(PostId, ParentId) of
        {error, Status, Message} ->
          response_utils:error(Status, Message);
        {ok, Parent} ->
          case blog_db:db() of
            {error, Reason} ->
              logger:error("Database open failed: ~p", [Reason]),
              response_utils:error(500, "Database error");
            {ok, Db} ->
              SanitizedUsername = blog_filter:sanitize(Username, <<"comments">>),
              SanitizedContent = blog_filter:sanitize(ContentMarkdown, <<"comments">>),
              Now = erlang:system_time(second),
              Sql = "INSERT INTO post_comments (post_id, parent_id, username, content_markdown, posted_at) VALUES (?, ?, ?, ?, ?)",
              Params = [PostId, Parent, SanitizedUsername, SanitizedContent, Now],
              case errm_sqlite:query(Db, Sql, Params) of
                {ok, _} ->
                  {ok, LastId} = errm_sqlite_nif:last_insert_rowid(Db),
                  blog_ws_broadcast:comment(created, SanitizedUsername, SanitizedContent, integer_to_binary(LastId), integer_to_binary(PostId), integer_to_binary(Now), parent_bin(Parent)),
                  blog_notifications:record(<<"comment">>, <<"created">>, SanitizedUsername, SanitizedContent, integer_to_binary(PostId), blog_notifications:comment_target(integer_to_binary(PostId), integer_to_binary(LastId))),
                  response_utils:ok(#{message => <<"Comment created successfully">>, id => LastId});
                {error, Reason1} ->
                  logger:error("Error creating comment: ~p", [Reason1]),
                  response_utils:error(500, "Couldn't create comment due to database error")
              end
          end
      end
  end.

resolve_parent(_PostId, null) -> {ok, null};
resolve_parent(_PostId, undefined) -> {ok, null};
resolve_parent(PostId, ParentId) ->
  case bin_to_int(ParentId) of
    {error, invalid} -> {error, 400, "Invalid parent id"};
    IntId when is_integer(IntId) ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed: ~p", [Reason]),
          {error, 500, "Database error"};
        {ok, Db} ->
          case errm_sqlite:query(Db, "SELECT id FROM post_comments WHERE id = ? AND post_id = ? LIMIT 1", [IntId, PostId]) of
            {ok, []} -> {error, 404, "Parent comment not found"};
            {ok, _} -> {ok, IntId};
            {error, Reason1} ->
              logger:error("Error fetching parent comment: ~p", [Reason1]),
              {error, 500, "Database error"}
          end
      end
  end.

parent_bin(null) -> null;
parent_bin(Int) when is_integer(Int) -> integer_to_binary(Int).

sql_check_post_exists(PostId) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      {error, 500, "Database error"};
    {ok, Db} ->
      case errm_sqlite:query(Db, "SELECT id FROM posts WHERE id = ? LIMIT 1", [PostId]) of
        {ok, []} -> {error, 404, "Post not found"};
        {ok, _} -> ok;
        {error, Reason1} ->
          logger:error("Error fetching post: ~p", [Reason1]),
          {error, 500, "Database error"}
      end
  end.

sql_update_comment(PostId, Username, ContentMarkdown, CommentId) ->
  case sql_check_post_exists(PostId) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    ok ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed: ~p", [Reason]),
          response_utils:error(500, "Database error");
        {ok, Db} ->
          SanitizedContent = blog_filter:sanitize(ContentMarkdown, <<"comments">>),
          Now = erlang:system_time(second),
          Sql = "UPDATE post_comments SET content_markdown = ?, edited_at = ? WHERE post_id = ? AND id = ? AND username = ?",
          Params = [SanitizedContent, Now, PostId, CommentId, Username],
          case errm_sqlite:query(Db, Sql, Params) of
            {ok, []} ->
              blog_ws_broadcast:comment(edited, Username, SanitizedContent, integer_to_binary(CommentId), integer_to_binary(PostId), integer_to_binary(Now)),
              blog_notifications:record(<<"comment">>, <<"edited">>, Username, SanitizedContent, integer_to_binary(PostId), blog_notifications:comment_target(integer_to_binary(PostId), integer_to_binary(CommentId))),
              response_utils:ok(#{message => <<"Comment updated successfully">>, id => CommentId});
            {error, Reason1} ->
              logger:error("Error updating comment: ~p", [Reason1]),
              response_utils:error(500, "Couldn't update comment due to database error")
          end
      end
  end.

sql_delete_comment(PostId, CommentId, Username, Content) ->
  case sql_check_post_exists(PostId) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    ok ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed: ~p", [Reason]),
          response_utils:error(500, "Database error");
        {ok, Db} ->
          case sql_delete_comment_tree(Db, PostId, CommentId) of
            ok ->
              blog_ws_broadcast:comment_delete(integer_to_binary(CommentId), integer_to_binary(PostId), Username, Content),
              blog_notifications:record(<<"comment">>, <<"deleted">>, Username, Content, integer_to_binary(PostId), blog_notifications:comment_target(integer_to_binary(PostId), integer_to_binary(CommentId))),
              {ok, {204, #{}, <<>>}};
            {error, Reason1} ->
              logger:error("Error deleting comment: ~p", [Reason1]),
              response_utils:error(500, "Couldn't delete comment due to database error")
          end
      end
  end.

sql_delete_comment_tree(Db, PostId, CommentId) ->
  Tree = "WITH RECURSIVE tree(id) AS (SELECT id FROM post_comments WHERE id = ? AND post_id = ? UNION ALL SELECT c.id FROM post_comments c JOIN tree t ON c.parent_id = t.id) SELECT id FROM tree",
  case errm_sqlite:exec(Db, "DELETE FROM comment_votes WHERE comment_id IN (" ++ Tree ++ ")", [CommentId, PostId]) of
    {ok, _} ->
      case errm_sqlite:exec(Db, "DELETE FROM post_comments WHERE id IN (" ++ Tree ++ ")", [CommentId, PostId]) of
        {ok, _} -> ok;
        {error, Reason} -> {error, Reason}
      end;
    {error, Reason} -> {error, Reason}
  end.

sql_vote_comment(PostId, CommentId, Ip) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      case errm_sqlite:query(Db, "SELECT id FROM post_comments WHERE id = ? AND post_id = ? LIMIT 1", [CommentId, PostId]) of
        {ok, []} ->
          response_utils:error(404, "Comment not found");
        {ok, _} ->
          case errm_sqlite:exec(Db, "INSERT OR IGNORE INTO comment_votes (comment_id, ip) VALUES (?, ?)", [CommentId, Ip]) of
            {ok, 1} ->
              {ok, _} = errm_sqlite:exec(Db, "UPDATE post_comments SET votes = votes + 1 WHERE id = ?", [CommentId]),
              vote_response(Db, PostId, CommentId);
            {ok, 0} ->
              vote_response(Db, PostId, CommentId);
            {error, Reason1} ->
              logger:error("Error voting comment: ~p", [Reason1]),
              response_utils:error(500, "Couldn't vote due to database error")
          end;
        {error, Reason1} ->
          logger:error("Error fetching comment: ~p", [Reason1]),
          response_utils:error(500, "Database error")
      end
  end.

vote_response(Db, PostId, CommentId) ->
  case errm_sqlite:query(Db, "SELECT votes FROM post_comments WHERE id = ?", [CommentId]) of
    {ok, [Row | _]} ->
      Votes = votes_of(Row),
      blog_ws_broadcast:comment_vote(integer_to_binary(CommentId), integer_to_binary(PostId), Votes),
      response_utils:ok(#{votes => Votes});
    _ ->
      response_utils:error(500, "Database error")
  end.

bin_to_int(Bin) when is_binary(Bin) ->
  try binary_to_integer(Bin) catch error:badarg -> {error, invalid} end;
bin_to_int(Int) when is_integer(Int) ->
    Int;
bin_to_int(Str) when is_list(Str) ->
  try list_to_integer(Str) catch error:badarg -> {error, invalid} end;
bin_to_int(_) ->
  {error, invalid}.

validate_lengths(U, C, ParentId) when is_binary(U), is_binary(C) ->
  case string:length(U) > 32 of
    true -> {error, 400, "Username too long (max 32 characters)"};
    false ->
      case string:length(C) > 800 of
        true -> {error, 400, "Content too long (max 800 characters)"};
        false -> {ok, U, C, ParentId}
      end
  end.

votes_of(Row) ->
  case maps:get("votes", Row, 0) of
    V when is_integer(V) -> V;
    _ -> 0
  end.
