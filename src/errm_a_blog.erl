-module(errm_a_blog).
-export([start/0, stop/0]).

start() ->
  blog_config:load(),
  blog_secrets:init(),
  blog_db:init(),

  {ok, _} = pg:start_link(blog_ws_group),

  Level = case string:lowercase(blog_config:get(internal_log_level)) of
    "emergency" -> emergency;
    "alert" -> alert;
    "critical" -> critical;
    "error" -> error;
    "err" -> error;
    "warning" -> warning;
    "warn" -> warning;
    "notice" -> notice;
    "info" -> info;
    "debug" -> debug;
    "all" -> all;
    "none" -> none;
    _ -> debug
  end,

  logger:set_primary_config(level, Level),
  logger:update_handler_config(default, formatter, {logger_formatter, #{
    legacy_header => false,
    single_line => true
  }}),

  {ok, Pid} = errm_http:start(#{
    server_name => blog_config:get(server_name),
    port => blog_config:get(port),
    routes => blog_routes:get(),
    middlewares => blog_middlewares:get()
  }),

  logger:debug("Server started on pid ~p", [Pid]),
  {ok, self()}.


stop() ->
  errm_http:stop(),
  ok.
