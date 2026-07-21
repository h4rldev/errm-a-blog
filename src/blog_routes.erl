-module(blog_routes).
-export([get/0]).

-spec get() -> [errm_http:route()].
get() ->
  [
    {get, [":path*"], errm_http_file:serve_dir("site-root", ["index.html", "index.htm"], "200.html")},
    {get, ["api", "posts"], fun posts_api:get_all_posts/1},
    {get, ["api", "posts", ":amount"], fun posts_api:get_all_posts/1},
    {get, ["api", "post", ":id"], fun posts_api:get_post/1},
    {get, ["api", "post", ":slug"], fun posts_api:get_post/1},
    {post, ["api", "post"], fun posts_api:create_post/1},
    {put, ["api", "post", ":id"], fun posts_api:update_post/1},
    {put, ["api", "post", ":slug"], fun posts_api:update_post/1},
    {delete, ["api", "post", ":id"], fun posts_api:delete_post/1},
    {delete, ["api", "post", ":slug"], fun posts_api:delete_post/1},

    {get, ["api", "me"], fun user_api:get_user/1},

    {post, ["api", "auth", "register"], fun auth_api:register/1},
    {post, ["api", "auth", "login"], fun auth_api:login/1},
    {get, ["api", "auth", "logout"], fun auth_api:logout/1}
  ].
