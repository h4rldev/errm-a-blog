-module (blog_ws_broadcast).
-export ([broadcast/2]).
-export ([guestbook/5, comment/6]).

-type topic() :: created | edited | deleted.

-spec broadcast(binary(), binary()) -> ok.
broadcast(Channel, Message) ->
  Pids = pg:get_local_members(blog_ws_group, Channel),
  broadcast_to(Pids, Channel, Message).

broadcast_to([], _Channel, _Message) -> ok;
broadcast_to([Pid | Rest], Channel, Message) ->
  Pid ! {broadcast, Channel, Message},
  broadcast_to(Rest, Channel, Message).

-spec guestbook(Topic :: topic(), Username :: binary(), Content :: binary(), Id :: binary(), Time :: binary()) -> ok.
guestbook(created, Username, Content, Id, Time) ->
  Action = <<"guestbook:new">>,
  Payload = #{<<"event">> => Action, <<"id">> => Id, <<"username">> => Username, <<"content_markdown">> => Content, <<"posted_at">> => Time},
  broadcast(<<"guestbook">>, errm_json:to_binary(Payload));
guestbook(edited, Username, Content, Id, Time) ->
  Action = <<"guestbook:edited">>,
  Payload = #{<<"event">> => Action, <<"id">> => Id, <<"username">> => Username, <<"content_markdown">> => Content, <<"edited_at">> => Time},
  broadcast(<<"guestbook">>, errm_json:to_binary(Payload));
guestbook(deleted, _Username, _Content, Id, _Time) ->
  Action = <<"guestbook:deleted">>,
  Payload = #{<<"event">> => Action, <<"id">> => Id},
  broadcast(<<"guestbook">>, errm_json:to_binary(Payload)).


-spec comment(Topic :: topic(), Username :: binary(), Content :: binary(), Id :: binary(), PostId :: binary(), Time :: binary()) -> ok.
comment(created, Username, Content, Id, PostId, Time) ->
  Action = <<"post_comments:new">>,
  Payload = #{<<"event">> => Action, <<"id">> => Id, <<"username">> => Username, <<"content_markdown">> => Content, <<"posted_at">> => Time},
  Channel = <<"post_", PostId/binary>>,
  broadcast(Channel, errm_json:to_binary(Payload));
comment(edited, Username, Content, Id, PostId, Time) ->
  Action = <<"post_comments:edited">>,
  Payload = #{<<"event">> => Action, <<"id">> => Id, <<"username">> => Username, <<"content_markdown">> => Content, <<"edited_at">> => Time},
  Channel = <<"post_", PostId/binary>>,
  broadcast(Channel, errm_json:to_binary(Payload));
comment(deleted, _Username, _Content, Id, PostId, _Time) ->
  Action = <<"post_comments:deleted">>,
  Payload = #{<<"event">> => Action, <<"id">> => Id},
  Channel = <<"post_", PostId/binary>>,
  broadcast(Channel, errm_json:to_binary(Payload)).


