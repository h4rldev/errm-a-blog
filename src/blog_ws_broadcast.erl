-module (blog_ws_broadcast).
-export ([broadcast/2]).
-export ([guestbook/5, guestbook_delete/3]).
-export ([comment/6, comment_delete/4]).

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
  broadcast(<<"guestbook">>, errm_json:to_binary(Payload)).

-spec guestbook_delete(Id :: binary(), Username :: binary() | null, Content :: binary() | null) -> ok.
guestbook_delete(Id, Username, Content) ->
  Action = <<"guestbook:deleted">>,
  Payload = #{<<"event">> => Action, <<"id">> => Id, <<"username">> => Username, <<"content_markdown">> => Content},
  broadcast(<<"guestbook">>, errm_json:to_binary(Payload)).

-spec comment(Topic :: topic(), Username :: binary(), Content :: binary(), Id :: binary(), PostId :: binary(), Time :: binary()) -> ok.
comment(created, Username, Content, Id, PostId, Time) ->
  Payload = #{<<"event">> => <<"post_comments:new">>, <<"id">> => Id,
              <<"username">> => Username, <<"content_markdown">> => Content,
              <<"post_id">> => PostId, <<"posted_at">> => Time},
  Msg = errm_json:to_binary(Payload),
  broadcast(<<"post_", PostId/binary>>, Msg),
  broadcast(<<"all_posts">>, Msg);
comment(edited, Username, Content, Id, PostId, Time) ->
  Payload = #{<<"event">> => <<"post_comments:edited">>, <<"id">> => Id,
              <<"username">> => Username, <<"content_markdown">> => Content,
              <<"post_id">> => PostId, <<"edited_at">> => Time},
  Msg = errm_json:to_binary(Payload),
  broadcast(<<"post_", PostId/binary>>, Msg),
  broadcast(<<"all_posts">>, Msg);
comment(deleted, Username, Content, Id, PostId, _Time) ->
  comment_delete(Id, PostId, Username, Content).

-spec comment_delete(Id :: binary(), PostId :: binary(), Username :: binary() | null, Content :: binary() | null) -> ok.
comment_delete(Id, PostId, Username, Content) ->
  Action = <<"post_comments:deleted">>,
  Payload = #{<<"event">> => Action, <<"id">> => Id, <<"post_id">> => PostId, <<"username">> => Username, <<"content_markdown">> => Content},
  Msg = errm_json:to_binary(Payload),
  broadcast(<<"post_", PostId/binary>>, Msg),
  broadcast(<<"all_posts">>, Msg).
