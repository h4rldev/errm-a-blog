<script lang="ts">
import { onMount } from "svelte";
import Markdown from "svelte-exmarkdown";
import Cell from "$components/Cell.svelte";
import Heading from "$components/Heading.svelte";
import Link from "$components/Link.svelte";
import { blog_api } from "$lib/blog_api";

interface Entry {
	id: number;
	username: string | "anonymous";
	content_markdown: string;
	posted_at: number;
	edited_at: number | null;
}

let entries = $state<Entry[]>([]);
let ws = $state<WebSocket | null>(null);
let username = $state<string | null>(null);
let content = $state<string | null>(null);
let loading = $state<boolean>(false);

onMount(() => {
	ws = new WebSocket("http://localhost:8080/ws");
	ws.onopen = () => {
		ws.send(JSON.stringify({ event: "subscribe", channel: "guestbook" }));
		ws.send(JSON.stringify({ event: "fetch_guestbook" }));
	};
	ws.onmessage = (e) => {
		const msg = JSON.parse(e.data);
		if (msg.event === "guestbook:initial") entries = msg.entries;
		else if (msg.event === "guestbook:new") entries = [...entries, msg];
		else if (msg.event === "guestbook:edit")
			entries = entries.map((entry) => (entry.id === msg.id ? msg : entry));
		else if (msg.event === "guestbook:delete")
			entries = entries.filter((entry) => entry.id !== msg.id);
		else console.log("unknown event", msg);
	};
});
</script>

<main>
  <Cell title="guestbook">
    <Cell title="Add a new entry">
      <Heading level="2">Add a new entry!</Heading>
      <form onsubmit={handle_submit} class="guestbook-form">
        <label class="username">
          USERNAME
          <input type="text" bind:value={username} autocomplete="username" placeholder="Anonymous" />
        </label>
        <label class="content">
          CONTENT (MARKDOWN)
          <textarea bind:value={content} placeholder="Write something..."></textarea>
        </label>
        <button type="submit" class="button-guestbook" disabled={loading}>
          {loading ? 'Loading...' : 'Submit'}
        </button>
      </form>
    </Cell>
    
    <Cell title="Entries">
      {#each entries as entry}
        <Cell title={ "from " + entry.username }>
          <p class="text-xs">{blog_api.convert_unix_timestamp_to_date(entry.posted_at)}</p>
          <p class="text-xs">{entry.edited_at ? blog_api.convert_unix_timestamp_to_date(entry.last_edited_at) : "never"}</p>
          <Markdown md={entry.content_markdown} />
        </Cell>
      {/each}
    </Cell>
  </Cell>
</main>
