-module(user_api).
-export([get_current_user/1]).

-spec get_current_user(errm_http:request()) -> {ok, errm_http:response()}.
get_current_user(Req) ->
  case blog_middlewares:get_user_id(Req) of
    undefined -> response_utils:error(401, "Unauthorized");
    UserId ->
      sql_get_user(UserId)
  end.


sql_get_user(UserId) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      fetch_user(Db, UserId)
  end.


fetch_user(Db, UserId) ->
  case errm_sqlite:query(Db, "SELECT uuid, username, role FROM users WHERE uuid = ? LIMIT 1", [UserId]) of
    {ok, []} ->
      response_utils:error(404, "User not found");
    {ok, [Row]} ->
      response_utils:ok(blog_format:format_user(Row), [uuid, username, role]);
    {error, Reason} ->
      logger:error("Error fetching user: ~p", [Reason]),
      response_utils:error(500, "Database error")
  end.
