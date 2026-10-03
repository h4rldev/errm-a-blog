<script lang="ts">
 import { onMount } from "svelte";
 import { tags_store } from "$lib/stores/tags.svelte";

 onMount(() => {
   tags_store.fetch_tags();
 });

 let { tags = $bindable([]), placeholder = "Add tags...", id } = $props();

 let selected = $derived<string[]>(tags);
 let input_value = $state<string>("");
 let suggestions = $state<string[]>([]);
 let open = $state<boolean>(false);
 let highlight_index = $state<number>(-1);

 $effect(() => {
   const query = input_value.trim().toLowerCase();
   if (query === "") {
     suggestions = [];
     open = false;
     highlight_index = -1;
   } else {
     const matched = tags_store.tags.filter(
       (t) => t.toLowerCase().includes(query) && !selected.includes(t),
     );
     suggestions = matched;
     open = matched.length > 0;
     highlight_index = -1;
   }
 });

 const add_tag = (tag: string) => {
   const trimmed = tag.trim();
   if (trimmed === "") return;
   if (!selected.some((t) => t.toLowerCase() === trimmed.toLowerCase())) {
     selected = [...selected, trimmed];
   }

   input_value = "";
   open = false;
   highlight_index = -1;

   tags = selected;
 };

 const remove_tag = (index: number) => {
   selected = selected.filter((_, i) => i !== index);
   tags = selected;
 };

 const handle_keydown = (e: KeyboardEvent) => {
   if (e.key === "Enter") {
     e.preventDefault();
     if (highlight_index >= 0 && highlight_index < suggestions.length) {
       add_tag(suggestions[highlight_index]);
     } else if (input_value.trim() !== "") {
       add_tag(input_value);
     }
   } else if (e.key === "ArrowDown") {
     e.preventDefault();
     if (suggestions.length > 0)
       highlight_index = (highlight_index + 1) % suggestions.length;
   } else if (e.key === "ArrowUp") {
     e.preventDefault();
     if (suggestions.length > 0)
       highlight_index =
	 (highlight_index - 1 + suggestions.length) % suggestions.length;
   } else if (e.key === "Escape") {
     open = false;
     highlight_index = -1;
   } else if (
     e.key === "Backspace" &&
     input_value === "" &&
     selected.length > 0
   ) {
     remove_tag(selected.length - 1);
   }
 };

 const handle_blur = () => {
   setTimeout(() => {
     open = false;
     highlight_index = -1;
   }, 100);
 };
</script>

<div class="tag-input" onfocusin={() => { if (input_value.trim() !== '') open = true; }}>
  <div class="tags-container">
    <ul class="tag-chips" id="tags-chips">
      {#if selected.length === 0}
        <p class="text-xs text-(--color-subtext)">No tags</p>
      {/if}
      {#each selected as tag, index}
        <li class="tag-chip-item">
          {tag}
          <button type="button" onclick={() => remove_tag(index)} class="remove-tag-button" aria-label="Remove tag">×</button>
        </li>
      {/each}
    </ul>
    <input
      type="text"
      id={id}
      name={id}
      bind:value={input_value}
      onkeydown={handle_keydown}
      onblur={handle_blur}
      onfocus={() => { if (input_value.trim() !== '') open = true; }}
      placeholder={selected.length === 0 ? placeholder : ""}
      class="tag-input-field"
    />
  </div>
  {#if open && suggestions.length > 0}
    <p> Suggestions: </p>
    <ul class="suggestions-dropdown" role="listbox">
      {#each suggestions as suggestion, index}
        <li role="option" aria-selected={index === highlight_index} class:highlighted={index === highlight_index} onpointerdown={(e) => {
                                                                                                                                e.preventDefault();
                                                                                                                                add_tag(suggestion);
                                                                                                                                }}>
          {suggestion}
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
 @reference '$tailcss';

 .tag-chips {
   @apply flex-row flex-wrap gap-2 my-1 inline-flex text-sm text-(--color-accent);
 }

 .tag-chip-item {
   @apply bg-(--color-secondary);
 }

 .remove-tag-button {
   @apply hover:cursor-pointer hover:text-(--color-error) inline-flex items-center justify-center text-xs border-0 p-0;
 }

 input {
   @apply bg-(--color-bg) text-(--color-text) p-2 w-full focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
 }


</style>
