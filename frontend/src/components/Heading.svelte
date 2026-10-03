<script>
 import Link from "$components/Link.svelte";

 const { children, level = "1", id = null } = $props();

 const size_map = [
   "text-2xl",
   "text-xl",
   "text-lg",
   "text-base",
   "text-sm",
   "text-xs",
 ];
 const size_class = $derived(size_map[+level - 1] || "text-base");
</script>

<svelte:element
  this={`h${level}`}
  {id}
  class="heading {size_class}"
>
  {#if id}
    <Link href={`#${id}`} aria_label="Link to this section">></Link>
  {/if}
  {@render children?.()}
</svelte:element>

<style>
 @reference '$tailcss';

 .heading {
   @apply font-bold font-arimo my-4;
 }

 .heading :global(a) {
   @apply no-underline;
   margin-right: 0.25rem;
 }
</style>
