-module (notifications_api).
-export ([get_all/1, clear/1]).

-spec get_all(Req :: errm_http:request()) -> {ok, Resp :: errm_http:response()}.
get_all(_Req) ->
  case blog_notifications:get_all() of
    {ok, Notifications} -> response_utils:ok(#{notifications => Notifications});
    {error, Reason} ->
      logger:error("Error fetching notifications: ~p", [Reason]),
      response_utils:error(500, "Couldn't fetch notifications")
  end.

-spec clear(Req :: errm_http:request()) -> {ok, Resp :: errm_http:response()}.
clear(_Req) ->
  case blog_notifications:clear() of
    ok -> response_utils:ok(#{message => <<"Notifications cleared">>});
    {error, Reason} ->
      logger:error("Error clearing notifications: ~p", [Reason]),
      response_utils:error(500, "Couldn't clear notifications")
  end.
