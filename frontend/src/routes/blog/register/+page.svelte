<script lang="ts">
 import Cell from "$components/Cell.svelte";
 import Meta from "$components/Meta.svelte";
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

<Meta title="Register" path="/blog/register/" />
<main>
  <Cell title="Register">
    <div class="form-container">
      <Heading level="2">
        Register
      </Heading>
      <form onsubmit={handle_submit} class="register-form">
        <label class="auth-label" for="register-username">
          USERNAME
          <input class="auth-input" id="register-username" name="username" type="text" bind:value={username} autocomplete="username" required />
        </label>
        <label class="auth-label" for="register-password">
          PASSWORD
          <input class="auth-input" id="register-password" name="password" type="password" bind:value={password} autocomplete="new-password" required />
        </label>
        <label class="auth-label" for="register-token">
          REGISTER TOKEN
          <input class="auth-input" id="register-token" name="register_token" type="password" bind:value={register_token} autocomplete="off" required />
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
