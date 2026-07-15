-module(response_utils).
-export([json/2, json/3, ok/1, error/2]).

-spec json(integer(), map()) -> {ok, errm_http:response()}.
json(Status, Body) ->
    json(Status, Body, #{}).

-spec json(integer(), map(), map()) -> {ok, errm_http:response()}.
json(Status, Body, ExtraHeaders) ->
    Headers = maps:merge(ExtraHeaders, #{<<"content-type">> => <<"application/json">>}),
    Json = errm_json:encode(Body),

    {ok, {Status, Headers, Json}}.


-spec ok(map()) -> {ok, errm_http:response()}.
ok(Body) ->
    json(200, Body).

-spec error(integer(), binary() | string()) -> {ok, errm_http:response()}.
error(Status, Message) when is_binary(Message) ->
    json(Status, #{error => Message});

error(Status, Message) when is_list(Message) ->
    json(Status, #{error => list_to_binary(Message)}).
