<script lang="ts">
 import { onMount } from "svelte";
 import { blog } from "$lib/blog.svelte";

 import Link from "$components/Link.svelte";
 import ThemeToggle from "$components/ThemeToggle.svelte";

 const is_admin = $derived(
   blog.user?.role === "administrator" || blog.user?.role === "super-administrator",
 );

 onMount(() => {
   blog.check();
 });
</script>

<header>
  <div class="header-container">
    <div class="me-ascii">
      <p>.__        _____        .__
|  |__    /  |  |_______|  |
|  |  \  /   |  |\_  __ \  |
|   Y  \/    ^   /|  | \/  |__
|___|  /\____   | |__|  |____/
     \/      |__|
      </p>
    </div>
    <div>
      <nav>
        <ul class="navigation">
          <li><Link href="/" target="_self" >home</Link></li>
          <li><Link href="/blog/" target="_self">blog</Link></li>
          <li><Link href="/guestbook/" target="_self">guestbook</Link></li>
          <li><Link href="/projects/" target="_self">projects</Link></li>
          <li><Link href="/contact/" target="_self">contact</Link></li>
          {#if is_admin}
            <li><Link href="/admin/" target="_self">admin</Link></li>
          {/if}
          <li><ThemeToggle /></li>
        </ul>
      </nav>
    </div>
  </div>
</header>

<style>
 @reference '$tailcss';

 header {
   @apply max-w-full flex flex-row items-center justify-center mt-8 text-base;
 }

 .header-container {
   @apply lg:w-200 lg:max-w-200 md:w-180 md:max-w-180 xs:w-96 xs:max-w-96 w-82 max-w-82 flex flex-row items-end justify-between;
 }
 
 .navigation {
   @apply flex md:flex-row flex-col md:gap-4 font-arimo xl:text-left text-right;
 }

 .me-ascii {
   @apply whitespace-pre-wrap font-mono xl:text-sm text-xs text-(--color-accent) transition-[color,text-shadow] duration-300 ease-in-out;
 }

 :global(html.dark) .me-ascii {
   text-shadow: 0 0 8px color-mix(in srgb, var(--color-accent) 55%, transparent);
 }
</style>
