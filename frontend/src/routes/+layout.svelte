<script lang="ts">
import "../app.css";
import favicon from "$lib/assets/favicon.svg";
import { theme } from "$lib/stores/theme.svelte";

$effect(() => {
	document.documentElement.classList.toggle("dark", theme.value === "dark");
});

let { children } = $props();
</script>

<svelte:head>
  <link rel="icon" href={favicon} />
  <script>
    (function() {
      let theme = localStorage.getItem('theme');
      if (!theme) {
        theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      }
      if (theme === 'dark') {
        document.documentElement.classList.add('dark');
      }
    })();
  </script>
</svelte:head>

{@render children()}

<style>
@reference '$tailcss';

:global(html) {
  @apply bg-[var(--color-bg)] text-[var(--color-text)];
}

</style>
