<script lang="ts">
 import { onDestroy, onMount, tick } from "svelte";
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
 import Pagination from "$components/Pagination.svelte";

 let per_page = $state(5);
 let order = $state<"newest" | "oldest">("newest");
 let page = $state(1);
 let pagination: Pagination<GuestbookEntry> | undefined = $state(undefined);
 
 let entries = $state<GuestbookEntry[]>([]);
 let ws = $state<WebSocket | null>(null);
 let username = $state<string | null>(null);
 let content = $state<string | null>(null);
 let loading = $state<boolean>(false);
 let error = $state<string | null>(null);
 let ws_open = $state<boolean>(false);
 let subscribed = false;
 let reconnect_timer: ReturnType<typeof setTimeout> | undefined;
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

 const vote_entry = async (entry: GuestbookEntry) => {
   try {
     const res = await blog_api.vote_guestbook_entry(entry.id);
     entries = entries.map((e) => (e.id === entry.id ? { ...e, votes: res.votes } : e));
   } catch {}
 };

 const connect = () => {
   const socket = new WebSocket(ws_url);
   ws = socket;
   socket.onopen = () => {
     ws_open = true;
     subscribed = false;
   };
   socket.onclose = () => {
     ws_open = false;
     subscribed = false;
     reconnect_timer = setTimeout(connect, 1000);
   };

   socket.onmessage = (e) => {
     const msg = JSON.parse(e.data);
     switch (msg.event) {
       case "guestbook:initial":
         entries = msg.entries.map(normalize_entry);
         break;
       case "guestbook:new":
         {
           const entry = normalize_entry(msg);
           if (!entries.some((e) => e.id === entry.id)) {
             entries = [...entries, entry];
           }
         }
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
       case "guestbook:voted":
         entries = entries.map((e) => (e.id === Number(msg.id) ? { ...e, votes: Number(msg.votes) } : e));
         break;
       default:
         break;
     }
   };
 };

 onMount(() => {
   blog.check();
   connect();
 });

 $effect(() => {
   if (!ws_open || !ws || subscribed) return;
   subscribed = true;
   ws.send(JSON.stringify({ event: "subscribe", channel: "guestbook" }));
   ws.send(JSON.stringify({ event: "fetch_guestbook" }));
 });

 onDestroy(() => {
   clearTimeout(reconnect_timer);
   ws?.close();
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
     await blog_api.create_guestbook_entry(payload);
     username = "";
     content = "";
   } catch (err: any) {
     error = err.message || "Failed to create guestbook entry";
   } finally {
     loading = false;
   }
 };

 $effect(() => {
   if (!entries.length || !location.hash.startsWith("#entry-")) return;
   const id = Number(location.hash.slice("#entry-".length));
   const p = pagination?.page_of(id);
   if (p !== undefined && p > 0) page = p;
   tick().then(() => document.querySelector(location.hash)?.scrollIntoView());
 });
</script>

<Meta title="Guestbook!" path="/guestbook/" />
<main>
  <Cell title="guestbook">
    <Heading level="4">
      Guestbook!
    </Heading>
    <p class="mb-2">
      Public wall where you can say hi, your thoughts about the website, or self advertise!
    </p>
    <p> A couple rules are as follows: </p>
    <ul class="rules">
      <li>No extreme profanity</li>
      <li>No malicious links</li>
      <li>Keep links and content SFW</li>
      <li>Keep it civil</li>
    </ul>
  </Cell>

  <Cell title="Add a new entry">
    <div class="form-container">
      <Heading level="2">Add a new entry!</Heading>
      {#if content}
        <Cell title="Preview">
          <RichMarkdown md={content ?? ""} />
        </Cell>
      {/if}
      <form onsubmit={handle_submit} class="guestbook-form">
        <label class="username">
          USERNAME
          <input type="text" name="username" bind:value={username} autocomplete="username" placeholder="Anonymous" maxlength="32" />
        </label>
        <label class="content">
          CONTENT (MARKDOWN)
          <textarea bind:value={content} name="content" placeholder="Write something..." maxlength="800"></textarea>
        </label>
        <button type="submit" class="button-guestbook" disabled={loading}>
          {loading ? 'Loading...' : 'Submit'}
        </button>
      </form>
    </div>
  </Cell>

  <Pagination split bind:this={pagination} items={entries} bind:per_page bind:order bind:page>
    {#snippet children(visible)}
      {#each visible as entry}
        <div id={`entry-${entry.id}`}>
          <Cell title="Entry">
            <div class="title-and-meta">
              <p class="font-bold">{entry.username}</p>
              <p class="text-xs">{blog_api.convert_unix_timestamp_to_date(entry.posted_at)}</p>
              <p class="text-xs">{entry.edited_at ? blog_api.convert_unix_timestamp_to_date(entry.edited_at) : "never"}</p>
            </div>
            {#if editing_entry_id === entry.id}
              <form class="guestbook-form mt-4 max-w-none"
                    onsubmit={(e) => { e.preventDefault(); save_edit(entry); }}>
                {#if edited_content}
                  <RichMarkdown md={edited_content ?? ""} />
                {/if}
                <textarea bind:value={edited_content}></textarea>
                <div class="flex flex-row gap-2">
                  <button type="submit" class="button-edit">Save</button>
                  <button type="button" class="button-delete" onclick={cancel_edit}>Cancel</button>
                </div>
              </form>
            {:else}
              <RichMarkdown md={entry.content_markdown} />
              <div class="mt-4 flex flex-row items-center justify-between gap-2">
                <button class="button-vote" onclick={() => vote_entry(entry)}>▲ {entry.votes ?? 0}</button>
                {#if is_admin}
                  <ul class="post-actions">
                    <li><button class="button-edit" onclick={() => start_edit(entry)}>Edit</button></li>
                    <li><button class="button-delete" onclick={() => delete_entry(entry)}>Delete</button></li>
                  </ul>
                {/if}
              </div>
            {/if}
          </Cell>
        </div>
      {/each}
    {/snippet}
  </Pagination>
</main>

<style>
 @reference "$tailcss";

 input, textarea {
   @apply bg-(--color-bg) text-(--color-text) p-2 w-full active:border-(--color-accent) active:outline-none active:ring-(--color-accent) focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
 }

 label {
   @apply flex flex-col text-xs text-(--color-accent);
 }

 .rules {
   @apply list-disc list-inside ml-2;
 }
</style>
