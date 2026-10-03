-module (blocked_words_api).
-export ([get_all/1, set/1]).

-spec get_all(errm_http:request()) -> {ok, errm_http:response()}.
get_all(#{params := #{<<"scope">> := Scope}}) ->
  case valid_scope(Scope) of
    true ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed: ~p", [Reason]),
          response_utils:error(500, "Database error");
        {ok, Db} ->
          Sql = "SELECT scope, patterns, keywords, enforced_by FROM blocked_words WHERE scope = ?",
          Param = [Scope],
          case errm_sqlite:query(Db, Sql, Param) of
            {ok, []} ->
              response_utils:ok(#{message => "No blocked words found"});
            {ok, Rows} ->
              response_utils:ok(#{blocked_words => blog_format:format_blocked_words(Rows)});
            {error, Reason1} ->
              logger:error("Error fetching blocked words: ~p", [Reason1]),
              response_utils:error(500, "Database error")
          end
      end;
    false -> response_utils:error(400, "Invalid scope")
  end;
get_all(_Req) ->
  response_utils:error(400, "Invalid scope").

-spec set(errm_http:request()) -> {ok, errm_http:response()}.
set(Req) ->
  case validate_request(Req) of
    {ok, Scope, Patterns, Keywords, EnforcedBy} ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed ~p", [Reason]),
          response_utils:error(500, "Database error");
        {ok, Db} ->
          sql_set_blocked_words(Scope, Patterns, Keywords, EnforcedBy, Db)
        end;
    {error, Status, Message} ->
      response_utils:error(Status, Message)
  end.

validate_request(Req) ->
  case maps:get(headers, Req, #{}) of
    #{<<"content-type">> := <<"application/json">>} ->
      case maps:get(body, Req, <<>>) of
        <<>> -> {error, 400, "No body provided"};
        Body ->
          case errm_json:decode(Body) of
            {ok, Data} when is_map(Data) ->
              Params = maps:get(params, Req, #{}),
              Scope = maps:get(<<"scope">>, Params, undefined),

              EnforcedBy = normalize_json_field(maps:get(<<"enforced_by">>, Data, undefined)),
              Patterns = normalize_json_field(maps:get(<<"patterns">>, Data, undefined)),
              Keywords = normalize_json_field(maps:get(<<"keywords">>, Data, undefined)),

              case {Patterns, Keywords, EnforcedBy} of
                {undefined, _, _} -> {error, 400, "No patterns provided"};
                {_, undefined, _} -> {error, 400, "No keywords provided"};
                {P, K, E} when is_binary(P), is_binary(K), is_binary(E) ->
                  case valid_scope(Scope) of
                    false -> {error, 400, "Invalid scope"};
                    true -> {ok, Scope, P, K, E}
                  end;
                _ -> {error, 400, "Invalid JSON fields"}
              end;
            {error, Reason} ->
              logger:error("Error creating reading json: ~p", [Reason]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ -> {error, 400, "Invalid content type"}
  end.

sql_set_blocked_words(Scope, Patterns, Keywords, EnforcedBy, Db) ->
  Params = [Scope, Patterns, Keywords, EnforcedBy, erlang:system_time(second)],
  Sql = "INSERT INTO blocked_words (scope, patterns, keywords, enforced_by, updated_at) "
        "VALUES (?, ?, ?, ?, ?) "
        "ON CONFLICT(scope) DO UPDATE SET patterns = excluded.patterns, keywords = excluded.keywords, "
        "enforced_by = excluded.enforced_by, updated_at = excluded.updated_at",
  case errm_sqlite:query(Db, Sql, Params) of
    {ok, _} ->
      response_utils:ok(#{message => "Blocked words updated successfully"});
    {error, Reason} ->
      logger:error("Error adding blocked words: ~p", [Reason]),
      response_utils:error(500, "Couldn't update blocked words due to database error")
  end.

normalize_json_field(V) when is_list(V) ->
  errm_json:to_binary(V);
normalize_json_field(V) -> V.


valid_scope(<<"global">>) -> true;
valid_scope(<<"guestbook">>) -> true;
valid_scope(<<"comments">>) -> true;
valid_scope(_) -> false.
