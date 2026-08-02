-module (blog_ws_handler).
-behaviour (errm_ws_handler).

-export ([init/2, handle_text/2, handle_binary/2, handle_info/2, terminate/2]).
-export ([handle_ping/2, handle_pong/2]).

init(_RequestInfo, WsState) ->
  {ok, #{ws_state => WsState, channels => []}}.

handle_text(Data, State = #{ws_state := #{user_id := UserId}, channels := Channels}) ->
  case errm_json:decode(Data) of
    {ok, #{<<"event">> := <<"subscribe">>, <<"channel">> := Channel}} ->
      pg:join(blog_ws_group, Channel, self()),
      logger:debug("[ws]: User ~s subscribed to channel ~p", [UserId, Channel]),
      NewChannels = [Channel | Channels],
      {ok, State#{channels => NewChannels}};
    {ok, #{<<"event">> := <<"unsubscribe">>, <<"channel">> := Channel}} ->
      pg:leave(blog_ws_group, Channel, self()),
      logger:debug("[ws]: User ~s unsubscribed from channel ~p", [UserId, Channel]),
      NewChannels = lists:delete(Channel, Channels),
      {ok, State#{channels => NewChannels}};
    {ok, #{<<"event">> := <<"fetch_guestbook">>}} ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("[ws]: Failed to fetch guestbook: ~p", [Reason]),
          {ok, State};
        {ok, Db} ->
          {ok, Rows} = errm_sqlite:query(Db, "SELECT id, username, content_markdown, posted_at, last_edited_at FROM guestbook_entries ORDER BY posted_at DESC"),
          Payload = errm_json:to_binary(#{<<"event">> => <<"guestbook:initial">>, <<"entries">> => format_entries(Rows)}),
          errm_ws:send_text(self(), Payload),
          {ok, State}
      end;
    {ok, #{<<"event">> := <<"subscribe_all">>}} ->
      pg:join(blog_ws_group, <<"all_posts">>, self()),
      logger:debug("[ws]: User ~s subscribed to all posts", [UserId]),
      {ok, State};
    _ ->
      {ok, State}
  end.

handle_binary(_Data, State) ->
  {ok, State}.

handle_info({broadcast, _Channel, Message}, State) ->
  errm_ws:send_text(self(), Message),
  {ok, State};
handle_info(_Info, State) ->
  {ok, State}.

handle_ping(_Data, State) ->
  {ok, State}.

handle_pong(_Data, State) ->
  {ok, State}.

terminate(_Reason, _State) ->
  ok.



format_entries(Rows) ->
  [format_entry(Row) || Row <- Rows].

format_entry(Row) ->
  #{
    <<"id">> => value_to_binary(maps:get("id", Row, undefined)),
    <<"username">> => value_to_binary(maps:get("username", Row, undefined)),
    <<"content_markdown">> => value_to_binary(maps:get("content_markdown", Row, undefined)),
    <<"posted_at">> => maps:get("posted_at", Row, undefined),
    <<"last_edited_at">> => maps:get("last_edited_at", Row, undefined)
  }.

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
