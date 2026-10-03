-module (admin_api).
-export ([get_stats/1, get_register_token/1, rotate/1]).
-export ([get_users/1, edit_user/1]).

-spec get_stats(errm_http:request()) -> {ok, errm_http:response()}.
get_stats(_Req) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      Sql = "SELECT "
        "(SELECT COUNT(*) FROM posts) AS total_posts, "
        "(SELECT COUNT(*) FROM post_comments) AS total_comments, "
        "(SELECT COUNT(*) FROM guestbook_entries) AS total_guestbook_entries",

      case errm_sqlite:query(Db, Sql) of
        {ok, [Row]} ->
          response_utils:ok(#{
            <<"total_posts">>             => maps:get("total_posts", Row),
            <<"total_comments">>          => maps:get("total_comments", Row),
            <<"total_guestbook_entries">> => maps:get("total_guestbook_entries", Row)
          });
        {error, Reason1} ->
          logger:error("Error fetching stats: ~p", [Reason1]),
          response_utils:error(500, "Database error")
      end
  end.

-spec get_register_token(errm_http:request()) -> {ok, errm_http:response()}.
get_register_token(_Req) ->
  {ok, Token} = blog_secrets:get_register_token(),
  response_utils:ok(#{token => Token}).

-spec rotate(errm_http:request()) -> {ok, errm_http:response()}.
rotate(#{params := #{<<"secret">> := <<"register_token">>}}) ->
  blog_secrets:generate_register_token(),
  {ok, Token} = blog_secrets:get_register_token(),
  response_utils:ok(#{message => <<"Generated a new register token!">>, token => Token});
rotate(#{params := #{<<"secret">> := <<"jwt_secret">>}}) ->
  blog_secrets:gen_jwt_secret(),
  response_utils:ok(#{message => <<"Generated a new JWT secret!">>});
rotate(#{params := #{<<"secret">> := <<"cookie_key">>}}) ->
  blog_secrets:gen_cookie_secret(),
  response_utils:ok(#{message => <<"Generated a new cookie key!">>});
rotate(_Req) ->
  response_utils:error(400, "Invalid secret").

-spec get_users(errm_http:request()) -> {ok, errm_http:response()}.
get_users(Req) ->
  case blog_middlewares:get_claims(Req) of
    #{<<"role">> := <<"super-administrator">>} ->
      fetch_users("SELECT uuid, username, role FROM users ORDER BY username");
    #{<<"role">> := <<"administrator">>} ->
      fetch_users("SELECT uuid, username, role FROM users WHERE role = 'poster' ORDER BY username");
    _ ->
      response_utils:error(403, "Forbidden")
  end.

-spec edit_user(errm_http:request()) -> {ok, errm_http:response()}.
edit_user(Req) ->
  case blog_middlewares:get_claims(Req) of
    #{<<"role">> := CallerRole} = Claims ->
      CallerId = maps:get(<<"sub">>, Claims, undefined),
      case validate_edit_user_request(Req) of
        {ok, UserId, Changes} ->
          case role_allowed(CallerRole, CallerId, UserId, maps:get(<<"role">>, Changes, undefined)) of
            true -> sql_update_user(UserId, Changes);
            false -> response_utils:error(403, "Forbidden")
          end;
        {error, Status, Message} ->
          response_utils:error(Status, Message)
      end;
    _ ->
      response_utils:error(403, "Forbidden")
  end.

validate_edit_user_request(Req) ->
  case maps:get(body, Req, undefined) of
    undefined -> {error, 400, "No body provided"};
    Body ->
      case errm_json:decode(Body) of
        {ok, Data} when is_map(Data) ->
          Uuid = maps:get(<<"uuid">>, Data, undefined),
          Changes = maps:with([<<"username">>, <<"role">>, <<"password">>], Data),
          case {Uuid, maps:size(Changes)} of
            {undefined, _} -> {error, 400, "No user uuid provided"};
            {_, 0} -> {error, 400, "No fields to update"};
            _ ->
              case valid_role_change(maps:get(<<"role">>, Changes, undefined)) of
                false -> {error, 400, "Invalid role"};
                true -> {ok, Uuid, Changes}
              end
          end;
        _ -> {error, 400, "Invalid JSON"}
      end
  end.

sql_update_user(UserId, Changes) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      case maybe_hash_password(maps:get(<<"password">>, Changes, undefined)) of
        {error, _} -> response_utils:error(500, "Password processing error");
        {ok, MaybeHash} ->
          Sets0 = case maps:get(<<"username">>, Changes, undefined) of
            undefined -> [];
            U -> [{"username = ?", [U]}]
          end,
          Sets1 = case maps:get(<<"role">>, Changes, undefined) of
            undefined -> Sets0;
            R -> Sets0 ++ [{"role = ?", [R]}]
          end,
          Sets2 = case MaybeHash of
            undefined -> Sets1;
            H -> Sets1 ++ [{"password_hash = ?", [H]}]
          end,
          SetSql = string:join([S || {S, _} <- Sets2], ", "),
          Params = lists:append([V || {_, V} <- Sets2]) ++ [erlang:system_time(second), UserId],
          Sql = "UPDATE users SET " ++ SetSql ++ ", updated_at = ?, auth_version = auth_version + 1 WHERE uuid = ?",
          case errm_sqlite:query(Db, Sql, Params) of
            {ok, []} ->
              response_utils:ok(#{message => <<"User updated successfully">>});
            {error, Reason1} ->
              logger:error("Error updating user: ~p", [Reason1]),
              response_utils:error(500, "Couldn't update user due to database error")
          end
      end
  end.

valid_role_change(undefined) -> true;
valid_role_change(<<"poster">>) -> true;
valid_role_change(<<"administrator">>) -> true;
valid_role_change(<<"super-administrator">>) -> true;
valid_role_change(_) -> false.

maybe_hash_password(undefined) -> {ok, undefined};
maybe_hash_password(Password) when is_binary(Password) ->
  maybe_hash_password(binary_to_list(Password));
maybe_hash_password(Password) ->
  case errm_argon:hash(Password, interactive) of
    {ok, Hash} -> {ok, Hash};
    {error, Reason} ->
      logger:error("Error hashing password: ~p", [Reason]),
      {error, Reason}
  end.

role_allowed(_CallerRole, _CallerId, _UserId, undefined) -> true;  % no role change, fine
role_allowed(<<"super-administrator">>, CallerId, UserId, <<"super-administrator">>) ->
  same_user(CallerId, UserId);
role_allowed(<<"super-administrator">>, _CallerId, _UserId, _NewRole) -> true;
role_allowed(CallerRole, _CallerId, _UserId, NewRole) ->
  rank(CallerRole) > rank(NewRole).

same_user(undefined, _) ->
  false;
same_user(_, undefined) ->
  false;
same_user(A, B) -> blog_format:value_to_binary(A) =:= blog_format:value_to_binary(B).

rank(<<"super-administrator">>) -> 3;
rank(<<"administrator">>) -> 2;
rank(<<"poster">>) -> 1;
rank(_) -> 0.

fetch_users(Sql) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      case errm_sqlite:query(Db, Sql) of
        {ok, Rows} ->
          response_utils:ok(#{users => [blog_format:format_user(User) || User <- Rows]});
        {error, Reason1} ->
          logger:error("Error fetching users: ~p", [Reason1]),
          response_utils:error(500, "Database error")
      end
  end.
