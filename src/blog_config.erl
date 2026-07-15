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
           #{
            ip_address => maps:get(<<"ip_address">>, Decoded, Defaults#config.ip_address),
            port => maps:get(<<"port">>, Decoded, Defaults#config.port),
            log_access => maps:get(<<"log_access">>, Decoded, Defaults#config.log_access),
            internal_log_level => maps:get(<<"internal_log_level">>, Decoded, Defaults#config.internal_log_level),
            db_path => maps:get(<<"db_path">>, Decoded, Defaults#config.db_path),
            server_name => maps:get(<<"server_name">>, Decoded, Defaults#config.server_name)
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
    _ -> throw({error, config_not_found})
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
