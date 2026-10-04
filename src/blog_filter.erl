-module (blog_filter).
-export([sanitize/2, decode_list/1]).

sanitize(Text, Scope) ->
  {Keywords, Patterns} = blocked_patterns(Scope),
  mask_keywords(apply_patterns(Text, Patterns), Keywords).

apply_patterns(Acc, []) -> Acc;
apply_patterns(Acc, [Pattern | Rest]) ->
  try re:replace(Acc, Pattern, <<"####">>, [global, caseless]) of
    Masked when is_binary(Masked) -> apply_patterns(Masked, Rest);
    Masked when is_list(Masked) -> apply_patterns(iolist_to_binary(Masked), Rest)
  catch _:_ ->
    logger:error("Invalid blocked pattern ~p", [Pattern]),
    apply_patterns(Acc, Rest)
  end.

mask_keywords(Text, []) ->
  Text;
mask_keywords(Text, [K | Rest]) ->
  mask_keywords(binary:replace(Text, K, <<"####">>, [global]), Rest).

blocked_patterns(Scope) ->
  case blog_db:db() of
    {ok, Db} ->
      case errm_sqlite:query(Db, "SELECT keywords, patterns FROM blocked_words WHERE scope IN (?, 'global')", [Scope]) of
        {ok, Rows} ->
          Keywords = [K || R <- Rows, K <- decode_list(maps:get("keywords", R)), is_binary(K), K =/= <<>>],
          Patterns = [P || R <- Rows, P <- decode_list(maps:get("patterns", R)), is_binary(P), P =/= <<>>],
          {Keywords, Patterns};
        {error, Reason} ->
          logger:error("Error fetching blocked words: ~p", [Reason]),
          {[], []}
      end;
    {error, Reason1} ->
      logger:error("Database open failed: ~p", [Reason1]),
      {[], []}
  end.

decode_list(Raw) ->
  case errm_json:decode(blog_format:value_to_binary(Raw)) of
    {ok, List} when is_list(List) -> List;
    _ -> []
  end.

