-module(blog_db).
-export([init/0, db/0]).

-spec init() -> ok.
init() ->
  {ok, Db} = errm_sqlite:open(blog_config:get(db_path)),
  errm_http:set_secret(db, Db).

db() ->
  errm_http:get_secret(db).
