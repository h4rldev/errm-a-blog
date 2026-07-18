-module(blog_config).
-export([load/0, get/1]).

-record(config, {
  ip_address :: string(),
  port :: non_neg_integer(),
  log_access :: boolean(),
  internal_log_level :: string(),
  db_path :: string(),
  server_name :: string()
}).


load() ->
  Defaults = #config{
    ip_address = "0.0.0.0",
    port = 8080,
    log_access = true,
    internal_log_level = "debug",
    db_path = "blog.db",
    server_name = "errm-a-blog"
  },

  Config = case file:read_file("errm-config.json") of
    {ok, Data} ->
      case errm_json:decode(Data) of
        {ok, Decoded} when is_map(Decoded) ->
          Ip = maps:get(<<"ip_address">>, Decoded, Defaults#config.ip_address),
          Port = maps:get(<<"port">>, Decoded, Defaults#config.port),
          PortInt = case Port of
            _Port when is_integer(_Port) -> _Port
          end,
          LogAccess = maps:get(<<"log_access">>, Decoded, Defaults#config.log_access),
          LogAccessBool = case LogAccess of
            LA when is_boolean(LA) -> LA
          end,
          InternalLogLevel = maps:get(<<"internal_log_level">>, Decoded, Defaults#config.internal_log_level),
          DbPath = maps:get(<<"db_path">>, Decoded, Defaults#config.db_path),
          ServerName = maps:get(<<"server_name">>, Decoded, Defaults#config.server_name),

           #config{
            ip_address=json_to_string(Ip),
            port=PortInt,
            log_access=LogAccessBool,
            internal_log_level=json_to_string(InternalLogLevel),
            db_path=json_to_string(DbPath),
            server_name=json_to_string(ServerName)
          };
        {error, not_found} ->
          logger:warning("Failed to decode config file: ~p, using defaults"),
          Defaults
      end;
    {error, Reason1} ->
      logger:warning("Failed to read config file: ~p, using defaults", [Reason1]),

      if Reason1 =:= enoent ->
        DefaultsMap = record_to_map(Defaults),
        Json = errm_json:encode(DefaultsMap, #{pretty => true, indent => 2}),
        file:write_file("errm-config.json", Json)
      end,
      Defaults
  end,

  errm_http:set_secret(config, Config),
  ok.

record_to_map(#config{} = Record) ->
  Fields = record_info(fields, config),
  Values = case tl(tuple_to_list(Record)) of
    Vals when is_list(Vals) -> Vals
  end,
  maps:from_list(lists:zip(Fields, Values)).


get(Key) ->
  Config = case errm_http:get_secret(config) of
    {ok, Secret} when is_record(Secret, config) -> Secret;
    WhatHappened ->
      io:format("What happened: ~p~n", [WhatHappened]),
      throw({error, config_not_found})
  end,

  case Key of
    ip_address -> Config#config.ip_address;
    port -> Config#config.port;
    log_access -> Config#config.log_access;
    internal_log_level -> Config#config.internal_log_level;
    db_path -> Config#config.db_path;
    server_name -> Config#config.server_name;
    _ -> undefined
  end.

%% Main conversion – eqWAlizer now sees both branches return string()
-spec json_to_string(errm_json:json_term()) -> string().
json_to_string(V) when is_binary(V) ->
    binary_to_list(V);
json_to_string(V) when is_list(V) ->
    ensure_string(V).   %% returns string()

%% Helper that accepts any list and returns a string (list of integers)
%% Throws if the list contains non‑integer elements.
-spec ensure_string(list()) -> string().
ensure_string([]) -> [];
ensure_string([H|T]) when is_integer(H) ->
    [H | ensure_string(T)];
ensure_string(_) -> error({not_a_string}).
