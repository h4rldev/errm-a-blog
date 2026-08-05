-module (blog_filter).
-export([sanitize/2, contains_blocked/2, decode_list/1]).

sanitize(Text, Scope) ->
  sanitize(Text, blocked_patterns(Scope));

sanitize(Acc, []) -> Acc;
sanitize(Acc, [Pattern | Rest]) ->
  Masked = re:replace(Acc, Pattern, "####", [global, caseless]),
  sanitize(Masked, Rest).

contains_blocked(Text, Scope) ->
  contains_blocked(Text, blocked_patterns(Scope));
contains_blocked(_Text, []) -> false;
contains_blocked(Text, [Pattern | Rest]) ->
  case re:run(Text, Pattern, [caseless]) of
    nomatch -> contains_blocked(Text, Rest);
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

