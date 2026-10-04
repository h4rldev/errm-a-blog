<script lang="ts">
 import { onMount } from "svelte";
 import { goto } from "$app/navigation";

 import Cell from "$components/Cell.svelte";
 import PostModal from "$components/PostModal.svelte";
 import Meta from "$components/Meta.svelte";
 import Heading from "$components/Heading.svelte";
 import Link from "$components/Link.svelte";
 import Pagination from "$components/Pagination.svelte";
 import { blog } from "$lib/blog.svelte";
 import { blog_api, type Post, type User } from "$lib/blog_api";

 let posts = $state<Post[]>([]);
 let total_posts = $state<number>(0);
 let loading = $state<boolean>(true);
 let error = $state<string | null>(null);
 let show_modal = $state<boolean>(false);
 let show_edit_modal = $state<boolean>(false);
 let post_to_edit = $state<Post | null>(null);

 let per_page = $state(20);
 let order = $state<"newest" | "oldest">("newest");
 let page = $state(1);

 const post_filter = (post: Post, q: string): boolean =>
   [post.title, post.summary, post.content_markdown, post.author?.username].some(
     (v) => typeof v === "string" && v.toLowerCase().includes(q),
   );

 const load = async () => {
   try {
     const data = await blog_api.get_posts();
     posts = data.posts;
     total_posts = data.amount;
   } catch (e: any) {
     error = e.message;
   } finally {
     loading = false;
   }
 };

 const can_do_actions = () => {
   return !blog.loading && blog.is_logged_in ? true : false;
 };

 const delete_post = async (post: Post) => {
   if (!post) {
     error = "No post found, something is wrong";
     return;
   }

   if (!blog.is_logged_in) {
     error = "You need to be logged in to delete a post";
     goto("/login/");
     return;
   }

   if (!confirm(`Delete ${post.title} by ${post.author.username}?`)) return;
   await blog_api.delete_post(post.id.toString());
   load();
 };

 onMount(() => {
   blog.check();
   load();
 });
</script>
<Meta title="Blog" path="/blog/" />
<main>
  <Cell title="Blog">
    <div class="things">
      <p class="text-(--color-accent) text-[8px] absolute top-1 left-2">TOTAL POSTS: {total_posts}</p>

      {#if can_do_actions()}
        <div class="actions">
          <ul>
            <li><button class="button-create-post" onclick={() => { show_modal = !show_modal; }}>New post</button></li>
            {#if blog.user}
              <li class="flex flex-col justify-center">
                <p class="text-(--color-accent)">Welcome {blog.user.username}</p>
              </li>
            {/if}
            <li><button class="button-logout" onclick={blog.logout}>Logout</button></li>
          </ul>
        </div>
      {:else}
        <div class="auth">
          <ul class="auth-links">
            <li><Link href="/blog/login/" target="_self">Login</Link></li>
            <li><Link href="/blog/register/" target="_self">Register</Link></li>
          </ul>
        </div>
      {/if}
    </div>
  </Cell>
  <div class="posts-wrapper">
    {#if show_modal}
      <PostModal show={show_modal} on_close={() => { show_modal = false; }} on_saved={() => { load(); }} />
    {:else if show_edit_modal}
      <PostModal show={show_edit_modal} on_close={() => { show_edit_modal = false; }} on_saved={() => { load(); }} post_id={post_to_edit?.id} post_slug={post_to_edit?.slug} />
    {:else}
        <Cell title="Posts">
          {#if loading}
            <p>Loading...</p>
          {:else if error}
            <p class="text-(--color-error)">{error}</p>
          {:else if posts.length === 0}
            <p>No posts available</p>
          {:else}
            <Pagination items={posts} bind:per_page bind:order bind:page filter={post_filter}>
              {#snippet children(visible)}
                <ul>
                  {#each visible as post}
                    {@const identifier = post.slug === "" ? post.id : post.slug}
                    {@const summary = (post.summary || post.content_markdown).length > 50 ? (post.summary || post.content_markdown).slice(0, 50) + '...' : (post.summary || post.content_markdown)}
                    <li>
                      <Cell title="Post">
                        <div class="title-and-actions">
                          <a href="/blog/post/{identifier}/" class="post-link" target="_self">
                            <Heading level="3">
                              <span class="title">{post.title}</span>
                            </Heading>
                          </a>

                          {#if post.author.uuid === blog.user?.uuid || blog.user?.role.includes("admin")}
                            <ul class="post-actions mt-1">
                              <li><button class="button-edit" onclick={() => { show_edit_modal = !show_edit_modal; post_to_edit = post; }}>Edit</button></li>
                              <li><button class="button-delete" onclick={() => {delete_post(post)}}>Delete</button></li>
                            </ul>
                          {/if}
                        </div>
                        <div class="post_specific">
                          <p> {summary} </p>
                          <p> by {post.author.username} at {blog_api.convert_unix_timestamp_to_date(post.posted_at)}, edited {post.edited_at === null ? "never" : blog_api.convert_unix_timestamp_to_date(post.edited_at)} </p>
                        </div>
                      </Cell>
                    </li>
                  {/each}
                </ul>
              {/snippet}
            </Pagination>
          {/if}
        </Cell>
    {/if}
  </div>
</main>

 <style>
 @reference "$tailcss";

 .auth {
   @apply flex flex-col justify-center;
 }

 .auth-links {
   @apply inline-flex flex-wrap justify-center flex-row gap-4;
 }

 .post-link:hover .title {
   @apply text-(--color-accent) underline;
 }

 .title-and-actions {
   @apply flex flex-row justify-between;
 }

 .post-actions {
   @apply flex flex-row gap-2 z-50;
 }
 
 .button-logout {
   @apply min-w-24;
   @apply hover:cursor-pointer bg-(--color-error) text-(--color-bg) font-bold py-1 px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay);
 }

 .post_specific {
   @apply flex flex-row justify-between;
 }
 
 .actions {
   @apply flex flex-row w-full gap-4 justify-center;
 }

 .actions > ul {
   @apply flex flex-row justify-between w-full mt-2;
 }

</style>
