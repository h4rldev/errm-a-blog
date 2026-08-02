<script lang="ts">
import { onMount } from "svelte";
import Cell from "$components/Cell.svelte";
import CreatePostModal from "$components/CreatePostModal.svelte";
import EditPostModal from "$components/EditPostModal.svelte";
import Heading from "$components/Heading.svelte";
import Link from "$components/Link.svelte";
import { blog } from "$lib/blog.svelte";
import type { Post } from "$lib/blog_api";
import { blog_api } from "$lib/blog_api";

interface User {
	uuid: string;
	username: string;
	role: string;
}

let posts = $state<Post[]>([]);
let total_posts = $state<number>(0);
let loading = $state<boolean>(true);
let error = $state<string | null>(null);
let current_user = $state<User | null>(null);
let show_modal = $state<boolean>(false);
let show_edit_modal = $state<boolean>(false);
let post_to_edit = $state<Post | null>(null);

onMount(() => {
	blog.check();
});

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


$effect(() => {
	current_user = blog.user ? blog.user : null;
	load();
});

const can_do_actions = () => {
	if (!blog.loading && !blog.is_logged_in) return false;

	return true;
};

const delete_post = async (post: Post) => {
  if (!post) return;
	if (!blog.is_logged_in) {
		goto("/login");
		return;
	}

	if (!confirm(`Delete ${post.title}?`)) return;

	await blog_api.delete_post(post.id);
  load();
};


const logout = () => {
	blog.logout();
};
</script>

<main>
  <Cell title="Blog">
    <div class="things">
      <p class="text-(--color-accent) text-[8px] absolute top-1 left-2">TOTAL POSTS: {total_posts}</p>

      {#if can_do_actions()}
      <div class="actions">
        <ul>
          <li><button class="button-create-post" onclick={() => { show_modal = !show_modal; }}>New post</button></li>
          {#if current_user}
          <li class="flex flex-col justify-center">
            <p class="text-(--color-accent)">Welcome {current_user.username}</p>
          </li>
          {/if}
          <li><button class="button-logout" onclick={logout}>Logout</button></li>
        </ul>
      </div>
      {:else}
      <div class="authentication">
        <ul>
          <li><Link href="/blog/login" target="_self">Login</Link></li>
          <li><Link href="/blog/register" target="_self">Register</Link></li>
        </ul>
      </div>
      {/if}
    </div>
  </Cell>
  <div class="posts-wrapper">
 

  {#if show_modal}
  <CreatePostModal show={show_modal} on_close={() => { show_modal = false; }} on_post={() => { load(); }} />
  {:else if show_edit_modal}
  <EditPostModal show={show_edit_modal} on_close={() => { show_edit_modal = false; }} on_edit={() => { load(); }} post_id={post_to_edit?.id} post_slug={post_to_edit?.slug} />
  {:else}
  <Cell title="Posts">
    {#if loading}
      <p>Loading...</p>
    {:else if error}
      <p class="text-(--color-error)">{error}</p>
    {:else}
    <ul>
      {#each posts as post}
        <li>
          {#if post.slug === ""}
            {@const identifier = post.id}
            {#if post.summary === ""}
              {@const summary = post.content.length > 50 ? post.content.slice(0, 50) + '...' : post.content}
              <a href="/blog/post/{identifier}" class="post-link" target="_self">
                <Cell title="Post">
                  <Heading level="3">
                    <span class="title">{post.title}</span>
                  </Heading>
                  <div class="post_specific">
                    <p> {summary} </p>
                    <p> by {post.author.username} at {blog_api.convert_unix_timestamp_to_date(post.posted_at)}, edited {post.last_edited_at === null ? "never" : blog_api.convert_unix_timestamp_to_date(post.last_edited_at)} </p>
                  </div>
                </Cell>
              </a>
            {:else}
              {@const summary = post.summary.length > 50 ? post.summary.slice(0, 50) + '...' : post.summary}
              <a href="/blog/post/{identifier}" class="post-link" target="_self">
                <Cell title="Post">
                  <Heading level="3">
                    <span class="title">{post.title}</span>
                  </Heading>
                  <div class="post_specific">
                    <p> {summary} </p>
                    <p> by {post.author.username} at {blog_api.convert_unix_timestamp_to_date(post.posted_at)}, edited {post.last_edited_at === null ? "never" : blog_api.convert_unix_timestamp_to_date(post.last_edited_at)} </p>
                  </div>
                </Cell>
              </a>
            {/if}
          {:else}
            {@const identifier = post.slug}
            {#if post.summary === ""}
              {@const summary = post.content.length > 50 ? post.content.slice(0, 50) + '...' : post.content}
                <Cell title="Post">
                  <a href="/blog/post/{identifier}" class="post-link" target="_self">
                    <Heading level="3">
                      <span class="title">{post.title}</span>
                    </Heading>
                  </a>
                  <div class="post_specific">
                    <p> {summary} </p>
                    <p> by {post.author.username} at {blog_api.convert_unix_timestamp_to_date(post.posted_at)}, edited {post.last_edited_at === null ? "never" : blog_api.convert_unix_timestamp_to_date(post.last_edited_at)} </p>
                  </div>
                </Cell>
            {:else}
              {@const summary = post.summary.length > 50 ? post.summary.slice(0, 50) + '...' : post.summary}
                <Cell title="Post">
                  <div class="title-and-actions">
                    <a href="/blog/post/{identifier}" class="post-link" target="_self">
                      <Heading level="3">
                        <span class="title">{post.title}</span>
                      </Heading>
                    </a>
                    {#if post.author.uuid === blog.user?.uuid}
                      <ul class="post-actions">
                        <li><button class="button-edit" onclick={() => { show_edit_modal = !show_edit_modal; post_to_edit = post; }}>Edit</button></li>
                        <li><button class="button-delete" onclick={delete_post}>Delete</button></li>
                      </ul>
                    {/if}
                  </div>
                  <div class="post_specific">
                    <p> {summary} </p>
                    <p> by {post.author.username} at {blog_api.convert_unix_timestamp_to_date(post.posted_at)}, edited {post.last_edited_at === null ? "never" : blog_api.convert_unix_timestamp_to_date(post.last_edited_at)} </p>
                  </div>
                </Cell>
            {/if}
          {/if}
        </li>
      {/each}
    </ul>
    {/if}
  </Cell>
  {/if}
  </div>
</main>

<style>
  @reference "$tailcss";

  .post-link:hover .title {
    @apply text-(--color-accent) underline;
  }

  .title-and-actions {
    @apply flex flex-row justify-between;
  }

  .post-actions {
    @apply flex flex-row gap-2 z-50;
  }

  .post-link {
    @apply text-(--color-text) w-full;
  }

  .button-create-post {
    @apply min-w-24;
    @apply hover:cursor-pointer bg-(--color-accent) text-(--color-bg) font-bold py-1 px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay);
  }

  .button-delete,
  .button-logout {
    @apply min-w-24;
    @apply hover:cursor-pointer bg-(--color-error) text-(--color-bg) font-bold py-1 px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay);
  }

  .button-edit {
    @apply min-w-24;
    @apply hover:cursor-pointer bg-(--color-confirm) text-(--color-bg) font-bold py-1 px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay);
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
