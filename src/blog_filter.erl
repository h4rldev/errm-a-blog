-module (blog_filter).
-export([sanitize/2, contains_blocked/2, decode_list/1]).

sanitize(Text, Scope) ->
  apply_patterns(Text, blocked_patterns(Scope)).

apply_patterns(Acc, []) -> Acc;
apply_patterns(Acc, [Pattern | Rest]) ->
  Masked = re:replace(Acc, Pattern, "####", [global, caseless]),
  apply_patterns(Masked, Rest).

contains_blocked(Text, Scope) ->
  check_patterns(Text, blocked_patterns(Scope)).

check_patterns(_Text, []) -> false;
check_patterns(Text, [Pattern | Rest]) ->
  case re:run(Text, Pattern, [caseless]) of
    nomatch -> check_patterns(Text, Rest);
    _ -> true
  end.

blocked_patterns(Scope) ->
  {ok, Db} = blog_db:db(),
  {ok, Rows} = errm_sqlite:query(Db,
    "SELECT keywords, patterns FROM blocked_words WHERE scope IN (?, 'global')", [Scope]),
  [K || R <- Rows, K <- decode_list(maps:get("keywords", R))] ++
  [P || R <- Rows, P <- decode_list(maps:get("patterns", R))].

decode_list(Raw) ->
  case errm_json:decode(blog_format:value_to_binary(Raw)) of
    {ok, List} when is_list(List) -> List;
    _ -> []
  end.

