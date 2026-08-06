<script lang="ts">
import { onMount, onDestroy } from "svelte";
import { goto } from "$app/navigation";
import { page } from "$app/state";
import { blog } from "$lib/blog.svelte";
import { blog_api, type Post, type Comment } from "$lib/blog_api";
import type { HTMLAnchorAttributes } from "svelte/elements";

import RichMarkdown from "$components/RichMarkdown.svelte";
import Cell from "$components/Cell.svelte";
import EditPostModal from "$components/EditPostModal.svelte";
import Heading from "$components/Heading.svelte";
import Link from "$components/Link.svelte";


let post = $state<Post | null>(null);
let loading = $state<boolean>(true);
let is_submitting = $state<boolean>(false);
let error = $state<string | null>(null);
let show_edit_modal = $state<boolean>(false);
let ws = $state<WebSocket | null>(null);
let comments = $state<Comment[]>([]);
let timeout_id = $state<number | null>(null);

let username = $state<string | null>(null);
let content = $state<string | null>(null);

let slug = $derived(page.params.slug);

const is_dev = import.meta.env.DEV;
const is_prod = import.meta.env.PROD;
const url = is_dev ? "http://localhost:8080" : is_prod ? "" : "http://localhost:8080";
const full_url = url + "/ws";

const load_post = async () => {
	loading = true;
	error = null;

	try {
		post = await blog_api.get_post(slug);
	} catch (e: any) {
		error = e.message || "Failed to load post";
		post = null;
	} finally {
		loading = false;
	}
};

const handle_submit = async (e: Event) => {
  e.preventDefault();

  if (content === null || content === "") {
    error = "Content is required";
    return;
  };

  if (post?.id === undefined) {
    error = "Post is required";
    return;
  };

  const payload = {
    username: username.trim(),
    content_markdown: content.trim(),
  };

  is_submitting = true;
  error = "";
  try {
    await blog_api.create_comment(payload, post?.id);
  } catch (err: any) {
    error = err.message || "Failed to create comment";
  } finally {
    is_submitting = false;
  }
};


onMount(() => {
	blog.check();

  ws = new WebSocket(full_url);
  ws.onopen = () => {
    ws.send(JSON.stringify({ event: "subscribe", channel: "post_" + post?.id }));
    ws.send(JSON.stringify({ event: "fetch_post_comments", post_id: post?.id }));
  };
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    switch (msg.event) {
      case "post_comments:initial":
        comments = msg.comments;
        comments = comments.sort((a, b) => b.posted_at - a.posted_at);
        break;
      case "post_comments:new":
        comments = [...comments, msg];
        comments = comments.sort((a, b) => b.posted_at - a.posted_at);
        break;
      case "post_comments:edited":
        comments = comments.map((comment) => (comment.id === msg.id ? msg : comment));
        comments = comments.sort((a, b) => b.posted_at - a.posted_at);
        break;
      case "post_comments:deleted":
        comments = comments.filter((comment) => comment.id !== msg.id);
        comments = comments.sort((a, b) => b.posted_at - a.posted_at);
        break;
      default:
        console.log("Unknown event:", msg);
        break;
    }
  };

  timeout_id = setTimeout(() => {
    ws.send(JSON.stringify({ event: "subscribe", channel: "post_" + post?.id }));
    ws.send(JSON.stringify({ event: "fetch_post_comments", post_id: post?.id }));
  }, 30000);
});

onDestroy(() => {
  clearTimeout(timeout_id);
  ws.close();
});

$effect(() => {
	load_post();
});

const delete_post = async () => {
	if (!post) return;
	if (!blog.is_logged_in) {
		goto("/login");
		return;
	}

	if (!confirm(`Delete ${post.title} by ${post.author.username}?`)) return;

	await blog_api.delete_post(post.id);
	goto("/blog");
};

const can_modify = (): boolean => {
	if (!blog.loading && !blog.is_logged_in) return false;
	if (post?.slug !== slug && post?.id.toString() !== slug) return false;
	if (post?.author.uuid !== blog.user?.uuid && !blog.user?.role.includes("admin")) return false;
	return true;
};
</script>

<main>
  <Cell title="Post">
  {#if loading}
    <p>Loading post...</p>
  {:else if error}
    <p class="text-(--color-danger)">{error}</p>
  {:else if post}
      <p class="absolute text-xs top-1"><Link href="/blog" target="_self">{`<-`} Back to blog</Link></p>
      <Cell title="metadata">
        <Heading level="1">{post.title}</Heading>
        <p class="">Slug: {post.slug}</p>
        <p class="">Summary: {post.summary}</p>
        <p> Tags: {post.tags.join(", ")} </p>
        <p> Posted at: {blog_api.convert_unix_timestamp_to_date(post.posted_at)}, edited at: {post.last_edited_at === null ? "never" : blog_api.convert_unix_timestamp_to_date(post.last_edited_at)} </p>
      </Cell>
      <Cell title="Content">
        <RichMarkdown render_images=true md={post.content_markdown} />
        {#if can_modify()}
          <div class="mt-4">
            <ul class="post-actions">
              <li><button class="button-edit" onclick={() => { show_edit_modal = !show_edit_modal; post_to_edit = post; }}>Edit</button></li>
              <li><button class="button-delete" onclick={delete_post}>Delete</button></li>
            </ul>
          </div>
        {/if}
      </Cell>
  {/if}
  </Cell>
  {#if show_edit_modal}
    <EditPostModal show={show_edit_modal} on_close={() => { show_edit_modal = false; }} on_edit={() => { load_post(); }} post_id={post?.id} post_slug={post?.slug} />
  {:else}
    <Cell title="Comments">
      <Cell title="Post A Comment">
        <div class="form-container">
          <form onsubmit={handle_submit} class="guestbook-form">
            <label class="username">
              USERNAME
              <input type="text" name="username" bind:value={username} autocomplete="username" placeholder="Anonymous" />
            </label>
            <label class="content">
              CONTENT (MARKDOWN)
              <textarea bind:value={content} name="content" required placeholder="Write something..."></textarea>
            </label>
            <button type="submit" class="button-guestbook" disabled={loading}>
              {loading ? 'Loading...' : 'Submit'}
            </button>
          </form>
        </div>
      </Cell>
      {#each comments as comment}
        <Cell title="Comment">
          <div class="title-and-meta">
            <p class="font-bold">{comment.username}</p>
            <p class="text-xs">{blog_api.convert_unix_timestamp_to_date(comment.posted_at)}</p>
            <p class="text-xs">{comment.edited_at ? blog_api.convert_unix_timestamp_to_date(comment.last_edited_at) : "never"}</p>
          </div>
          <RichMarkdown md={comment.content_markdown} />
        </Cell>
      {/each}
    </Cell>
  {/if}
</main>
