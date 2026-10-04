-module (blog_access_log).
-export ([middleware/0]).

middleware() ->
  Enabled = case blog_config:get(log_access) of
    true -> true;
    _ -> false
  end,
  File = blog_config:get(access_log_file),
  fun(Req, Next) ->
    case Enabled of
      false ->
        Next(Req);
      true ->
        Start = erlang:monotonic_time(microsecond),
        Result = Next(Req),
        Duration = erlang:monotonic_time(microsecond) - Start,
        Line = io_lib:format("~s ~s -> ~p from ~s (~p µs)~n", [
          string:uppercase(atom_to_binary(maps:get(method, Req, get), utf8)),
          maps:get(raw_path, Req, <<"/">>),
          status_of(Result),
          peer_ip(Req),
          Duration
        ]),
        write(File, Line),
        Result
    end
  end.

-spec write(string(), unicode:chardata()) -> ok.
write("", Line) ->
  logger:info("~ts", [Line]);
write(File, Line) ->
  case unicode:characters_to_binary(Line) of
    Bin when is_binary(Bin) ->
      case file:write_file(File, Bin, [append]) of
        ok -> ok;
        {error, Reason} ->
          logger:error("Failed to append access log ~s: ~p", [File, Reason])
      end;
    EncodingError ->
      logger:error("Failed to encode access log line: ~p", [EncodingError])
  end.

-spec peer_ip(errm_http:request()) -> string().
peer_ip(Req) ->
  case maps:get(peer, Req, undefined) of
    {IP, _Port} ->
      case inet:ntoa(IP) of
        {error, _} -> "-";
        Str -> Str
      end;
    _ ->
      "-"
  end.

-spec status_of(term()) -> integer() | atom().
status_of({ok, {Status, _Headers, _Body}}) when is_integer(Status) -> Status;
status_of({error, Reason}) when is_atom(Reason) -> Reason;
status_of({upgrade, _Module, _Args}) -> 101;
status_of(_) -> undefined.
