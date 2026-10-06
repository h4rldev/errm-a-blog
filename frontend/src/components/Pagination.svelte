<script lang="ts" generics="T">
 import type { Snippet } from "svelte";

 let {
   items,
   per_page = $bindable(20),
   order = $bindable<"newest" | "oldest">("newest"),
   page = $bindable(1),
   search = $bindable(""),
   filter,
   children,
 }: {
   items: T[];
   per_page?: number;
   order?: "newest" | "oldest";
   page?: number;
   search?: string;
   filter?: (item: T, query: string) => boolean;
   children: Snippet<[T[]]>;
 } = $props();

 const sizes = [20, 40, 80, 0];

 const filtered = $derived(
   search.trim() === ""
   ? items
   : items.filter((x) =>
     filter
     ? filter(x, search.trim().toLowerCase())
     : [(x as any).username, (x as any).content_markdown].some(
       (v) =>
         typeof v === "string" && v.toLowerCase().includes(search.trim().toLowerCase()),
     ),
   ),
 );

 const sorted = $derived(
   order === "newest"
   ? [...filtered].sort((a, b) => (b as any).posted_at - (a as any).posted_at)
   : [...filtered].sort((a, b) => (a as any).posted_at - (b as any).posted_at),
 );

 const page_count = $derived(per_page === 0 ? 1 : Math.max(1, Math.ceil(sorted.length / per_page)));

 $effect(() => {
   if (page > page_count) page = page_count;
   if (page < 1) page = 1;
 });

 const visible = $derived(
   per_page === 0 ? sorted : sorted.slice((page - 1) * per_page, page * per_page),
 );

 const pages = $derived(Array.from({ length: page_count }, (_, i) => i + 1));

 export function page_of(id: number): number {
   const idx = sorted.findIndex((x) => Number((x as any).id) === id);
   if (idx === -1) return -1;
   return per_page === 0 ? 1 : Math.floor(idx / per_page) + 1;
 }
</script>

<div class="pagination">
  <input
    type="search"
    class="pagination-search"
    placeholder="Search..."
    bind:value={search}
  />
  <label>
    SHOW
    <select bind:value={per_page}>
      {#each sizes as s}
        <option value={s}>{s === 0 ? "All" : s}</option>
      {/each}
    </select>
  </label>
  <label>
    ORDER
    <select bind:value={order}>
      <option value="newest">Newest first</option>
      <option value="oldest">Oldest first</option>
    </select>
  </label>
</div>

{@render children(visible)}

{#if page_count > 1}
  <div class="pagination-controls">
    <button type="button" disabled={page === 1} onclick={() => page--}>Prev</button>
    {#each pages as p}
      <button type="button" class:active={p === page} onclick={() => page = p}>{p}</button>
    {/each}
    <button type="button" disabled={page === page_count} onclick={() => page++}>Next</button>
  </div>
{/if}

<style>
 @reference "$tailcss";

 .pagination {
   @apply flex flex-row flex-wrap gap-4 items-center my-4;
 }

 .pagination-search {
   @apply grow basis-full sm:basis-0 bg-(--color-bg) text-(--color-text) text-sm border border-(--color-overlay) py-1 px-2 focus:border-(--color-accent) focus:outline-none;
 }

 .pagination label {
   @apply flex flex-row items-center gap-2 text-sm text-(--color-accent);
 }

 .pagination select {
   @apply appearance-none bg-(--color-bg) text-(--color-text) text-sm border border-(--color-overlay) py-1 pl-2 pr-8 focus:border-(--color-accent) focus:outline-none;
 }

 .pagination-controls {
   @apply flex flex-row gap-1 mt-4 flex-wrap;
 }

 .pagination-controls button {
   @apply px-2 py-1 border border-(--color-overlay) text-(--color-text) text-xs;
 }

 .pagination-controls button.active {
   @apply bg-(--color-accent) text-(--color-bg);
 }

 .pagination-controls button:disabled {
   @apply opacity-40;
 }

 .pagination-search:focus,
 .pagination-search:focus-visible {
   outline: none;
   box-shadow: none;
 }
</style>
