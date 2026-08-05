-module (blocked_words_api).
-export ([get_all/1, add/1, delete/1]).

-spec get_all(errm_http:request()) -> {ok, errm_http:response()}.
get_all(Req) ->
  Params = maps:get(params, Req, #{}),
  Scope = maps:get(<<"scope">>, Params, undefined),

  case valid_scope(Scope) of
    true ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("Database open failed: ~p", [Reason]),
          response_utils:error(500, "Database error");
        {ok, Db} ->
          Sql = "SELECT patterns, keywords, enforced_by FROM blocked_words WHERE scope = ?",
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
  end.

-spec add(errm_http:request()) -> {ok, errm_http:response()}.
add(Req) ->
  case validate_request(Req) of
    {ok, Scope, Patterns, Keywords, EnforcedBy} ->
      add_blocked_word(Scope, Patterns, Keywords, EnforcedBy);
    {error, Status, Message} ->
      response_utils:error(Status, Message)
  end.

-spec delete(errm_http:request()) -> {ok, errm_http:response()}.
delete(Req) ->
  case validate_request(Req) of
    {ok, Scope, Patterns, Keywords, EnforcedBy} ->
      delete_blocked_word(Scope, Patterns, Keywords, EnforcedBy);
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

              EnforcedBy = maps:get(<<"enforced_by">>, Data, undefined),
              Patterns = maps:get(<<"patterns">>, Data, undefined),
              Keywords = maps:get(<<"keywords">>, Data, undefined),

              case {Patterns, Keywords, EnforcedBy} of
                {undefined, _, _} -> {error, 400, "No patterns provided"};
                {_, undefined, _} -> {error, 400, "No keywords provided"};
                {undefined, undefined, _} -> {error, 400, "No enforced_by provided"};
                {P, K, E} when is_binary(P), is_binary(K), is_binary(E) ->
                  case valid_scope(Scope) of
                    false -> {error, 400, "Invalid scope"};
                    true -> {ok, Scope, P, K, E}
                  end;
                {_, _, _} -> {error, 400, "Invalid JSON fields"}
              end;
            {error, Reason} ->
              logger:error("Error creating reading json: ~p", [Reason]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ -> {error, 400, "Invalid content type"}
  end.

add_blocked_word(Scope, Patterns, Keywords, EnforcedBy) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      sql_add_blocked_word(Scope, Patterns, Keywords, EnforcedBy, Db)
  end.

delete_blocked_word(Scope, Patterns, Keywords, EnforcedBy) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      sql_delete_blocked_word(Scope, Patterns, Keywords, EnforcedBy, Db)
  end.


sql_add_blocked_word(_Scope, <<"[]">>, <<"[]">>, _EnforcedBy, _Db) ->
  response_utils:error(400, "No patterns or keywords provided");
sql_add_blocked_word(Scope, Patterns, Keywords, EnforcedBy, Db) ->
  {SetClause, Values} = case {Patterns, Keywords} of 
    {P, <<"[]">>} -> {"patterns = ?", [P]};
    {<<"[]">>, K} -> {"keywords = ?", [K]};
    {P, K} -> {"patterns = ?, keywords = ?", [P, K]}
  end,

  Params = Values ++ [EnforcedBy, erlang:system_time(second), Scope],
  Sql = "UPDATE blocked_words SET " ++ SetClause ++ ", enforced_by = ?, updated_at = ? WHERE scope = ?",
  case errm_sqlite:query(Db, Sql, Params) of
    {ok, []} ->
      response_utils:ok(#{message => "Blocked word added successfully"});
    {error, Reason} ->
      logger:error("Error adding blocked word: ~p", [Reason]),
      response_utils:error(500, "Couldn't add blocked word due to database error")
  end.

sql_delete_blocked_word(_Scope, <<"[]">>, <<"[]">>, _EnforcedBy, _Db) ->
  response_utils:error(400, "No patterns or keywords provided");
sql_delete_blocked_word(Scope, Patterns, Keywords, EnforcedBy, Db) ->
  case errm_sqlite:query(Db, "SELECT keywords, patterns FROM blocked_words WHERE scope = ?", [Scope]) of
    {ok, []} ->
      response_utils:error(404, "No blocked words found, are you using the right scope?");
    {ok, [Row]} ->
      OldKeywords = blog_filter:decode_list(maps:get("keywords", Row)),
      OldPatterns = blog_filter:decode_list(maps:get("patterns", Row)),
      NewKeywords = [K || K <- OldKeywords, not lists:member(K, blog_filter:decode_list(Keywords))],
      NewPatterns = [P || P <- OldPatterns, not lists:member(P, blog_filter:decode_list(Patterns))],
      Sql = "UPDATE blocked_words SET keywords = ?, patterns = ?, enforced_by = ?, updated_at = ? WHERE scope = ?",
      Params = [errm_json:to_binary(NewKeywords), errm_json:to_binary(NewPatterns), EnforcedBy, erlang:system_time(second), Scope],
      case errm_sqlite:query(Db, Sql, Params) of
        {ok, []} ->
          response_utils:ok(#{message => "Blocked word deleted successfully"});
        {error, Reason} ->
          logger:error("Error deleting blocked word: ~p", [Reason]),
          response_utils:error(500, "Couldn't delete blocked words due to database error")
      end;
    {error, Reason1} ->
      logger:error("Error fetching blocked words: ~p", [Reason1]),
      response_utils:error(500, "Database error")
  end.

valid_scope(<<"global">>) -> true;
valid_scope(<<"guestbook">>) -> true;
valid_scope(<<"comments">>) -> true;
valid_scope(_) -> false.
