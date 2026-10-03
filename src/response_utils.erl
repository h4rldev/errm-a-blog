-module (response_utils).
-export ([ok/1, ok/2, error/2]).

-spec ok(map()) -> {ok, errm_http:response()}.
ok(Body) ->
  json(200, Body, []).

-spec ok(map(), [binary() | atom()]) -> {ok, errm_http:response()}.
ok(Body, Order) ->
  json(200, Body, Order).

-spec error(integer(), binary() | string()) -> {ok, errm_http:response()}.
error(Status, Message) when is_binary(Message) ->
  json(Status, #{error => Message}, []);
error(Status, Message) when is_list(Message) ->
  json(Status, #{error => list_to_binary(Message)}, []).

json(Status, Body, Order) ->
  Headers = #{<<"content-type">> => <<"application/json">>},
  Json = errm_json:encode(Body, #{order => Order}),
  {ok, {Status, Headers, Json}}.
