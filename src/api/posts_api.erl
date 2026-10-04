-module(posts_api).
-export([get_all_posts/1, get_post/1, create_post/1, update_post/1, delete_post/1, get_tags/1]).

-define(POST_ORDER, [id, slug, title, summary, content_markdown, tags, edited_at, posted_at, author]).


-spec get_all_posts(errm_http:request()) -> {ok, errm_http:response()}.
get_all_posts(Req) ->
  Params = maps:get(params, Req, #{}),
  handle_get_posts(to_int(maps:get(<<"amount">>, Params, 10))).

-spec get_post(errm_http:request()) -> {ok, errm_http:response()}.
get_post(Req) ->
  Params = maps:get(params, Req, #{}),
  case maps:get(<<"id">>, Params, undefined) of
    undefined ->
      response_utils:error(400, "No id or slug provided");
    IdBin when is_binary(IdBin) ->
      fetch_post(identifier(IdBin))
  end.

-spec create_post(errm_http:request()) -> {ok, errm_http:response()}.
create_post(Req) ->
  case blog_middlewares:get_user_id(Req) of
    undefined -> 
      logger:error("No user id found"),
      response_utils:error(401, "Unauthorized");
    UserId ->
      case validate_post_request(Req) of
        {error, Status, Message} ->
          response_utils:error(Status, Message);
        {ok, Title, Slug, Summary, ContentMarkdown, Tags} ->
          insert_post(UserId, Title, Slug, Summary, ContentMarkdown, Tags)
      end
  end.

-spec update_post(errm_http:request()) -> {ok, errm_http:response()}.
update_post(Req) ->
  case blog_middlewares:get_user_id(Req) of
    undefined -> response_utils:error(401, "Unauthorized");
    UserId ->
      Params = maps:get(params, Req, #{}),
      case maps:get(<<"id">>, Params, undefined) of
        undefined ->
          response_utils:error(400, "No id or slug provided");
        IdBin when is_binary(IdBin) ->
          handle_update(Req, UserId, identifier(IdBin))
      end
  end.

-spec delete_post(errm_http:request()) -> {ok, errm_http:response()}.
delete_post(Req) ->
  case blog_middlewares:get_user_id(Req) of
    undefined -> response_utils:error(401, "Unauthorized");
    UserId ->
      Params = maps:get(params, Req, #{}),
      case maps:get(<<"id">>, Params, undefined) of
        undefined -> response_utils:error(400, "No id or slug provided");
        IdBin when is_binary(IdBin) ->
          sql_delete_post(UserId, identifier(IdBin))
      end
  end.

-spec get_tags(errm_http:request()) -> {ok, errm_http:response()}.
get_tags(_Req) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      case errm_sqlite:query(Db, "SELECT tags FROM posts WHERE tags IS NOT NULL") of
        {ok, Rows} ->
          AllTags = extract_tags(Rows),
          UniqueTags = deduplicate_tags(AllTags),
          SortedTags = lists:sort(UniqueTags),
          response_utils:ok(#{tags => SortedTags});
        {error, Reason1} ->
          logger:error("Error fetching tags: ~p", [Reason1]),
          response_utils:error(500, "Database error")
      end
  end.

extract_tags(Rows) ->
  [Tag || Row <- Rows, Tag <- tags_of(Row)].

tags_of(Row) ->
  case errm_json:decode(blog_format:value_to_binary(maps:get("tags", Row, <<"[]">>))) of
    {ok, List} when is_list(List) -> List;
    _ -> []
  end.

-spec deduplicate_tags([binary()]) -> [binary()].
deduplicate_tags(Tags) ->
  Map = deduplicate_tags(Tags, #{}),
  maps:values(Map).

-spec deduplicate_tags([binary()], #{binary() => binary()}) -> #{binary() => binary()}.
deduplicate_tags([], Acc) ->
  Acc;
deduplicate_tags([Tag | Rest], Acc) ->
  Lower = string:to_lower(binary_to_list(Tag)),
  case maps:is_key(Lower, Acc) of
    true ->
      deduplicate_tags(Rest, Acc);
    false ->
      deduplicate_tags(Rest, Acc#{list_to_binary(Lower) => Tag})
  end.

handle_get_posts(Amount) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      fetch_posts(Db, Amount)
  end.

fetch_posts(Db, Amount) ->
  case errm_sqlite:query(Db, "SELECT posts.*, users.username, users.role FROM posts JOIN users ON posts.author_id = users.uuid ORDER BY posts.posted_at DESC LIMIT ?", [Amount]) of
    {ok, []} ->
      response_utils:ok(#{<<"amount">> => 0, <<"posts">> => []}, ?POST_ORDER);
    {ok, Rows} ->
      Posts = [blog_format:format_post(Row) || Row <- Rows],
      Response = #{
        <<"amount">> => length(Posts),
        <<"posts">> => Posts
      },
      response_utils:ok(Response, ?POST_ORDER);
    {error, Reason} ->
      logger:error("Error fetching posts: ~p", [Reason]),
      response_utils:error(500, "Database error")
  end.


fetch_post({id, Id}) ->
  run_post_query("WHERE posts.id = ? LIMIT 1", [Id]);
fetch_post({slug, Slug}) ->
  run_post_query("WHERE posts.slug = ? LIMIT 1", [Slug]).

run_post_query(Where, Args) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      Sql = "SELECT posts.*, users.username, users.role FROM posts JOIN users ON posts.author_id = users.uuid " ++ Where,
      case errm_sqlite:query(Db, Sql, Args) of
        {ok, []} -> response_utils:error(404, "Post not found");
        {ok, [Row]} -> response_utils:ok(blog_format:format_post(Row), ?POST_ORDER);
        {error, Reason1} ->
          logger:error("Error fetching post: ~p", [Reason1]),
          response_utils:error(500, "Database error")
      end
  end.


validate_post_request(Req) ->
  case maps:get(headers, Req, #{}) of
    #{<<"content-type">> := <<"application/json">>} ->
      case maps:get(body, Req, <<>>) of
        <<>> -> {error, 400, "No body provided"};
        Body ->
          case errm_json:decode(Body) of
            {ok, Data} when is_map(Data) ->
              Title = maps:get(<<"title">>, Data, undefined),
              Slug = maps:get(<<"slug">>, Data, undefined),
              Summary = maps:get(<<"summary">>, Data, undefined),
              ContentMarkdown = maps:get(<<"content_markdown">>, Data, undefined),
              Tags = maps:get(<<"tags">>, Data, []),

              case {Title, Slug, ContentMarkdown} of
                {undefined, _, _} -> {error, 400, "No title provided"};
                {_, undefined, _} -> {error, 400, "No slug provided"};
                {_, _, undefined} -> {error, 400, "No content provided"};
                {T, S, C} when is_binary(T), is_binary(S), is_binary(C) ->
                  case validate_tags(Tags) of
                    {ok, TagsJson} ->
                      {ok, T, S, Summary, C, TagsJson};
                    {error, Reason} ->
                      {error, 400, Reason}
                  end;
                _ -> {error, 400, "Invalid JSON fields"}
              end;
            {error, Reason} ->
              logger:error("Error reading json: ~p", [Reason]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ ->
      {error, 400, "Invalid content type"}
  end.

validate_tags(Tags) ->
  case is_list(Tags) of
    true ->
      case lists:all(fun(Tag) -> is_binary(Tag) end, Tags) of
        true ->
          Json = errm_json:encode(Tags),
          {ok, iolist_to_binary(Json)};
        false ->
          {error, "Invalid tags, tags must be an array of strings"}
      end;
    false ->
      {error, "Invalid tags, tags must be an array"}
  end.

insert_post(UserId, Title, Slug, Summary, ContentMarkdown, Tags) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      Now = erlang:system_time(second),
      Sql = "INSERT INTO posts (slug, title, summary, content_markdown, author_id, tags, posted_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      case errm_sqlite:query(Db, Sql, [Slug, Title, Summary, ContentMarkdown, UserId, Tags, Now]) of
        {ok, _} ->
          {ok, LastId} = errm_sqlite_nif:last_insert_rowid(Db),
          response_utils:ok(#{message => <<"Post created successfully">>, id => LastId});
        {error, Reason1} ->
          logger:error("Error creating post: ~p", [Reason1]),
          response_utils:error(500, "Couldn't create post due to database error")
      end
  end.

handle_update(Req, UserId, Identifier) ->
  case validate_post_request(Req) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    {ok, Title, Slug, Summary, ContentMarkdown, TagsJson} ->
      sql_update_post(UserId, Identifier, Title, Slug, Summary, ContentMarkdown, TagsJson)
  end.

sql_update_post(UserId, Identifier, Title, Slug, Summary, ContentMarkdown, Tags) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      Now = erlang:system_time(second),
      {Where, WhereArgs} = case Identifier of
        {id, Id} -> {"id = ?", [Id]};
        {slug, SlugVal} -> {"slug = ?", [SlugVal]}
      end,
      Sql = "UPDATE posts SET title = ?, slug = ?, summary = ?, content_markdown = ?, tags = ?, edited_at = ? WHERE " ++ Where ++ " AND author_id = ?",
      Params = [Title, Slug, Summary, ContentMarkdown, Tags, Now] ++ WhereArgs ++ [UserId],
      case errm_sqlite:query(Db, Sql, Params) of
        {ok, []} ->
          fetch_post(Identifier);
        {error, Reason1} ->
          logger:error("Error updating post: ~p", [Reason1]),
          response_utils:error(500, "Couldn't update post due to database error");
        _ -> response_utils:error(500, "Couldn't find post to update")
      end
  end.

sql_delete_post(UserId, Identifier) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      {Where, WhereArgs} = case Identifier of
        {id, Id} -> {"id = ?", [Id]};
        {slug, SlugVal} -> {"slug = ?", [SlugVal]}
      end,

      Sql = "DELETE FROM posts WHERE " ++ Where ++ " AND author_id = ?",
      Params = WhereArgs ++ [UserId],
      case errm_sqlite:query(Db, Sql, Params) of
        {ok, []} ->
          {ok, {204, #{}, <<>>}};
        {error, Reason1} ->
          logger:error("Error deleting post: ~p", [Reason1]),
          response_utils:error(500, "Couldn't delete post due to database error");
        _ -> response_utils:error(500, "Couldn't find post to delete")
      end
  end.

to_int(N) when is_integer(N) ->
  N;
to_int(B) when is_binary(B) ->
  case string:to_integer(binary_to_list(B)) of
    {I, []} when is_integer(I) -> I;
    _ -> 10
  end;
to_int(_) -> 10.

identifier(Bin) ->
  case string:to_integer(binary_to_list(Bin)) of
    {IntId, []} when is_integer(IntId) -> {id, IntId};
    _ -> {slug, Bin}
  end.
