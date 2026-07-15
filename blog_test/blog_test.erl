-module(blog_test).
-export([main/1, stop/0]).


main(_Args) ->
  errm_a_blog:start(),

  receive
    stop -> stop()
  end.


stop() ->
  errm_http:stop().
