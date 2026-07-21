<script lang="ts">
import type { HTMLAnchorAttributes } from "svelte/elements";
import Markdown from "svelte-exmarkdown";
import { goto } from "$app/navigation";
import { page } from "$app/state";
import Cell from "$components/Cell.svelte";
import Link from "$components/Link.svelte";
import { blog } from "$lib/blog.svelte";
import { blog_api, type Post } from "$lib/blog_api";
import { onMount } from "svelte";


let post = $state<Post | null>(null);
let loading = $state<boolean>(true);
let error = $state<string | null>(null);

let slug = $derived(page.params.slug);

onMount(() => {
  blog.check();
});

$effect(() => {
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

	load_post();
});

const delete_post = async () => {
	if (!post) return;
	if (!blog.is_logged_in) {
		goto("/login");
		return;
	}

	if (!confirm(`Delete ${post.title}?`)) return;

	try {
		await blog_api.delete_post(post.id);
		goto("/blog");
	} catch (e: any) {
		alert(e.message || "Failed to delete post");
	}
};

const can_modify = (): boolean => {
	if (!blog.loading && !blog.is_logged_in) {
    console.log('not logged in, or blog loading');
    return false;
  }
	if (post?.slug !== slug && post?.id.toString() !== slug) {
    console.log(`post: ${post?.slug} !== slug: ${slug}`);
    console.log(`post: ${post?.id} !== slug: ${slug}`);
    return false;
  }
	if (post?.author_id !== blog.user?.uuid) {
    console.log(`post: ${post?.author_id} !== user: ${blog.user?.uuid}`);
    return false;
  }
	return true;
};
</script>

<main>
  {#if loading}
    <p>Loading post...</p>
  {:else if error}
    <p class="text-(--color-danger)">{error}</p>
  {:else if post}
    <Cell title="Post">
      <p class="absolute text-xs top-1"><Link href="/blog" target="_self">{`<-`} Back to blog</Link></p>
      <Cell title="metadata">
        <h1>{post.title}</h1>
        <p class="">{post.slug}</p>
        <p class="">{post.summary}</p>
        <p> Tags: {post.tags.join(", ")} </p>
      </Cell>
      <div class="content">
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
      </div>

      {#if can_modify()}
        <div class="actions">
          <a href="/blog/post/{post.slug}/edit" class="button button-edit">Edit</a>
          <button class="button button-delete" onclick={delete_post}>Delete</button>
        </div>
      {/if}
    </Cell>
  {/if}
</main>
