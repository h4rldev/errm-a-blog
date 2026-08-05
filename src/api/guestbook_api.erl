-module (guestbook_api).
-export ([create_guestbook_entry/1, delete_guestbook_entry/1, update_guestbook_entry/1]).

-spec create_guestbook_entry(errm_http:request()) -> {ok, errm_http:response()}.
create_guestbook_entry(Req) ->
  case validate_guestbook_entry_request(Req) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    {ok, Username, ContentMarkdown} ->
      insert_guestbook_entry(Username, ContentMarkdown)
  end.

-spec delete_guestbook_entry(errm_http:request()) -> {ok, errm_http:response()}.
delete_guestbook_entry(Req) ->
  Params = maps:get(params, Req, #{}),
  case maps:get(<<"id">>, Params, undefined) of
    undefined ->
      response_utils:error(400, "No id provided");
    IdBin when is_binary(IdBin) ->
      case string:to_integer(binary_to_list(IdBin)) of
        {IntId, []} when is_integer(IntId) ->
          case blog_middlewares:is_admin(Req) of
            true -> sql_delete_guestbook_entry(IntId);
            false -> response_utils:error(401, "Unauthorized")
          end;
        _ -> response_utils:error(400, "Invalid id")
      end
  end.

-spec update_guestbook_entry(errm_http:request()) -> {ok, errm_http:response()}.
update_guestbook_entry(Req) ->
  Params = maps:get(params, Req, #{}),
  case maps:get(<<"id">>, Params, undefined) of
    undefined ->
      response_utils:error(400, "No id provided");
    IdBin when is_binary(IdBin) ->
      case string:to_integer(binary_to_list(IdBin)) of
        {IntId, []} when is_integer(IntId) -> 
          case blog_middlewares:is_admin(Req) of
            true -> handle_update(Req, IntId);
            false -> response_utils:error(401, "Unauthorized")
          end;
        _ ->
          response_utils:error(400, "Invalid id")
      end
  end.


validate_guestbook_entry_request(Req) ->
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
    _ ->
      {error, 400, "Invalid content type"}
  end.

insert_guestbook_entry(Username, ContentMarkdown) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      SanitizedContent = blog_filter:sanitize(ContentMarkdown, <<"guestbook">>),
      Now = erlang:system_time(second),
      Sql = "INSERT INTO guestbook_entries (username, content_markdown, posted_at) VALUES (?, ?, ?)",
      case errm_sqlite:query(Db, Sql, [Username, SanitizedContent, Now]) of
        {ok, _} ->
          {ok, LastId} = errm_sqlite_nif:last_insert_rowid(Db),
          blog_ws_broadcast:guestbook(created, Username, SanitizedContent, integer_to_binary(LastId), integer_to_binary(Now)),
          response_utils:ok(#{message => <<"Guestbook entry created successfully">>, id => LastId});
        {error, Reason1} ->
          logger:error("Error creating guestbook entry: ~p", [Reason1]),
          response_utils:error(500, "Couldn't create guestbook entry due to database error")
      end
  end.

sql_delete_guestbook_entry(EntryId) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      Sql = "DELETE FROM guestbook_entries WHERE id = ?",
      Params = [EntryId],
      case errm_sqlite:query(Db, Sql, Params) of
        {ok, []} ->
          blog_ws_broadcast:guestbook_delete(integer_to_binary(EntryId)),
          {ok, {204, #{}, <<>>}};
        {error, Reason1} ->
          logger:error("Error deleting guestbook entry: ~p", [Reason1]),
          response_utils:error(500, "Couldn't delete guestbook entry due to database error");
        _ -> response_utils:error(500, "Couldn't find guestbook entry to delete")
      end
  end.

handle_update(Req, EntryId) ->
  case validate_update_body(Req) of
    {error, Status, Message} ->
      response_utils:error(Status, Message);
    {ok, Title, ContentMarkdown} ->
      sql_update_guestbook_entry(EntryId, Title, ContentMarkdown)
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

sql_update_guestbook_entry(EntryId, Username, ContentMarkdown) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      SanitizedContent = blog_filter:sanitize(ContentMarkdown, <<"guestbook">>),
      Now = erlang:system_time(second),
      Sql = "UPDATE guestbook_entries SET content_markdown = ?, last_edited_at = ? WHERE id = ? AND username = ?",
      Params = [SanitizedContent, Now, EntryId, Username],
      case errm_sqlite:query(Db, Sql, Params) of
        {ok, []} ->
          blog_ws_broadcast:guestbook(edited, Username, SanitizedContent, integer_to_binary(EntryId), integer_to_binary(Now)),
          response_utils:ok(#{message => <<"Guestbook entry updated successfully">>, id => EntryId});
        {error, Reason1} ->
          logger:error("Error updating guestbook entry: ~p", [Reason1]),
          response_utils:error(500, "Couldn't update guestbook entry due to database error")
      end
  end.

