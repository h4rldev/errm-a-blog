<script lang="ts">
 import { onMount } from "svelte";
 import { goto } from "$app/navigation";
 import Cell from "$components/Cell.svelte";
 import Heading from "$components/Heading.svelte";
 import Link from "$components/Link.svelte";
 import Meta from "$components/Meta.svelte";
 import { blog } from "$lib/blog.svelte";

 let username = $state<string | null>(null);
 let password = $state<string | null>(null);

 let error = $state<string | null>(null);
 let loading = $state<boolean>(false);

 const handle_submit = async (e: Event) => {
   e.preventDefault();

   if (!username || !password) {
     error = "Username, and password are required";
     return;
   }

   loading = true;
   error = "";
   try {
     await blog.login(username, password);
     goto("/blog");
   } catch (err: any) {
     error = err.message || "Login failed";
   } finally {
     loading = false;
   }
 };

 onMount(() => {
   blog.check();
 });
</script>

<Meta title="Login" path="/blog/login/" />
<main>
  <Cell title="Login">
    <div class="form-container">
      <Heading level="2">
        Login
      </Heading>
      <form onsubmit={handle_submit} class="login-form">
        <label class="auth-label" for="login-username">
          USERNAME
          <input class="auth-input" id="login-username" name="username" type="text" bind:value={username} autocomplete="username" required />
        </label>
        <label class="auth-label" for="login-password">
          PASSWORD
          <input class="auth-input" id="login-password" name="password" type="password" bind:value={password} autocomplete="current-password" required />
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
