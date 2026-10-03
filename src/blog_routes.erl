-module (blog_routes).
-export ([get/0]).

-spec get() -> [errm_http:route()].
get() ->
  [
    {get, [":path*"], errm_http_file:serve_dir("site-root", ["index.html", "index.htm"], "200.html")},
    {get, ["api", "posts"], fun posts_api:get_all_posts/1},
    {get, ["api", "posts", ":amount"], fun posts_api:get_all_posts/1},
    {get, ["api", "post", ":id"], fun posts_api:get_post/1},
    {post, ["api", "post"], fun posts_api:create_post/1},
    {put, ["api", "post", ":id"], fun posts_api:update_post/1},
    {delete, ["api", "post", ":id"], fun posts_api:delete_post/1},

    {get, ["api", "admin", "stats"], fun admin_api:get_stats/1},
    {get, ["api", "admin", "register_token"], fun admin_api:get_register_token/1},
    {get, ["api", "admin", "users"], fun admin_api:get_users/1},

    {post, ["api", "admin", "rotate", ":secret"], fun admin_api:rotate/1},

    {patch, ["api", "admin", "edit_user"], fun admin_api:edit_user/1},

    {get, ["api", "admin", "blocked_words", ":scope"], fun blocked_words_api:get_all/1},
    {put, ["api", "admin", "blocked_words", ":scope"], fun blocked_words_api:set/1},

    {get, ["api", "admin", "notifications"], fun notifications_api:get_all/1},
    {delete, ["api", "admin", "notifications"], fun notifications_api:clear/1},

    {post, ["api", "post", ":post_id", "comments"], fun comments_api:create_comment/1},
    {put, ["api", "post", ":post_id", "comments", ":comment_id"], fun comments_api:edit_comment/1},
    {delete, ["api", "post", ":post_id", "comments", ":comment_id"], fun comments_api:delete_comment/1},

    {post, ["api", "guestbook"], fun guestbook_api:create_guestbook_entry/1},
    {put, ["api", "guestbook", ":id"], fun guestbook_api:update_guestbook_entry/1},
    {delete, ["api", "guestbook", ":id"], fun guestbook_api:delete_guestbook_entry/1},

    {get, ["api", "tags"], fun posts_api:get_tags/1},

    {get, ["api", "me"], fun user_api:get_current_user/1},

    {post, ["api", "auth", "register"], fun auth_api:register/1},
    {post, ["api", "auth", "login"], fun auth_api:login/1},
    {get, ["api", "auth", "logout"], fun auth_api:logout/1},
    {get, ["ws"], fun ws_upgrade/1}
  ].

ws_upgrade(Req) ->
  case blog_middlewares:authenticate(Req) of
    {ok, UserId, _Claims} ->
      {upgrade, errm_ws, {blog_ws_handler, #{user_id => UserId}}};
    {error, _} ->
      {upgrade, errm_ws, {blog_ws_handler, #{user_id => undefined}}}
  end.
