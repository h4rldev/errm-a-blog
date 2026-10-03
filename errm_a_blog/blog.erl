-module (blog).
-export ([main/1]).

main(_Args) ->
  errm_a_blog:start(),
  receive stop -> errm_a_blog:stop() end.
