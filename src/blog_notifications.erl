-module (blog_notifications).
-export ([record/6, get_all/0, clear/0, delete_identity/1]).
-export ([comment_target/2, guestbook_target/1]).

-spec record(Kind :: binary(), Action :: binary(), Username :: binary() | null, Content :: binary() | null, RefId :: binary() | null, Target :: binary() | null) -> ok.
record(Kind, Action, Username, Content, RefId, Target) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed recording notification: ~p", [Reason]),
      ok;
    {ok, Db} ->
      Sql = "INSERT INTO notifications (kind, action, username, content, ref_id, target, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      case errm_sqlite:query(Db, Sql, [Kind, Action, Username, Content, RefId, Target, erlang:system_time(second)]) of
        {ok, _} ->
          ok;
        {error, Reason1} ->
          logger:error("Error recording notification: ~p", [Reason1]),
          ok
      end
  end.

-spec get_all() -> {ok, Notifications :: [map()]} | {error, Reason :: term()}.
get_all() ->
  case blog_db:db() of
    {error, Reason} -> {error, Reason};
    {ok, Db} ->
      Sql = "SELECT id, kind, action, username, content, ref_id, target, created_at FROM notifications ORDER BY created_at DESC, id DESC",
      case errm_sqlite:query(Db, Sql, []) of
        {ok, Rows} ->
          {ok, [blog_format:format_notification(R) || R <- Rows]};
        {error, Reason1} -> {error, Reason1}
      end
  end.

-spec clear() -> ok | {error, Reason :: term()}.
clear() ->
  case blog_db:db() of
    {error, Reason} -> {error, Reason};
    {ok, Db} ->
      case errm_sqlite:query(Db, "DELETE FROM notifications", []) of
        {ok, _} -> ok;
        {error, Reason1} -> {error, Reason1}
      end
  end.

-spec comment_target(PostId :: binary(), CommentId :: binary()) -> binary().
comment_target(PostId, CommentId) ->
  <<"/blog/post/", PostId/binary, "#comment-", CommentId/binary>>.

-spec guestbook_target(EntryId :: binary()) -> binary().
guestbook_target(EntryId) ->
  <<"/guestbook#entry-", EntryId/binary>>.



delete_identity(Req) ->
  case errm_json:decode(maps:get(body, Req, <<>>)) of
    {ok, Data} when is_map(Data) ->
      {nullable(maps:get(<<"username">>, Data, undefined)),
       nullable(maps:get(<<"content_markdown">>, Data, undefined))};
    _ -> {null, null}
  end.

nullable(V) when is_binary(V) -> V;
nullable(_) -> null.
