<script lang="ts">
import Cell from "$components/Cell.svelte";
import Link from "$components/Link.svelte";
import { blog } from "$lib/blog.svelte";
import type { Post } from "$lib/blog_api";
import { blog_api } from "$lib/blog_api";
import { onMount } from "svelte";

let posts = $state<Post[]>([]);
let total_posts = $state<number>(0);
let loading = $state<boolean>(true);
let error = $state<string | null>(null);

onMount(() => {
  blog.check();
});

$effect(() => {
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

	load();
});

const can_do_actions = () => {
  if (!blog.loading && !blog.is_logged_in) return false;

  return true;
};

</script>

<main>
  <Cell title="Blog">
    <div class="things">
      <p>Total posts: {total_posts}</p>
      {#if can_do_actions()}
      <div class="actions">
        <ul>
          <li><button class="button-create-post">New post</button></li>
          <li><button class="button-logout">Logout</button></li>
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
            <Link href="/blog/post/{post.id}" target="_self">{post.title}</Link>
          {:else}
            <Link href="/blog/post/{post.slug}" target="_self">{post.title}</Link>
          {/if}
        </li>
      {/each}
    </ul>
    {/if}
  </Cell>
</main>

<style>
  .button-create-post {
    @apply hover:cursor-pointer hover:underline text-(--color-link) hover:text-(--color-accent);
  }

  .button-logout {
    @apply hover:cursor-pointer hover:underline text-(--color-link) hover:text-(--color-error);
  }
</style>
