-module(blog_routes).
-export([get/0]).

-spec get() -> [errm_http:route()].
get() ->
  [
    %{get, ["api", "posts"], fun posts_api:get_all_posts/1},
    %{get, ["api", "posts", ":id"], fun posts_api:get_post/1},
    %{get, ["api", "posts", ":slug"], fun posts_api:get_post/1},
    %{post, ["api", "posts"], fun posts_api:create_post/1},
    %{put, ["api", "posts", ":id"], fun posts_api:update_post/1},
    %{delete, ["api", "posts", ":id"], fun posts_api:delete_post/1},

    {post, ["api", "auth", "register"], fun auth_api:register/1},
    {post, ["api", "auth", "login"], fun auth_api:login/1}
  ].
