-module(blog_db).
-export([init/0, db/0]).

-spec init() -> ok.
init() ->
  {ok, Db} = errm_sqlite:open(blog_config:get(db_path)),
  {ok, _} = errm_sqlite:exec(Db, "PRAGMA foreign_keys = ON;"),
  errm_http:set_secret(db, Db).

-spec db() -> {ok, Db :: reference()} | {error, not_found}.
db() ->
  errm_http:get_secret(db).
