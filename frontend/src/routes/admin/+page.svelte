<script lang="ts">
import { onMount, onDestroy } from "svelte";
import { blog } from "$lib/blog.svelte";
import { blog_api, type RotateRegisterToken } from "$lib/blog_api";

import Cell from "$components/Cell.svelte";

let token = $state<string | null>(null);
let token_length = $state<number>(0);

let show_token = $state<boolean>(false);
let interval = $state<NodeJS.Timer | null>(null);
let stats = $state<Stats | null>(null);

let copied = $state<boolean>(false);
let copy_timer = $state<NodeJS.Timer | null>(null);

let register_rotated = $state<boolean>(false);
let jwt_rotated = $state<boolean>(false);
let cookie_rotated = $state<boolean>(false);

let register_rotate_timer = $state<NodeJS.Timer | null>(null);
let jwt_rotate_timer = $state<NodeJS.Timer | null>(null);
let cookie_rotate_timer = $state<NodeJS.Timer | null>(null);


const fetch_token = async () => {
  const data = await blog_api.get_register_token();
  token = data.token;
  token_length = data.token.length;
};

const copy_token = async () => {
  if (!token) return;
  await navigator.clipboard.writeText(token);

  copied = true;
  clearTimeout(copy_timer);
  copy_timer = setTimeout(() => (copied = false), 1500);
};

const rotate = async (secret: string) => {
  switch (secret) {
    case "register":
      const resp: RotateRegisterToken = await blog_api.admin_secret_rotate("register_token");
      token = resp.token;

      register_rotated = true;
      clearTimeout(register_rotate_timer);
      register_rotate_timer = setTimeout(() => (register_rotated = false), 1500);
      break;

    case "jwt":
      if (!confirm("Are you sure you want to rotate the JWT secret? Every user will be logged out?")) return;
      blog_api.admin_secret_rotate("jwt_secret");
      blog.logout();

      jwt_rotated = true;
      clearTimeout(jwt_rotate_timer);
      jwt_rotate_timer = setTimeout(() => (jwt_rotated = false), 1500);
      break;

    case "cookie":
      if (!confirm("Are you sure you want to rotate the cookie key? Every user will be logged out")) return;
      blog_api.admin_secret_rotate("cookie_key");
      blog.logout();

      cookie_rotated = true;
      clearTimeout(cookie_rotate_timer);
      cookie_rotate_timer = setTimeout(() => (cookie_rotated = false), 1500);
      break;

    default:
      return;
  }
};

const role = $derived(blog.user?.role ?
  blog.user.role.split("-").map((w) => 
    w[0].toUpperCase() + w.slice(1)).join(" ") 
  : "",
);

onMount(() => {
  blog.check();
  blog_api.get_admin_stats().then((s) => (stats = s));

  fetch_token();
  interval = setInterval(fetch_token, 30000);
});

onDestroy(() => {
  clearInterval(interval);
  clearTimeout(register_rotate_timer);
  clearTimeout(jwt_rotate_timer);
  clearTimeout(cookie_rotate_timer);
  clearTimeout(copy_timer);
});

</script>

<main>
  <Cell title="Overview">
    <p class="text-center mb-2">Welcome, <span class="text-(--color-accent)">{blog.user?.username}</span>! (<span class="font-bold">{role}</span>)</p>
    {#if stats}
      <ul class="stats">
        <li>Total posts: {stats.total_posts}</li>
        <li>Total comments: {stats.total_comments}</li>
        <li>Total guestbook entries: {stats.total_guestbook_entries}</li>
      </ul>
    {/if}
  </Cell>
  <Cell title="Secrets">
    <div class="register-token">
      <div>
        <p>Register token:</p>
        <p class="text-(--color-subtext) min-w-80">
          {#if show_token}
          <code>{token}</code>
          {:else}
          <code>{"*".repeat(token?.token_length ?? 16)}</code>
          {/if}
        </p>
      </div>
      <div class="flex flex-row gap-2 justify-center items-center">
        <button class="show" onclick={() => (show_token = !show_token)}>
          {show_token ? "Hide" : "Show"}
        </button>
        <button class="copy" onclick={copy_token}>
          {copied ? "Copied!" : "Copy"}
        </button>
        <button class="rotate" onclick={() => {rotate("register")}}>
          {register_rotated ? "Rotated!" : "Rotate"}
        </button>
      </div>
    </div>
    <div class="secrets">
      <button class="secret-rotate" onclick={() => {rotate("jwt");}}>{jwt_rotated ? "Rotated!" : "Rotate JWT Secret?"}</button>
      <button class="secret-rotate" onclick={() => {rotate("cookie");}}>{cookie_rotated ? "Rotated!" : "Rotate Cookie Key?"}</button>
    </div>
  </Cell>
</main>

<style>
  @reference "$tailcss";

  .stats {
    @apply flex flex-row gap-8 justify-center;
  }

  .show {
    @apply hover:cursor-pointer font-bold px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay) w-20;
  }

  .copy {
    @apply hover:cursor-pointer font-bold px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay) w-20;
  }

  .rotate {
    @apply hover:cursor-pointer font-bold text-(--color-bg) px-2 bg-(--color-error) active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay) w-20;
  }

  .secret-rotate {
    @apply hover:cursor-pointer font-bold text-(--color-bg) px-2 bg-(--color-error) active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay) w-54;
  }

  .secrets {
    @apply flex flex-row gap-8 justify-center w-full mt-6 mb-2;
  }

  .register-token {
    @apply flex flex-row gap-4 justify-center w-full mt-2;
  }

  code {
    @apply font-mono;
  }

</style>
