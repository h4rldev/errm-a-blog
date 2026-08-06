-module(posts_api).
-export([get_all_posts/1, get_post/1, create_post/1, update_post/1, delete_post/1, get_tags/1]).

-define(POST_ORDER, [id, slug, title, summary, content_markdown, tags, last_edited_at, posted_at, author]).


-spec get_all_posts(errm_http:request()) -> {ok, errm_http:response()}.
get_all_posts(Req) ->
  Params = maps:get(params, Req, #{}),
  Number = maps:get(<<"amount">>, Params, 10),
  handle_get_posts(Number).

-spec get_post(errm_http:request()) -> {ok, errm_http:response()}.
get_post(Req) ->
  Params = maps:get(params, Req, #{}),
  case maps:get(<<"id">>, Params, undefined) of
    undefined ->
      response_utils:error(400, "No id or slug provided");
    IdBin when is_binary(IdBin) ->
      case string:to_integer(binary_to_list(IdBin)) of
        {IntId, []} when is_integer(IntId) -> fetch_post_by_id(IntId);
        _ -> fetch_post_by_slug(IdBin)
      end;
    _ -> response_utils:error(400, "Invalid id")
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
          case string:to_integer(binary_to_list(IdBin)) of
            {IntId, []} when is_integer(IntId) -> handle_update(Req, UserId, {id, IntId});
            _ -> handle_update(Req, UserId, {slug, IdBin})
          end
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
          case string:to_integer(binary_to_list(IdBin)) of
            {IntId, []} when is_integer(IntId) -> sql_delete_post(UserId, {id, IntId});
            _ ->
              sql_delete_post(UserId, {slug, IdBin})
          end
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
          SafeRows = [Row || Row <- Rows, is_map(Row)],
          AllTags = extract_tags(SafeRows),
          UniqueTags = deduplicate_tags(AllTags),
          SortedTags = lists:sort(UniqueTags),
          response_utils:ok(#{tags => SortedTags});
        {error, Reason1} ->
          logger:error("Error fetching tags: ~p", [Reason1]),
          response_utils:error(500, "Database error")
      end
  end.

-spec extract_tags([map()]) -> [binary()].
extract_tags(Rows) ->
  extract_tags(Rows, []).

-spec extract_tags([map()], [binary()]) -> [binary()].
extract_tags([], Acc) ->
  Acc;
extract_tags([Row | Rest], Acc) ->
  NewTags = extract_tags_from_row(Row),
  extract_tags(Rest, NewTags ++ Acc).

-spec extract_tags_from_row(map()) -> [binary()].
extract_tags_from_row(Row) when is_map(Row) ->
  TagsRaw = maps:get("tags", Row, <<"[]">>),
  TagsBin = blog_format:value_to_binary(TagsRaw),
  case is_binary(TagsBin) of
    true ->
      try
        errm_json:decode(TagsBin) of
          {ok, List} when is_list(List) ->
            convert_tags_to_binary(List, []);
          _ ->
            []
      catch
        _:_ -> []
      end;
    false ->
      []
  end.

-spec convert_tags_to_binary([term()], [binary()]) -> [binary()].
convert_tags_to_binary([], Acc) ->
  Acc;
convert_tags_to_binary([Tag | Rest], Acc) ->
  BinTag = blog_format:value_to_binary(Tag),
  convert_tags_to_binary(Rest, [BinTag | Acc]).

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
  case errm_sqlite:query(Db, "SELECT posts.*, users.username, users.role FROM posts JOIN users ON posts.author_id = users.uuid LIMIT ?", [Amount]) of
    {ok, []} ->
      response_utils:ok(#{message => "No posts available"});
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


fetch_post_by_id(Id) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      case errm_sqlite:query(Db, "SELECT posts.*, users.username, users.role FROM posts JOIN users ON posts.author_id = users.uuid WHERE posts.id = ? LIMIT 1", [Id]) of
        {ok, []} ->
          response_utils:error(404, "Post not found");
        {ok, [Row]} ->
          response_utils:ok(blog_format:format_post(Row), ?POST_ORDER);
        {error, Reason1} ->
          logger:error("Error fetching post: ~p", [Reason1]),
          response_utils:error(500, "Database error")
      end
  end.

fetch_post_by_slug(Slug) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      case errm_sqlite:query(Db, "SELECT posts.*, users.username, users.role FROM posts JOIN users ON posts.author_id = users.uuid WHERE posts.slug = ? LIMIT 1", [Slug]) of
        {ok, []} ->
          response_utils:error(404, "Post not found");
        {ok, [Row]} ->
          response_utils:ok(blog_format:format_post(Row), ?POST_ORDER);
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
      logger:debug("Tags: ~p", [Tags]),
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

handle_update(Req, UserId, {Type, Value}) ->
  case validate_update_body(Req) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    {ok, Title, Slug, Summary, ContentMarkdown, TagsJson} ->
      case Type of
        id ->
          sql_update_post(UserId, {id, Value}, Title, Slug, Summary, ContentMarkdown, TagsJson);
        slug ->
          sql_update_post(UserId, {slug, Value}, Title, Slug, Summary, ContentMarkdown, TagsJson)
      end
  end.

validate_update_body(Req) ->
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
            {error, Reason1} ->
              logger:error("Error creating reading json: ~p", [Reason1]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ -> {error, 400, "Invalid content type"}
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
      Sql = io_lib:format("UPDATE posts SET title = ?, slug = ?, summary = ?, content_markdown = ?, tags = ?, last_edited_at = ? WHERE ~s AND author_id = ?", [Where]),
      SqlStr = lists:flatten(Sql),
      Params = [Title, Slug, Summary, ContentMarkdown, Tags, Now] ++ WhereArgs ++ [UserId],
      case errm_sqlite:query(Db, SqlStr, Params) of
        {ok, []} ->
          fetch_updated_post(Db, Identifier);
        {error, Reason1} ->
          logger:error("Error updating post: ~p", [Reason1]),
          response_utils:error(500, "Couldn't update post due to database error");
        _ -> response_utils:error(500, "Couldn't find post to update")
      end
  end.

fetch_updated_post(Db, Identifier) ->
  case Identifier of
    {id, Id} ->
      case errm_sqlite:query(Db, "SELECT posts.*, users.username, users.role FROM posts JOIN users ON posts.author_id = users.uuid WHERE posts.id = ? LIMIT 1", [Id]) of
        {ok, [Row]} -> response_utils:ok(blog_format:format_post(Row), ?POST_ORDER);
        {ok, []} -> response_utils:error(404, "Post not found");
        {error, Reason} ->
          logger:error("Error fetching post: ~p", [Reason]),
          response_utils:error(500, "Database error")
      end;
    {slug, Slug} ->
      case errm_sqlite:query(Db, "SELECT * FROM posts WHERE slug = ? LIMIT 1", [Slug]) of
        {ok, [Row]} -> response_utils:ok(blog_format:format_post(Row), ?POST_ORDER);
        {ok, []} -> response_utils:error(404, "Post not found");
        {error, Reason1} ->
          logger:error("Error fetching post: ~p", [Reason1]),
          response_utils:error(500, "Database error")
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

      Sql = io_lib:format("DELETE FROM posts WHERE ~s AND author_id = ?", [Where]),
      SqlStr = lists:flatten(Sql),
      Params = WhereArgs ++ [UserId],
      case errm_sqlite:query(Db, SqlStr, Params) of
        {ok, []} ->
          {ok, {204, #{}, <<>>}};
        {error, Reason1} ->
          logger:error("Error deleting post: ~p", [Reason1]),
          response_utils:error(500, "Couldn't delete post due to database error");
        _ -> response_utils:error(500, "Couldn't find post to delete")
      end
  end.

