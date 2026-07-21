<script lang="ts">
import Cell from "$components/Cell.svelte";
import Link from "$components/Link.svelte";
import Heading from "$components/Heading.svelte";

import { goto } from "$app/navigation";
import { blog_api } from "$lib/blog_api";


let username = $state<string | null>(null);
let password = $state<string | null>(null);
let register_token = $state<string | null>(null);

let error = $state<string | null>(null);
let loading = $state<boolean>(false);

const handle_submit = async (e: Event) => {
  e.preventDefault();

  if (!username || !password || !register_token) {
    error = 'Username, password, and register token are required';
    return;
  }

  loading = true;
  error = '';
  try {
    await blog_api.register({ username, password, register_token });
    goto('/blog');
  } catch (err: any) {
    error = err.message || 'Registration failed';
  } finally {
    loading = false;
  }
}
</script>


<main>
  <Cell title="Register">
    <div class="form-container">
    <Heading level="2">
      Register
    </Heading>
    <form onsubmit={handle_submit} class="register-form">
      <label class="username">
        USERNAME
        <input type="text" bind:value={username} autocomplete="username" required />
      </label>
      <label>
        PASSWORD
        <input type="password" bind:value={password} autocomplete="new-password" required />
      </label>
      <label>
        REGISTER TOKEN
        <input type="password" bind:value={register_token} required />
      </label>
      {#if error}
        <p class="text-(--color-error)">{error}</p>
      {/if}
      <button type="submit" class="button-register" disabled={loading}>
        {loading ? 'Loading...' : 'Register'}
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

  .register-form {
    @apply flex flex-col gap-4 lg:w-1/3;
  }

  input {
    @apply bg-(--color-bg) text-(--color-text) p-2 w-full active:border-(--color-accent) active:outline-none active:ring-(--color-accent) focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
  }

  label {
    @apply flex flex-col text-xs text-(--color-accent);
  }

  .button-register {
    @apply hover:cursor-pointer bg-(--color-accent) text-(--color-bg) font-bold py-2 px-4 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out;
  } 

</style>
