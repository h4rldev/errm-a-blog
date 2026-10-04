<script lang="ts">
 import { onDestroy, onMount } from "svelte";
 import Cell from "$components/Cell.svelte";
 import Meta from "$components/Meta.svelte";
 import { blog } from "$lib/blog.svelte";
 import {
   blog_api,
   ws_url,
   type RotateRegisterToken,
   type Stats,
   type User,
   type BlockedWords,
   type AdminNotification,
 } from "$lib/blog_api";


 type NotifPerm = "unsupported" | NotificationPermission;

 let notif_perm = $state<NotifPerm>("default");
 let notifications = $state<AdminNotification[]>([]);
 let browser_notifications = $state(false);
 let ws: WebSocket | null = null;
 
 let token = $state<string | undefined>(undefined);
 let token_length = $state<number>(0);

 let show_token = $state<boolean>(false);
 let token_interval = $state<ReturnType<typeof setInterval> | undefined>(
   undefined,
 );

 let stats = $state<Stats | undefined>(undefined);

 let copied = $state<boolean>(false);
 let copy_timer = $state<ReturnType<typeof setTimeout> | undefined>(undefined);

 let rotated = $state<boolean>(false);
 let rotate_timer = $state<ReturnType<typeof setTimeout> | undefined>(undefined);

 let users = $state<User[] | undefined>(undefined);
 let selected_user_id = $state<string | undefined>(undefined);
 let selected_user = $derived(
   selected_user_id ? users?.find((u) => u.uuid === selected_user_id) : null,
 );

 let selected_user_password = $state<string | undefined>(undefined);
 let user_interval = $state<ReturnType<typeof setInterval> | undefined>(
   undefined,
 );
 
 let user_selected = $derived(selected_user ? true : false);
 let blocked_scope = $state<"global" | "comments" | "guestbook">("global");
 let blocked_keywords = $state<string>("");
 let blocked_patterns = $state<string>("");
 let blocked_saved = $state<boolean>(false);
 const roles = ["super-administrator", "administrator", "poster"];
 const role_rank: Record<string, number> = {
   "super-administrator": 3,
   administrator: 2,
   poster: 1,
 };

 const comment_target = (post_id: string | number, comment_id: string | number) =>
   `/blog/post/${post_id}#comment-${comment_id}`;
 const guestbook_target = (entry_id: string | number) => `/guestbook#entry-${entry_id}`;

 const action_of = (event: string) => {
   const a = event.split(":")[1];
   return a === "new" ? "created" : a ?? "created";
 };
 
 const to_notification = (msg: any): AdminNotification | null => {
   const created = Number(msg.posted_at ?? msg.edited_at) || Math.floor(Date.now() / 1000);
   const base = { id: -Date.now(), username: msg.username ?? null, content: msg.content_markdown ?? null, created_at: created, target: null };
   switch (msg.event) {
     case "post_comments:new":
     case "post_comments:edited":
     case "post_comments:deleted":
       return { ...base, kind: "comment", action: action_of(msg.event),
	  ref_id: msg.post_id ?? null,
	  target: msg.id != null && msg.post_id != null ? comment_target(msg.post_id, msg.id) : null };
     case "guestbook:new":
     case "guestbook:edited":
     case "guestbook:deleted":
       return { ...base, kind: "guestbook", action: action_of(msg.event),
	  ref_id: msg.id ?? null,
	  target: msg.id != null ? guestbook_target(msg.id) : null };
     default: return null;
   }
 };

 const notif_subject = (n: AdminNotification) =>
   n.kind === "guestbook"
   ? (n.ref_id ? `guestbook entry #${n.ref_id}` : "guestbook")
   : (n.ref_id ? `comment on post #${n.ref_id}` : "comment");

 const notif_href = (n: AdminNotification) =>
   n.target ?? (n.kind === "guestbook" ? "/guestbook/" : "/blog/");
 
 const refresh_notif_perm = () => {
   notif_perm = typeof Notification === "undefined" ? "unsupported" : Notification.permission;
   browser_notifications = notif_perm === "granted";
 };
 
 const enable_browser_notifications = async () => {
   if (typeof Notification === "undefined") { notif_perm = "unsupported"; return; }
   notif_perm = await Notification.requestPermission();
   browser_notifications = notif_perm === "granted";
 };
 
 const split_list = (s: string): string[] =>
   s.split("\n").map((x) => x.trim()).filter(Boolean);

 const load_blocked = async () => {
   const data = await blog_api.admin_get_blocked_words(blocked_scope);
   const row = data.blocked_words?.[0];
   blocked_keywords = (row?.keywords ?? []).join("\n");
   blocked_patterns = (row?.patterns ?? []).join("\n");
 };

 const save_blocked = async () => {
   await blog_api.admin_save_blocked_words(blocked_scope, {
     keywords: split_list(blocked_keywords),
     patterns: split_list(blocked_patterns),
     enforced_by: blog.user?.username ?? "unknown",
   });
   blocked_saved = true;
   setTimeout(() => (blocked_saved = false), 1500);
 };

 const available_roles = $derived(
   selected_user
   ? roles.filter(
     (r) =>
       r !== selected_user.role &&
          (role_rank[r] ?? 0) < (role_rank[blog.user?.role ?? "poster"] ?? 0),
   )
   : [],
 );

 const fetch_token = async () => {
   const data = await blog_api.admin_get_register_token();
   token = data.token;
   token_length = data.token.length;
 };

 const fetch_users = async () => {
   const data = await blog_api.admin_get_users();
   users = data.users;
 };

 const copy_token = async () => {
   if (!token) return;
   await navigator.clipboard.writeText(token);

   copied = true;
   clearTimeout(copy_timer);
   copy_timer = setTimeout(() => (copied = false), 1500);
 };

 const edit_user = async (e: Event) => {
   e.preventDefault();

   if (!selected_user) return;
   await blog_api.admin_edit_user({
     uuid: selected_user.uuid,
     username: selected_user.username,
     role: selected_user.role,
     password: selected_user_password,
   });

   await fetch_users();
   selected_user_password = undefined;
 };

 const rotate = async (secret: string) => {
   switch (secret) {
     case "register": {
       const resp: RotateRegisterToken =
         await blog_api.admin_secret_rotate("register_token");
       token = resp.token;

       rotated = true;
       clearTimeout(rotate_timer);
       rotate_timer = setTimeout(() => (rotated = false), 500);
       break;
     }

     case "jwt":
       if (!confirm("Are you sure you want to rotate the JWT secret? Every user will be logged out"))
         return;
       await blog_api.admin_secret_rotate("jwt_secret");
       blog.logout();
       break;

     case "cookie":
       if (!confirm("Are you sure you want to rotate the cookie key? Every user will be logged out"))
         return;
       await blog_api.admin_secret_rotate("cookie_key");
       blog.logout();
       break;

     default:
       return;
   }
 };

 const role = $derived(
   blog.user?.role
   ? blog.user.role
         .split("-")
         .map((w) => w[0].toUpperCase() + w.slice(1))
         .join(" ")
   : "",
 );

 onMount(() => {
   blog_api.admin_get_notifications().then((d) => (notifications = d.notifications));
   blog.check();
   blog_api.admin_get_stats().then((s) => (stats = s));

   fetch_token();
   fetch_users();
   token_interval = setInterval(fetch_token, 30000);
   user_interval = setInterval(fetch_users, 30000);

   refresh_notif_perm();

   ws = new WebSocket(ws_url);
   ws.onopen = () => {
     ws!.send(JSON.stringify({ event: "subscribe", channel: "guestbook" }));
     ws!.send(JSON.stringify({ event: "subscribe", channel: "all_posts" }));
   };

   ws.onmessage = (e: MessageEvent) => {
     const n = to_notification(JSON.parse(e.data));
     if (!n) return;
     notifications = [n, ...notifications];
     if (browser_notifications) new Notification(`New ${n.kind} from ${n.username}`, { body: n.content ?? undefined });
   };
 });

 onDestroy(() => {
   clearInterval(token_interval);
   clearInterval(user_interval);
   clearTimeout(rotate_timer);
   clearTimeout(copy_timer);
   ws?.close();
 });

 $effect(() => {
   blocked_scope;
   load_blocked();
 });
</script>
<Meta title="Admin Dashboard" path="/admin/" />
<main>
  <Cell title="Overview">
    <p class="text-center mb-2">Welcome, <span class="text-(--color-accent)">{blog.user?.username}</span>! (<span class="font-bold">{role}</span>)</p>
    {#if stats}
      <ul class="stats">
        <li>Total posts: {stats.total_posts}</li>
        <li>Total comments: {stats.total_comments}</li>
        <li>Total guestbook entries: {stats.total_guestbook_entries}</li>
      </ul>
    {/if}
  </Cell>
  <Cell title="Notifications">
    <div class="admin-form mt-2">
      <div class="flex flex-row flex-wrap items-center justify-between gap-2">
        <p class="text-(--color-subtext)">{notifications.length} new</p>
        <div class="flex flex-row gap-2">
          <button class="notif" onclick={enable_browser_notifications}
                  disabled={notif_perm === "granted" || notif_perm === "unsupported"}>
            {#if notif_perm === "granted"}Notifications on
            {:else if notif_perm === "denied"}Notifications blocked
            {:else if notif_perm === "unsupported"}Not supported
            {:else}Enable notifications{/if}
          </button>
          <button class="notif" onclick={async () => { await blog_api.admin_clear_notifications(); notifications = []; }} disabled={notifications.length === 0}>
            Clear
          </button>
        </div>
      </div>
      <ul class="notifications">
        {#each notifications as n}
          <li>
            <a class="notif-body" href={notif_href(n)}>
              <div class="notif-head">
                <span>
                  <span class="text-(--color-accent)">{n.username ?? "unknown"}</span>
                  <span class="text-(--color-subtext)"> · {notif_subject(n)} · {n.action}{#if n.content}:{/if}</span>
                </span>
                <time class="notif-time">{new Date(n.created_at * 1000).toLocaleTimeString()}</time>
              </div>
              {#if n.content}<p class="notif-content" title={n.content}>{n.content}</p>{/if}
            </a>
          </li>
        {/each}
      </ul>
      {#if notifications.length === 0}
        <p class="text-(--color-subtext) text-sm">Nothing yet.</p>
      {/if}
    </div>
  </Cell>
  <Cell title="Secrets">
    <div class="register-token">
      <div>
        <p>Register token:</p>
        <p class="text-(--color-subtext) min-w-80">
          {#if show_token}
            <code>{token}</code>
          {:else}
            <code>{"*".repeat(token_length ?? 16)}</code>
          {/if}
        </p>
      </div>
      <div class="flex flex-row gap-2 justify-center items-center">
        <button class="show" onclick={() => (show_token = !show_token)}>
          {show_token ? "Hide" : "Show"}
        </button>
        <button class="copy" onclick={copy_token}>
          {copied ? "Copied!" : "Copy"}
        </button>
        <button class="rotate" onclick={() => {rotate("register")}}>
          {rotated ? "Rotated!" : "Rotate"}
        </button>
      </div>
    </div>
    <div class="secrets">
      <button class="secret-rotate" onclick={() => {rotate("jwt");}}>Rotate JWT Secret?</button>
      <button class="secret-rotate" onclick={() => {rotate("cookie");}}>Rotate Cookie Key?</button>
    </div>
  </Cell>
  <Cell title="Blocked words">
    <div class="admin-form mt-2">
      <select bind:value={blocked_scope}>
        <option value="global">global</option>
        <option value="comments">comments</option>
        <option value="guestbook">guestbook</option>
      </select>
      <label for="blocked_keywords">Keywords (literal, one per line)</label>
      <textarea id="blocked_keywords" rows="4" bind:value={blocked_keywords}></textarea>
      <label for="blocked_patterns">Patterns (regex, one per line)</label>
      <textarea id="blocked_patterns" rows="4" bind:value={blocked_patterns}></textarea>
      <button type="button" class="save" onclick={save_blocked}>{blocked_saved ? "Saved!" : "Save"}</button>
    </div>
  </Cell>
  <Cell title={user_selected ? "Manage " + selected_user?.username : "Manage Users"}>
    <div class="admin-form mt-2">
      <select bind:value={selected_user_id}>
        <option value={undefined}>Select a user....</option>
        {#each users as user}
          <option value={user.uuid}>{user.username} ({user.role})</option>
        {/each}
      </select>

      {#if user_selected}
        {@const current = selected_user!}
        <form onsubmit={edit_user} class="admin-form">
          <label for="username">
            Username
          </label>
          <input type="text" id="username" bind:value={current.username} />
          <select bind:value={current.role}>
            <option value={current.role}>{current.role}</option>
            {#each available_roles as role}
              <option value={role}>{role}</option>
            {/each}
          </select>
          <label for="password">
            Change password (only change this if you know the user has forgotten their password)
          </label>
          <input type="password" id="password" bind:value={selected_user_password} />
          <button type="submit" class="save">Save</button>
        </form>
      {/if}
    </div>
  </Cell>
</main>

<style>
 @reference "$tailcss";

 select,
 textarea,
 input {
   @apply bg-(--color-bg) text-(--color-text) p-2 w-full focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
 }

 select {
   @apply bg-(--color-bg) text-(--color-text) p-2 w-full focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
 }

 select option {
   @apply bg-(--color-bg) text-(--color-text);
 }

 label {
   @apply flex flex-col text-xs text-(--color-accent);
 }

 .admin-form {
   @apply flex flex-col gap-3 w-full;
 }

 .notifications { @apply flex flex-col max-h-64 overflow-y-auto text-sm; }
 .notifications li { @apply px-2 py-1.5 border-b border-(--color-overlay); }
 .notifications li:last-child { @apply border-b-0; }
 .notif-body { @apply block min-w-0 no-underline text-(--color-text) hover:opacity-80; }
 .notif-head { @apply flex flex-row items-baseline justify-between gap-3; }
 .notif-content { @apply text-(--color-text) text-sm break-words line-clamp-2; }
 .notif-time { @apply text-(--color-subtext) text-xs shrink-0; }

 .notif {
   @apply hover:cursor-pointer bg-(--color-bg) font-bold text-sm px-3 py-1 border-2 border-(--color-text) hover:bg-(--color-secondary) active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out disabled:opacity-40 disabled:cursor-default;
 }
 
 .save {
   @apply hover:cursor-pointer bg-(--color-confirm) text-(--color-bg) font-bold py-2 px-4 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay);
 }

 .stats {
   @apply flex flex-row gap-8 justify-center;
 }

 .show {
   @apply hover:cursor-pointer font-bold px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay) w-20;
 }

 .copy {
   @apply hover:cursor-pointer font-bold px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay) w-20;
 }

 .rotate {
   @apply hover:cursor-pointer font-bold text-(--color-bg) px-2 bg-(--color-error) active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay) w-20;
 }

 .secret-rotate {
   @apply hover:cursor-pointer font-bold text-(--color-bg) px-2 bg-(--color-error) active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay) w-54;
 }

 .secrets {
   @apply flex flex-row gap-8 justify-center w-full mt-6 mb-2;
 }

 .register-token {
   @apply flex flex-row gap-4 justify-center w-full mt-2;
 }

 code {
   @apply font-mono;
 }

</style>
