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
      response_utils:ok(format_user(Row), [uuid, username, role]);
    {error, Reason} ->
      logger:error("Error fetching user: ~p", [Reason]),
      response_utils:error(500, "Database error")
  end.

-spec format_user(map()) -> map().
format_user(Row) ->
  maps:fold(fun(Key, Value, Acc) ->
    BinKey = key_to_binary(Key),
    BinValue = value_to_binary(Value),
    Acc#{BinKey => BinValue}
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
