-module (admin_api).
-export ([get_stats/1, get_register_token/1, rotate/1]).

-spec get_stats(errm_http:request()) -> {ok, errm_http:response()}.
get_stats(_Req) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      Sql = "SELECT "
        "(SELECT COUNT(*) FROM posts) AS total_posts, "
        "(SELECT COUNT(*) FROM post_comments) AS total_comments, "
        "(SELECT COUNT(*) FROM guestbook_entries) AS total_guestbook_entries",

      case errm_sqlite:query(Db, Sql) of
        {ok, [Row]} ->
          response_utils:ok(#{
            <<"total_posts">>             => maps:get("total_posts", Row),
            <<"total_comments">>          => maps:get("total_comments", Row),
            <<"total_guestbook_entries">> => maps:get("total_guestbook_entries", Row)
          });
        {error, Reason1} ->
          logger:error("Error fetching stats: ~p", [Reason1]),
          response_utils:error(500, "Database error")
      end
  end.

-spec get_register_token(errm_http:request()) -> {ok, errm_http:response()}.
get_register_token(_Req) ->
  {ok, Token} = blog_secrets:get_register_token(),
  response_utils:ok(#{token => Token}).

-spec rotate(errm_http:request()) -> {ok, errm_http:response()}.
rotate(#{params := #{<<"secret">> := <<"register_token">>}}) ->
  blog_secrets:generate_register_token(),
  {ok, Token} = blog_secrets:get_register_token(),
  response_utils:ok(#{message => <<"Generated a new register token!">>, token => Token});
rotate(#{params := #{<<"secret">> := <<"jwt_secret">>}}) ->
  blog_secrets:gen_jwt_secret(),
  response_utils:ok(#{message => <<"Generated a new JWT secret!">>});
rotate(#{params := #{<<"secret">> := <<"cookie_key">>}}) ->
  blog_secrets:gen_cookie_secret(),
  response_utils:ok(#{message => <<"Generated a new cookie key!">>});
rotate(_Req) ->
  response_utils:error(400, "Invalid secret").
