<script lang="ts">
import { onMount, onDestroy } from "svelte";
import { blog_api, type GuestbookEntry } from "$lib/blog_api";

import RichMarkdown from "$components/RichMarkdown.svelte";
import Cell from "$components/Cell.svelte";
import Heading from "$components/Heading.svelte";
import Link from "$components/Link.svelte";

let entries = $state<GuestbookEntry[]>([]);
let ws = $state<WebSocket | null>(null);
let username = $state<string | null>(null);
let content = $state<string | null>(null);
let loading = $state<boolean>(false);
let error = $state<string | null>(null);
let timeout_id = $state<number | null>(null);

const is_dev = import.meta.env.DEV;
const is_prod = import.meta.env.PROD;
const url = is_dev ? "http://localhost:8080" : is_prod ? "" : "http://localhost:8080";
const full_url = url + "/ws";

onMount(() => {
	ws = new WebSocket(full_url);
	ws.onopen = () => {
		ws.send(JSON.stringify({ event: "subscribe", channel: "guestbook" }));
		ws.send(JSON.stringify({ event: "fetch_guestbook" }));
	};

	ws.onmessage = (e) => {
		const msg = JSON.parse(e.data);
		switch (msg.event) {
		  case "guestbook:initial":
		    entries = msg.entries;
        entries = entries.sort((a, b) => b.posted_at - a.posted_at);
		    break;
      case "guestbook:new":
        entries = [...entries, msg];
        entries = entries.sort((a, b) => b.posted_at - a.posted_at);
        break;
      case "guestbook:edit":
        entries = entries.map((entry) => (entry.id === msg.id ? msg : entry));
        entries = entries.sort((a, b) => b.posted_at - a.posted_at);
        break;
      case "guestbook:delete":
        entries = entries.filter((entry) => entry.id !== msg.id);
        entries = entries.sort((a, b) => b.posted_at - a.posted_at);
        break;
		  default:
		    console.log("Unknown event:", msg);
        entries = entries.sort((a, b) => b.posted_at - a.posted_at);
        break;
		}
	};

  timeout_id = setTimeout(() => {
    ws.send(JSON.stringify({ event: "subscribe", channel: "guestbook" }));
    ws.send(JSON.stringify({ event: "fetch_guestbook" }));
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
  
  const payload = {
    username: username.trim(),
    content_markdown: content.trim(),
  };

  loading = true;
  error = "";
  try {
    const data = await blog_api.create_guestbook_entry(payload);
    console.log("data", data);
  } catch (err: any) {
    error = err.message || "Failed to create guestbook entry";
  } finally {
    loading = false;
  }
};
</script>

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
        <Cell title="Entry">
          <div class="title-and-meta">
            <p class="font-bold">{entry.username}</p>
            <p class="text-xs">{blog_api.convert_unix_timestamp_to_date(entry.posted_at)}</p>
            <p class="text-xs">{entry.edited_at ? blog_api.convert_unix_timestamp_to_date(entry.last_edited_at) : "never"}</p>
          </div>
          <RichMarkdown md={entry.content_markdown} />
        </Cell>
      {/each}
    </Cell>
  </Cell>
</main>

<style>
  @reference "$tailcss";

  .title-and-meta {
    @apply flex flex-row justify-between;
  }

  .form-container {
    @apply flex flex-col justify-center items-center font-arimo mb-4;
  }

  .guestbook-form {
    @apply flex flex-col gap-4 max-w-2xl w-xl;
  }

  input, textarea {
    @apply bg-(--color-bg) text-(--color-text) p-2 w-full active:border-(--color-accent) active:outline-none active:ring-(--color-accent) focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
  }

  label {
    @apply flex flex-col text-xs text-(--color-accent);
  }
</style>
