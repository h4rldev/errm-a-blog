<script lang="ts">
 import "../app.css";
 import Footer from "$components/Footer.svelte";
 import Header from "$components/Header.svelte";
 import Meta from "$components/Meta.svelte";
 import { theme } from "$lib/stores/theme.svelte";

 $effect(() => {
   document.documentElement.classList.toggle("dark", theme.value === "dark");
 });

 let { children } = $props();
</script>

<svelte:head>
  <link rel="icon" href="/favicon.ico" sizes="any" />
  <link rel="apple-touch-icon" href="/og.webp" />
  <script>
   (function() {
     let theme = localStorage.getItem('theme');
     if (!theme)
       theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
     if (theme === 'dark')
       document.documentElement.classList.add('dark');
   })();
  </script>
</svelte:head>

<Header />
{@render children()}
<Footer />

<style>
 @reference '$tailcss';

 :global(html) {
   @apply bg-(--color-bg) text-(--color-text) max-w-full;
 }

</style>
