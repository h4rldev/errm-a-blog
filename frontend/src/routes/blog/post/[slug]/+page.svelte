<script lang="ts">
import { onMount } from "svelte";
import type { HTMLAnchorAttributes } from "svelte/elements";
import Markdown from "svelte-exmarkdown";
import { goto } from "$app/navigation";
import { page } from "$app/state";
import Cell from "$components/Cell.svelte";
import EditPostModal from "$components/EditPostModal.svelte";
import Heading from "$components/Heading.svelte";
import Link from "$components/Link.svelte";
import { blog } from "$lib/blog.svelte";
import { blog_api, type Post } from "$lib/blog_api";

let post = $state<Post | null>(null);
let loading = $state<boolean>(true);
let error = $state<string | null>(null);
let show_edit_modal = $state<boolean>(false);

let slug = $derived(page.params.slug);

onMount(() => {
	blog.check();
});

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

$effect(() => {
	load_post();
});

const delete_post = async () => {
	if (!post) return;
	if (!blog.is_logged_in) {
		goto("/login");
		return;
	}

	if (!confirm(`Delete ${post.title}?`)) return;

	await blog_api.delete_post(post.id);
	goto("/blog");
};

const can_modify = (): boolean => {
	if (!blog.loading && !blog.is_logged_in) {
		console.log("not logged in, or blog loading");
		return false;
	}
	if (post?.slug !== slug && post?.id.toString() !== slug) {
		console.log(`post: ${post?.slug} !== slug: ${slug}`);
		console.log(`post: ${post?.id} !== slug: ${slug}`);
		return false;
	}
	if (post?.author.uuid !== blog.user?.uuid) {
		console.log(`post: ${post?.author.uuid} !== user: ${blog.user?.uuid}`);
		return false;
	}
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
        <Markdown md={post.content_markdown}>
          {#snippet a(props)}
            {@const { children,  download, href, hreflang, media, ping, rel, target, type, referrerpolicy } = props}
            <Link
              {href}
              target={target ?? undefined}
              {download}
              {media}
              {hreflang}
              {ping}
              {rel}
              {type}
              {referrerpolicy}
            >
              {@render children?.()}
            </Link>
          {/snippet}
        </Markdown>

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
  {/if}
    
</main>
