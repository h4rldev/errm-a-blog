<script lang="ts">
import Cell from "$components/Cell.svelte";
import Link from "$components/Link.svelte";
import Heading from "$components/Heading.svelte";

import { goto } from "$app/navigation";
import { blog } from "$lib/blog.svelte";
import { onMount } from "svelte";


let username = $state<string | null>(null);
let password = $state<string | null>(null);

let error = $state<string | null>(null);
let loading = $state<boolean>(false);

const handle_submit = async (e: Event) => {
  e.preventDefault();

  if (!username || !password) {
    error = 'Username, and password are required';
    return;
  }

  loading = true;
  error = '';
  try {
    await blog.login(username, password);
    goto('/blog');
  } catch (err: any) {
    error = err.message || 'Login failed';
  } finally {
    loading = false;
  }
}

  onMount(() => {
    blog.check();
  });

  $effect(() => {
    console.log('effect');
    if (!blog.loading && blog.is_logged_in) {
      console.log('redirecting');
      goto('/blog');
    }
  });

</script>


<main>
  <Cell title="Login">
    <div class="form-container">
    <Heading level="2">
      Login
    </Heading>
    <form onsubmit={handle_submit} class="login-form">
      <label class="username">
        USERNAME
        <input type="text" bind:value={username} autocomplete="username" required />
      </label>
      <label>
        PASSWORD
        <input type="password" bind:value={password} autocomplete="new-password" required />
      </label>
      {#if error}
        <p class="text-(--color-error)">{error}</p>
      {/if}
      <button type="submit" class="button-login" disabled={loading}>
        {loading ? 'Loading...' : 'Login'}
      </button>
    </form>
    </div>
  </Cell>
</main>

<style>
  @reference "$tailcss";
  .form-container {
    @apply flex flex-col justify-center items-center font-arimo mb-4;
  }

  .login-form {
    @apply flex flex-col gap-4 lg:w-1/3;
  }

  input {
    @apply bg-(--color-bg) text-(--color-text) p-2 w-full active:border-(--color-accent) active:outline-none active:ring-(--color-accent) focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
  }

  label {
    @apply flex flex-col text-xs text-(--color-accent);
  }

  .button-login {
    @apply hover:cursor-pointer bg-(--color-accent) text-(--color-bg) font-bold py-2 px-4 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out;
  } 

</style>
