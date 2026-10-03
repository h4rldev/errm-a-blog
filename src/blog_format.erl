-module (blog_format).
-export ([format_post/1, format_entries/1, format_comments/1, format_blocked_words/1, format_notification/1]).
-export ([value_to_binary/1, format_user/1]).

-spec format_post(Post :: map()) -> FormattedPost :: map().
format_post(Post) ->
  AuthorMap = #{
    <<"uuid">> => value_to_binary(maps:get("author_id", Post, undefined)),
    <<"username">> => value_to_binary(maps:get("username", Post, undefined)),
    <<"role">> => value_to_binary(maps:get("role", Post, undefined))
  },

  Rest = maps:without(["author_id", "username", "role"], Post),
  FormattedRest = maps:fold(fun(Key, Value, Acc) ->
    BinKey = key_to_binary(Key),
    BinValue = value_to_binary(Value),
    FinalValue =
      case BinKey of
        <<"tags">> when is_binary(BinValue) ->
          try errm_json:decode(BinValue) of
            {ok, Decoded} -> Decoded;
            _ -> BinValue
          catch _:_ -> BinValue
          end;
        _ -> BinValue
      end,
    Acc#{BinKey => FinalValue}
  end, #{}, Rest),

  FormattedRest#{<<"author">> => AuthorMap}.

-spec format_blocked_words(BlockedWords :: [map()]) -> FormattedBlockedWords :: [map()].
format_blocked_words(BlockedWords) ->
  [format_blocked_word(BlockedWord) || BlockedWord <- BlockedWords].

format_blocked_word(BlockedWord) ->
  #{
    <<"scope">> => value_to_binary(maps:get("scope", BlockedWord, undefined)),
    <<"keywords">> => decode_json_array(maps:get("keywords", BlockedWord, <<"[]">>)),
    <<"patterns">> => decode_json_array(maps:get("patterns", BlockedWord, <<"[]">>)),
    <<"enforced_by">> => value_to_binary(maps:get("enforced_by", BlockedWord, undefined)),
    <<"updated_at">> => maps:get("updated_at", BlockedWord, undefined)
  }.

decode_json_array(Raw) ->
  case errm_json:decode(value_to_binary(Raw)) of
    {ok, List} when is_list(List) -> List;
    _ -> []
  end.

-spec format_comments(Comments :: [map()]) -> FormattedComments :: [map()].
format_comments(Comments) -> 
  format_entries(Comments).

-spec format_entries(Entries :: [map()]) -> FormattedEntries :: [map()].
format_entries(Entries) ->
  [format_entry(Entry) || Entry <- Entries].

format_entry(Entry) ->
  #{
    <<"id">> => value_to_binary(maps:get("id", Entry, undefined)),
    <<"username">> => value_to_binary(maps:get("username", Entry, undefined)),
    <<"content_markdown">> => value_to_binary(maps:get("content_markdown", Entry, undefined)),
    <<"posted_at">> => maps:get("posted_at", Entry, undefined),
    <<"edited_at">> => maps:get("edited_at", Entry, undefined)
  }.

format_notification(Row) ->
  #{
    <<"id">> => maps:get("id", Row, null),
    <<"kind">> => blog_format:value_to_binary(maps:get("kind", Row, undefined)),
    <<"action">> => blog_format:value_to_binary(maps:get("action", Row, undefined)),
    <<"username">> => blog_format:value_to_binary(maps:get("username", Row, undefined)),
    <<"content">> => blog_format:value_to_binary(maps:get("content", Row, undefined)),
    <<"ref_id">> => blog_format:value_to_binary(maps:get("ref_id", Row, undefined)),
    <<"target">> => blog_format:value_to_binary(maps:get("target", Row, undefined)),
    <<"created_at">> => maps:get("created_at", Row, null)
  }.

key_to_binary(Key) when is_atom(Key) -> atom_to_binary(Key, utf8);
key_to_binary(Key) when is_list(Key) -> list_to_binary(Key);
key_to_binary(Key) when is_binary(Key) -> Key;
key_to_binary(Key) -> iolist_to_binary(Key).

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

-spec format_user(User :: map()) -> map().
format_user(User) ->
  #{
    <<"uuid">> => value_to_binary(maps:get("uuid", User, undefined)),
    <<"username">> => value_to_binary(maps:get("username", User, undefined)),
    <<"role">> => value_to_binary(maps:get("role", User, undefined))
  }.
