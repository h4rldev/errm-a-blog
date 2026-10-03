<script lang="ts">
 import { onDestroy, onMount } from "svelte";
 import Cell from "$components/Cell.svelte";
 import Heading from "$components/Heading.svelte";
 import Link from "$components/Link.svelte";
 import Meta from "$components/Meta.svelte";
 import RichMarkdown from "$components/RichMarkdown.svelte";
 import {
   ws_url,
   blog_api,
   normalize_entry,
   type GuestbookEntry,
   type PostGuestbookEntry,
 } from "$lib/blog_api";
 import { blog } from "$lib/blog.svelte";

 let entries = $state<GuestbookEntry[]>([]);
 let ws = $state<WebSocket | null>(null);
 let username = $state<string | null>(null);
 let content = $state<string | null>(null);
 let loading = $state<boolean>(false);
 let error = $state<string | null>(null);
 let timeout_id = $state<ReturnType<typeof setTimeout> | undefined>(undefined);
 let editing_entry_id = $state<number | undefined>(undefined);
 let edited_content = $state<string>("");
 const is_admin = $derived(blog.user?.role.includes("admin") ?? false);
 
 const start_edit = (entry: GuestbookEntry) => {
   editing_entry_id = entry.id;
   edited_content = entry.content_markdown;
 };

 const cancel_edit = () => {
   editing_entry_id = undefined;
   edited_content = "";
 };

 const save_edit = async (entry: GuestbookEntry) => {
   await blog_api.edit_guestbook_entry(entry.id, {
     username: entry.username,
     content_markdown: edited_content,
   });
   cancel_edit();
 };

 const delete_entry = async (entry: GuestbookEntry) => {
   if (!confirm(`Delete entry by ${entry.username}?`)) return;
   await blog_api.delete_guestbook_entry(entry.id, {
     username: entry.username,
     content_markdown: entry.content_markdown,
   });
 };
 

 onMount(() => {
   blog.check();
   ws = new WebSocket(ws_url);
   ws!.onopen = () => {
     ws!.send(JSON.stringify({ event: "subscribe", channel: "guestbook" }));
     ws!.send(JSON.stringify({ event: "fetch_guestbook" }));
   };

   ws!.onmessage = (e) => {
     const msg = JSON.parse(e.data);
     switch (msg.event) {
       case "guestbook:initial":
	 entries = msg.entries.map(normalize_entry);
	 entries = entries.sort((a, b) => b.posted_at - a.posted_at);
	 break;
       case "guestbook:new":
	 entries = [...entries, normalize_entry(msg)];
	 entries = entries.sort((a, b) => b.posted_at - a.posted_at);
	 break;
       case "guestbook:edited":
	 entries = entries.map((e) =>
	   e.id === Number(msg.id)
	   ? { ...e, content_markdown: msg.content_markdown, edited_at: Number(msg.edited_at) }
	   : e,
	 );
	 break;
       case "guestbook:deleted":
	 entries = entries.filter((e) => e.id !== Number(msg.id));
	 break;
       default:
         break;
     }
   };

   timeout_id = setTimeout(() => {
     ws?.send(JSON.stringify({ event: "subscribe", channel: "guestbook" }));
     ws?.send(JSON.stringify({ event: "fetch_guestbook" }));
   }, 30000);
 });

 onDestroy(() => {
   clearTimeout(timeout_id);
 });

 const handle_submit = async (e: Event) => {
   e.preventDefault();

   if (!username || !content) {
     error = "Username, and content are required";
     return;
   }

   const payload: PostGuestbookEntry = {
     username: username.trim(),
     content_markdown: content.trim(),
   };

   loading = true;
   error = "";
   try {
     const data = await blog_api.create_guestbook_entry(payload);
   } catch (err: any) {
     error = err.message || "Failed to create guestbook entry";
   } finally {
     loading = false;
   }
 };

 $effect(() => {
   if (entries.length && location.hash.startsWith("#entry-"))
     document.querySelector(location.hash)?.scrollIntoView();
 });
</script>

<Meta title="Guestbook!" path="/guestbook/" />
<main>
  <Cell title="guestbook">
    <Cell title="Add a new entry">
      <div class="form-container">
        <Heading level="2">Add a new entry!</Heading>
        <form onsubmit={handle_submit} class="guestbook-form">
          <label class="username">
            USERNAME
            <input type="text" name="username" bind:value={username} autocomplete="username" placeholder="Anonymous" />
          </label>
          <label class="content">
            CONTENT (MARKDOWN)
            <textarea bind:value={content} name="content" placeholder="Write something..."></textarea>
          </label>
          <button type="submit" class="button-guestbook" disabled={loading}>
            {loading ? 'Loading...' : 'Submit'}
          </button>
        </form>
      </div>
    </Cell>

    <Cell title="Entries">
      {#each entries as entry}
        <div id={`entry-${entry.id}`}>
          <Cell title="Entry">
            <div class="title-and-meta">
              <p class="font-bold">{entry.username}</p>
              <p class="text-xs">{blog_api.convert_unix_timestamp_to_date(entry.posted_at)}</p>
              <p class="text-xs">{entry.edited_at ? blog_api.convert_unix_timestamp_to_date(entry.edited_at) : "never"}</p>
            </div>
            <RichMarkdown md={entry.content_markdown} />
            {#if is_admin}
              <div class="mt-4">
                <ul class="post-actions">
                  <li><button class="button-edit" onclick={() => start_edit(entry)}>Edit</button></li>
                  <li><button class="button-delete" onclick={() => delete_entry(entry)}>Delete</button></li>
                </ul>
              </div>
            {/if}
            {#if editing_entry_id === entry.id}
              <form class="guestbook-form mt-4"
                    onsubmit={(e) => { e.preventDefault(); save_edit(entry); }}>
                <textarea bind:value={edited_content}></textarea>
                <div class="flex flex-row gap-2">
                  <button type="submit" class="button-edit">Save</button>
                  <button type="button" class="button-delete" onclick={cancel_edit}>Cancel</button>
                </div>
              </form>
            {/if}
          </Cell>
        </div>
      {/each}
    </Cell>
  </Cell>
</main>

<style>
 @reference "$tailcss";

 input, textarea {
   @apply bg-(--color-bg) text-(--color-text) p-2 w-full active:border-(--color-accent) active:outline-none active:ring-(--color-accent) focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
 }

 label {
   @apply flex flex-col text-xs text-(--color-accent);
 }
</style>
