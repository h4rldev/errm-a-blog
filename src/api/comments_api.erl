-module (comments_api).
-export ([create_comment/1, delete_comment/1, edit_comment/1]).

-spec create_comment(errm_http:request()) -> {ok, errm_http:response()}.
create_comment(Req) ->
  Params = maps:get(params, Req, #{}),
  PostId = maps:get(<<"post_id">>, Params, undefined),
  case bin_to_int(PostId) of
    {IntId, []} when is_integer(IntId) ->
      case validate_comment_request(Req) of
        {error, Status, Message} ->
          response_utils:error(Status, Message);
        {ok, PostId, Username, ContentMarkdown} ->
          insert_comment(IntId, Username, ContentMarkdown)
      end;
    _ ->
      response_utils:error(400, "Invalid post id")
  end.

-spec delete_comment(errm_http:request()) -> {ok, errm_http:response()}.
delete_comment(Req) ->
  case blog_middlewares:get_claims(Req) of
    undefined -> response_utils:error(401, "Unauthorized");
    Claims ->
      Params = maps:get(params, Req, #{}),
      CommentId = maps:get(<<"comment_id">>, Params, undefined),
      PostId = maps:get(<<"post_id">>, Params, undefined),
      Role = maps:get(<<"role">>, Claims, undefined),

      case {CommentId, PostId} of
        {undefined, undefined} -> response_utils:error(400, "No comment id or post id provided");
        {undefined, _} -> response_utils:error(400, "No comment id provided");
        {_, undefined} -> response_utils:error(400, "No post id provided");
        {CId, PId} when is_binary(CId), is_binary(PId) ->
          case {bin_to_int(CId), bin_to_int(PId)} of
            {{error, _},   {error, _}}                           -> response_utils:error(400, "Invalid post_id, and comment id");
            {{error, _},   {IntPId, []}} when is_integer(IntPId) -> response_utils:error(400, "Invalid comment id");
            {{error, _},   _}                                    -> response_utils:error(400, "Invalid post id");
            {{IntCId, []}, {IntPId, []}} when is_integer(IntCId), is_integer(IntPId) -> 
              case verify_claims(Role) of
                ok -> sql_delete_comment(IntPId, IntCId);
                {error, Status, Message} -> response_utils:error(Status, Message)
              end
          end
      end
  end.


-spec edit_comment(errm_http:request()) -> {ok, errm_http:response()}.
edit_comment(Req) ->
  case blog_middlewares:get_claims(Req) of
    undefined -> response_utils:error(401, "Unauthorized");
    Claims ->
      Params = maps:get(params, Req, #{}),
      CommentId = maps:get(<<"comment_id">>, Params, undefined),
      PostId = maps:get(<<"post_id">>, Params, undefined),
      Role = maps:get(<<"role">>, Claims, undefined),

      case {CommentId, PostId} of
        {undefined, undefined} -> response_utils:error(400, "No comment id or post id provided");
        {undefined, _} -> response_utils:error(400, "No comment id provided");
        {_, undefined} -> response_utils:error(400, "No post id provided");
        {CId, PId} when is_binary(CId), is_binary(PId) ->
          case {bin_to_int(CId), bin_to_int(PId)} of
            {{error, _},   {error, _}}                           -> response_utils:error(400, "Invalid comment id, and post id");
            {{error, _},   {IntPId, []}} when is_integer(IntPId) -> response_utils:error(400, "Invalid comment id");
            {{error, _},   _}                                    -> response_utils:error(400, "Invalid post id");
            {{IntCId, []}, {IntPId, []}} when is_integer(IntCId), is_integer(IntPId) ->
              case verify_claims(Role) of
                ok -> handle_update(Req, IntPId, IntCId);
                {error, Status, Message} -> response_utils:error(Status, Message)
              end
          end
      end
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
              case {Username, ContentMarkdown} of
                {undefined, _} -> {error, 400, "No username provided"};
                {_, undefined} -> {error, 400, "No content provided"};
                {U, C} when is_binary(U), is_binary(C) ->
                  {ok, U, C};
                _ -> {error, 400, "Invalid JSON fields"}
              end;
            {error, Reason} ->
              logger:error("Error reading json: ~p", [Reason]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ -> {error, 400, "Invalid content type"}
  end.


verify_claims(Role) ->
  case Role of
    undefined                 -> {error, 401, "Unauthorized"};
    <<"super-administrator">> -> ok;
    <<"administrator">>       -> ok;
    _                         -> {error, 401, "Unauthorized"}
  end.


handle_update(Req, PostId, CommentId) ->
  case validate_update_body(Req) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    {ok, Username, ContentMarkdown} ->
      sql_update_comment(PostId, Username, ContentMarkdown, CommentId)
  end.


validate_update_body(Req) ->
  case maps:get(headers, Req, #{}) of
    #{<<"content-type">> := <<"application/json">>} ->
      case maps:get(body, Req, <<>>) of
        <<>> -> {error, 400, "No body provided"};
        Body ->
          case errm_json:decode(Body) of
            {ok, Data} when is_map(Data) ->
              Username = maps:get(<<"username">>, Data, undefined),
              ContentMarkdown = maps:get(<<"content_markdown">>, Data, undefined),
              case {Username, ContentMarkdown} of
                {undefined, _} -> {error, 400, "No title provided"};
                {_, undefined} -> {error, 400, "No content provided"};
                {U, C} when is_binary(U), is_binary(C) ->
                  {ok, U, C};
                _ -> {error, 400, "Invalid JSON fields"}
              end;
            {error, Reason} ->
              logger:error("Error reading json: ~p", [Reason]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ -> {error, 400, "Invalid content type"}
  end.


insert_comment(PostId, Username, ContentMarkdown) ->
  case sql_check_post_exists(PostId) of
    ok ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed: ~p", [Reason]),
          response_utils:error(500, "Database error");
        {ok, Db} ->
          Now = erlang:system_time(second),
          Sql = "INSERT INTO post_comments (post_id, username, content_markdown, posted_at) VALUES (?, ?, ?, ?)",
          Params = [PostId, Username, ContentMarkdown, Now],
          case errm_sqlite:query(Db, Sql, Params) of
            {ok, _} ->
              {ok, LastId} = errm_sqlite_nif:last_insert_rowid(Db),
              blog_ws_broadcast:comment(created, Username, ContentMarkdown, integer_to_binary(LastId), integer_to_binary(PostId), integer_to_binary(Now)),
              response_utils:ok(#{message => <<"Comment created successfully">>, id => LastId});
            {error, Reason1} ->
              logger:error("Error creating comment: ~p", [Reason1]),
              response_utils:error(500, "Couldn't create comment due to database error")
          end
      end;
    {error, Status, Message} ->
      response_utils:error(Status, Message)
  end.

sql_check_post_exists(PostId) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      {error, 500, "Database error"};
    {ok, Db} ->
      Sql = "SELECT id FROM posts WHERE id = ? LIMIT 1",
      Params = [PostId],

      case errm_sqlite:query(Db, Sql, Params) of
        {ok, []} -> {error, 404, "Post not found"};
        {ok, _} -> ok;
        {error, Reason1} ->
          logger:error("Error fetching post: ~p", [Reason1]),
          {error, 500, "Database error"}
      end
  end.


sql_update_comment(PostId, Username, ContentMarkdown, CommentId) ->
  case sql_check_post_exists(PostId) of
    ok ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed: ~p", [Reason]),
          response_utils:error(500, "Database error");
        {ok, Db} ->
          Now = erlang:system_time(second),
          Sql = "UPDATE post_comments SET content_markdown = ?, last_edited_at = ? WHERE post_id = ? AND id = ? AND username = ?",
          Params = [ContentMarkdown, Now, PostId, CommentId, Username],
          case errm_sqlite:query(Db, Sql, Params) of
            {ok, []} ->
              blog_ws_broadcast:comment(edited, Username, ContentMarkdown, integer_to_binary(CommentId), integer_to_binary(PostId), integer_to_binary(Now)),
              response_utils:ok(#{message => <<"Comment updated successfully">>, id => CommentId});
            {error, Reason1} ->
              logger:error("Error updating comment: ~p", [Reason1]),
              response_utils:error(500, "Couldn't update comment due to database error")
          end
      end;
    {error, Status, Message} ->
      response_utils:error(Status, Message)
  end.


sql_delete_comment(PostId, CommentId) ->
  case sql_check_post_exists(PostId) of
    ok ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed: ~p", [Reason]),
          response_utils:error(500, "Database error");
        {ok, Db} ->
          Sql = "DELETE FROM post_comments WHERE post_id = ? AND id = ?",
          Params = [PostId, CommentId],
          case errm_sqlite:query(Db, Sql, Params) of
            {ok, []} ->
              blog_ws_broadcast:comment(deleted, <<>>, <<>>, integer_to_binary(CommentId), integer_to_binary(PostId), <<>>),
              {ok, {204, #{}, <<>>}};
            {error, Reason1} ->
              logger:error("Error deleting comment: ~p", [Reason1]),
              response_utils:error(500, "Couldn't delete comment due to database error");
            _ -> response_utils:error(500, "Couldn't find comment to delete")
          end
      end;
    {error, Status, Message} ->
      response_utils:error(Status, Message)
  end.


bin_to_int(Bin) when is_binary(Bin) ->
  binary_to_integer(Bin);
bin_to_int(Int) when is_integer(Int) ->
    Int;
bin_to_int(Str) when is_list(Str) ->
  list_to_integer(Str).
