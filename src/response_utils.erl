-module(response_utils).
-export([json/2, json/3, json/4, ok/1, ok/2, error/2, error/3]).

-spec json(integer(), map()) -> {ok, errm_http:response()}.
json(Status, Body) ->
    json(Status, Body, #{}).

-spec json(integer(), map(), map()) -> {ok, errm_http:response()}.
json(Status, Body, ExtraHeaders) ->
  json(Status, Body, [], ExtraHeaders).

-spec json(integer(), map(), [atom() | binary()], map()) -> {ok, errm_http:response()}.
json(Status, Body, Order, ExtraHeaders) ->
    Headers = maps:merge(ExtraHeaders, #{<<"content-type">> => <<"application/json">>}),
    Json = errm_json:encode(Body, #{order => Order}),

    {ok, {Status, Headers, Json}}.


-spec ok(map()) -> {ok, errm_http:response()}.
ok(Body) ->
    json(200, Body).

-spec ok(map(), [binary() | atom()]) -> {ok, errm_http:response()}.
ok(Body, Order) ->
  json(200, Body, Order, #{}).


-spec error(integer(), binary() | string()) -> {ok, errm_http:response()}.
error(Status, Message) when is_binary(Message) ->
    json(Status, #{error => Message});

error(Status, Message) when is_list(Message) ->
    json(Status, #{error => list_to_binary(Message)}).

-spec error(integer(), binary() | string(), [binary() | atom()]) -> {ok, errm_http:response()}.
error(Status, Message, Order) when is_binary(Message) ->
    json(Status, #{error => Message}, Order, #{});

error(Status, Message, Order) when is_list(Message) ->
    json(Status, #{error => list_to_binary(Message)}, Order, #{}).
