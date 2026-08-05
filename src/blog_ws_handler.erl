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
          Payload = errm_json:to_binary(#{<<"event">> => <<"guestbook:initial">>, <<"entries">> => blog_format:format_entries(Rows)}),
          errm_ws:send_text(self(), Payload),
          {ok, State}
      end;
    {ok, #{<<"event">> := <<"fetch_post_comments">>, <<"post_id">> := PostId}} ->
      case blog_db:db() of
        {error, Reason} ->
          logger:error("[ws]: Failed to fetch post comments: ~p", [Reason]),
          {ok, State};
        {ok, Db} ->
          {ok, Rows} = errm_sqlite:query(Db, "SELECT id, username, content_markdown, posted_at, last_edited_at FROM post_comments WHERE post_id = ? ORDER BY posted_at DESC", [PostId]),
          Payload = errm_json:to_binary(#{<<"event">> => <<"post_comments:initial">>, <<"comments">> => blog_format:format_comments(Rows)}),
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
