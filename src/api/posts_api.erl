-module(posts_api).
-export([get_all_posts/1, get_post/1, create_post/1, update_post/1, delete_post/1]).

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
      case maps:get(<<"slug">>, Params, undefined) of
        undefined -> response_utils:error(400, "No id or slug provided");
        Slug -> fetch_post_by_slug(Slug)
      end;
    IdBin when is_binary(IdBin) ->
      case string:to_integer(binary_to_list(IdBin)) of
        {IntId, []} when is_integer(IntId) -> fetch_post_by_id(IntId);
        _ ->
          response_utils:error(400, "Invalid id")
      end
  end.

-spec create_post(errm_http:request()) -> {ok, errm_http:response()}.
create_post(Req) ->
  case blog_middlewares:get_user_id(Req) of
    undefined -> response_utils:error(401, "Unauthorized");
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
          case maps:get(<<"slug">>, Params, undefined) of
            undefined -> response_utils:error(400, "No id or slug provided");
            Slug -> handle_update(Req, UserId, {slug, Slug})
          end;
        IdBin when is_binary(IdBin) ->
          case string:to_integer(binary_to_list(IdBin)) of
            {IntId, []} when is_integer(IntId) -> handle_update(Req, UserId, {id, IntId});
            _ ->
              response_utils:error(400, "Invalid id")
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
        undefined ->
          case maps:get(<<"slug">>, Params, undefined) of
            undefined -> response_utils:error(400, "No id or slug provided");
            Slug -> sql_delete_post(UserId, {slug, Slug})
          end;
        IdBin when is_binary(IdBin) ->
          case string:to_integer(IdBin) of
            {IntId, []} when is_integer(IntId) -> sql_delete_post(UserId, {id, IntId});
            _ ->
              response_utils:error(400, "Invalid id")
          end
      end
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
  case errm_sqlite:query(Db, "SELECT * FROM posts LIMIT ?", [Amount]) of
    {ok, []} ->
      response_utils:ok(#{message => "No posts available"});
    {ok, Rows} ->
      Posts = [format_post(Row) || Row <- Rows],
      Response = #{
        <<"amount">> => length(Posts),
        <<"posts">> => Posts
      },
      response_utils:ok(Response);
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
      case errm_sqlite:query(Db, "SELECT * FROM posts WHERE id = ? LIMIT 1", [Id]) of
        {ok, []} ->
          response_utils:error(404, "Post not found");
        {ok, [Row]} ->
          response_utils:ok(format_post(Row));
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
      case errm_sqlite:query(Db, "SELECT * FROM posts WHERE slug = ? LIMIT 1", [Slug]) of
        {ok, []} ->
          response_utils:error(404, "Post not found");
        {ok, [Row]} ->
          response_utils:ok(format_post(Row));
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
              logger:debug("Data: ~p", [Data]),
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
              logger:error("Error creating reading json: ~p", [Reason]),
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
        {ok, 0} ->
          response_utils:error(404, "Post not found or not authorized");
        {ok, 1} ->
          fetch_updated_post(Db, Identifier);
        {error, Reason1} ->
          logger:error("Error updating post: ~p", [Reason1]),
          response_utils:error(500, "Couldn't update post due to database error")
      end
  end.

fetch_updated_post(Db, Identifier) ->
  case Identifier of
    {id, Id} ->
      case errm_sqlite:query(Db, "SELECT * FROM posts WHERE id = ? LIMIT 1", [Id]) of
        {ok, [Row]} -> response_utils:ok(Row);
        {ok, []} -> response_utils:error(404, "Post not found");
        {error, Reason} ->
          logger:error("Error fetching post: ~p", [Reason]),
          response_utils:error(500, "Database error")
      end;
    {slug, Slug} ->
      case errm_sqlite:query(Db, "SELECT * FROM posts WHERE slug = ? LIMIT 1", [Slug]) of
        {ok, [Row]} -> response_utils:ok(Row);
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
        {ok, 0} ->
          response_utils:error(404, "Post not found or not authorized");
        {ok, 1} ->
          {ok, {204, #{}, <<>>}};
        {error, Reason1} ->
          logger:error("Error deleting post: ~p", [Reason1]),
          response_utils:error(500, "Couldn't delete post due to database error")
      end
  end.

-spec format_post(map()) -> map().
format_post(Row) ->
  maps:fold(fun(Key, Value, Acc) ->
    BinKey = key_to_binary(Key),
    BinValue = value_to_binary(Value),
    FinalValue = case BinKey of
      <<"tags">> when is_binary(BinValue) ->
        try errm_json:decode(BinValue) of
          {ok, Decoded} -> Decoded;
          _ -> BinValue
        catch _:_ -> BinValue
          end;
      _ -> BinValue
    end,
    Acc#{BinKey => FinalValue}
  end, #{}, Row).

key_to_binary(Key) when is_atom(Key) -> atom_to_binary(Key, utf8);
key_to_binary(Key) when is_list(Key) -> list_to_binary(Key);
key_to_binary(Key) when is_binary(Key) -> Key;
key_to_binary(Key) -> iolist_to_binary(Key).

value_to_binary(null) -> null;
value_to_binary(undefined) -> null;
value_to_binary(V) when is_list(V) ->
    case is_string(V) of
        true -> iolist_to_binary(V);
        false -> V
    end;
value_to_binary(V) -> V.

is_string([]) -> true;
is_string([H|T]) when is_integer(H), H >= 0, H =< 255 -> is_string(T);
is_string(_) -> false.
