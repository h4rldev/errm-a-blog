<script lang="ts">
 import { onDestroy, onMount, tick } from "svelte";
 import type { HTMLAnchorAttributes } from "svelte/elements";
 import { goto } from "$app/navigation";
 import { page as route } from "$app/state";
 import Cell from "$components/Cell.svelte";
 import PostModal from "$components/PostModal.svelte";
 import Heading from "$components/Heading.svelte";
 import Link from "$components/Link.svelte";
 import Meta from "$components/Meta.svelte";
 import RichMarkdown from "$components/RichMarkdown.svelte";
 import { blog } from "$lib/blog.svelte";
 import { blog_api, type Comment, type Post, ws_url, normalize_entry as normalize_comment } from "$lib/blog_api";
 import Pagination from "$components/Pagination.svelte";

 let per_page = $state(5);
 let order = $state<"newest" | "oldest">("newest");
 let page = $state(1);
 let pagination: Pagination<Comment> | undefined = $state(undefined);
 
 let post = $state<Post | null>(null);
 let loading = $state<boolean>(true);
 let is_submitting = $state<boolean>(false);
 let error = $state<string | null>(null);
 let show_edit_modal = $state<boolean>(false);
 let ws = $state<WebSocket | null>(null);
 let comments = $state<Comment[]>([]);
 let ws_open = $state<boolean>(false);
 let subscribed_post_id: number | undefined = undefined;

 let username = $state<string | undefined>(undefined);
 let content = $state<string | undefined>(undefined);

 let editing_comment_id = $state<number | undefined>(undefined);
 let edited_content = $state<string>("");
 let replying_to = $state<number | null>(null);
 let reply_username = $state<string>("");
 let reply_content = $state<string>("");

 const children_of = $derived.by(() => {
   const map = new Map<number, Comment[]>();
   for (const c of comments) {
     const key = c.parent_id ?? 0;
     const existing = map.get(key);
     if (existing) existing.push(c);
     else map.set(key, [c]);
   }
   return map;
 });

 const top_level_comments = $derived(children_of.get(0) ?? []);

 const remove_comment_tree = (id: number) => {
   const remove = new Set<number>();
   const walk = (cid: number) => {
     remove.add(cid);
     for (const c of comments) if (c.parent_id === cid) walk(c.id);
   };
   walk(id);
   comments = comments.filter((c) => !remove.has(c.id));
 };

 const vote_comment = async (comment: Comment) => {
   if (post?.id === undefined) return;
   try {
     const res = await blog_api.vote_comment(post.id, comment.id);
     comments = comments.map((c) => (c.id === comment.id ? { ...c, votes: res.votes } : c));
   } catch {}
 };

 const start_reply = (comment: Comment) => {
   replying_to = comment.id;
   reply_username = "";
   reply_content = "";
 };

 const cancel_reply = () => {
   replying_to = null;
   reply_username = "";
   reply_content = "";
 };

 const submit_reply = async (e: Event, parent: Comment) => {
   e.preventDefault();
   if (post?.id === undefined || !reply_content.trim()) return;
   is_submitting = true;
   error = "";
   try {
     await blog_api.create_comment(
       { username: (reply_username || "anonymous").trim(), content_markdown: reply_content.trim(), parent_id: parent.id },
       post.id,
     );
     cancel_reply();
   } catch (err: any) {
     error = err.message || "Failed to reply";
   } finally {
     is_submitting = false;
   }
 };

 const is_admin = $derived(blog.user?.role?.includes("admin") ?? false);
 const start_edit_comment = (comment: Comment) => {
   editing_comment_id = comment.id;
   edited_content = comment.content_markdown;
 };

 const cancel_edit_comment = () => {
   editing_comment_id = undefined;
   edited_content = "";
 };

 const save_edit_comment = async (comment: Comment) => {
   if (post?.id === undefined) return;
   await blog_api.edit_comment(post.id, comment.id, {
     username: comment.username,
     content_markdown: edited_content,
   });
   cancel_edit_comment();
 };

 const delete_comment = async (comment: Comment) => {
   if (post?.id === undefined) return;
   if (!confirm(`Delete comment by ${comment.username}?`)) return;
   await blog_api.delete_comment(post.id, comment.id, {
     username: comment.username,
     content_markdown: comment.content_markdown,
   });
 };

 
 let slug = $derived(route.params.slug);

 const load_post = async () => {
   loading = true;
   error = null;

   try {
     post = await blog_api.get_post(slug);
   } catch (e: any) {
     error = e.message || "Failed to load post";
     post = null;
   } finally {
     loading = false;
   }
 };

 const handle_submit = async (e: Event) => {
   e.preventDefault();

   if (content === null || content === "") {
     error = "Content is required";
     return;
   }

   if (post?.id === undefined) {
     error = "Post is required";
     return;
   }

   const payload = {
     username: (username ?? "anonymous").trim(),
     content_markdown: (content ?? "").trim(),
   };

   is_submitting = true;
   error = "";
   try {
     await blog_api.create_comment(payload, post?.id);
   } catch (err: any) {
     error = err.message || "Failed to create comment";
   } finally {
     is_submitting = false;
   }
 };

 onMount(() => {
   blog.check();

   ws = new WebSocket(ws_url);
   ws!.onopen = () => {
     ws_open = true;
     subscribed_post_id = undefined;
   };

   ws!.onclose = () => {
     ws_open = false;
   };

   ws!.onmessage = (e) => {
     const msg = JSON.parse(e.data);
     switch (msg.event) {
       case "post_comments:initial":
         comments = msg.comments.map(normalize_comment);
         break;
       case "post_comments:new":
       	 {
	   const comment = normalize_comment(msg);
	   if (!comments.some((c) => c.id === comment.id)) {
	     comments = [...comments, comment];
	   }
	 }
         break;
       case "post_comments:edited":
         comments = comments.map((comment) =>
           comment.id === Number(msg.id) ? { ...comment, content_markdown: msg.content_markdown, edited_at: Number(msg.edited_at) } : comment,
         );
         break;
       case "post_comments:deleted":
         remove_comment_tree(Number(msg.id));
         break;
       case "post_comments:voted":
         comments = comments.map((c) => (c.id === Number(msg.id) ? { ...c, votes: Number(msg.votes) } : c));
         break;
       default:
         break;
     }
   };
 });

 $effect(() => {
   const id = post?.id;
   if (!ws_open || !ws || id === undefined || subscribed_post_id === id) return;
   subscribed_post_id = id;
   ws.send(JSON.stringify({ event: "subscribe", channel: "post_" + id }));
   ws.send(JSON.stringify({ event: "fetch_post_comments", post_id: id }));
 });
 
 onDestroy(() => {
   ws?.close();
 });
 
 $effect(() => {
   load_post();
 });

 $effect(() => {
   if (!comments.length || !location.hash.startsWith("#comment-")) return;
   const id = Number(location.hash.slice("#comment-".length));
   const p = pagination?.page_of(id);
   if (p !== undefined && p > 0) page = p;
   tick().then(() => document.querySelector(location.hash)?.scrollIntoView());
 });
 
 const delete_post = async () => {
   if (!post) return;
   if (!blog.is_logged_in) {
     goto("/login/");
     return;
   }

   if (!confirm(`Delete ${post.title} by ${post.author.username}?`)) return;

   await blog_api.delete_post(post.id.toString());
   goto("/blog/");
 };

 const can_modify = (): boolean => {
   if (!blog.loading && !blog.is_logged_in) return false;
   if (post?.slug !== slug && post?.id.toString() !== slug) return false;
   if (
     post?.author.uuid !== blog.user?.uuid &&
     !blog.user?.role.includes("admin")
   )
     return false;
   return true;
 };
</script>

<main>
  <Meta title={post?.title ?? "Post"} description={post?.summary ?? undefined} path={`/blog/post/${slug}/`} />
  <Cell title="Post">
    {#if loading}
      <p>Loading post...</p>
    {:else if error}
      <p class="text-(--color-danger)">{error}</p>
    {:else if post}
      <p class="absolute text-xs top-1"><Link href="/blog/" target="_self">{`<-`} Back to blog</Link></p>
      <Cell title="metadata">
        <Heading level="1">{post.title}</Heading>
        <dl class="post-meta">
          <dt>Slug</dt>
          <dd>{post.slug}</dd>
          {#if post.summary}
            <dt>Summary</dt>
            <dd>{post.summary}</dd>
          {/if}
          {#if post.tags?.length}
            <dt>Tags</dt>
            <dd class="post-meta-tags">
              {#each post.tags as tag}<span class="post-meta-tag">#{tag}</span>{/each}
            </dd>
          {/if}
          <dt>Posted</dt>
          <dd>{blog_api.convert_unix_timestamp_to_date(post.posted_at)}</dd>
          <dt>Edited</dt>
          <dd>{post.edited_at === null ? "never" : blog_api.convert_unix_timestamp_to_date(post.edited_at)}</dd>
        </dl>
      </Cell>
      <Cell title="Content">
        <RichMarkdown render_images={true} md={post.content_markdown} />
        {#if can_modify()}
          <div class="mt-4">
            <ul class="post-actions">
              <li><button class="button-edit" onclick={() => { show_edit_modal = !show_edit_modal; }}>Edit</button></li>
              <li><button class="button-delete" onclick={delete_post}>Delete</button></li>
            </ul>
          </div>
        {/if}
      </Cell>
    {/if}
  </Cell>
  {#if show_edit_modal}
    <PostModal show={show_edit_modal} on_close={() => { show_edit_modal = false; }} on_saved={() => { load_post(); }} post_id={post?.id} post_slug={post?.slug} />
  {:else if post}
      <Cell title="Post A Comment">
        <div class="form-container">
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
              <textarea bind:value={content} name="content" required placeholder="Write something..." maxlength="800"></textarea>
            </label>
            <button type="submit" class="button-guestbook" disabled={is_submitting}>
              {is_submitting ? 'Submitting...' : 'Submit'}
            </button>
          </form>
        </div>
      </Cell>
      {#snippet comment_block(comment: Comment, depth: number)}
        <div id={`comment-${comment.id}`} class:comment-reply={depth > 0}>
          <div class="title-and-meta">
            <p class="font-bold">{comment.username}</p>
            <p class="text-xs">{blog_api.convert_unix_timestamp_to_date(comment.posted_at)}</p>
            <p class="text-xs">{comment.edited_at ? blog_api.convert_unix_timestamp_to_date(comment.edited_at) : "never"}</p>
          </div>
          {#if editing_comment_id === comment.id}
            <form class="guestbook-form mt-4 max-w-none" onsubmit={(e) => { e.preventDefault(); save_edit_comment(comment); }}>
              {#if edited_content}
                <RichMarkdown md={edited_content ?? ""} />
              {/if}
              <textarea bind:value={edited_content}></textarea>
              <div class="flex flex-row gap-2">
                <button type="submit" class="button-edit">Save</button>
                <button type="button" class="button-delete" onclick={cancel_edit_comment}>Cancel</button>
              </div>
            </form>
          {:else}
            <RichMarkdown md={comment.content_markdown} />
            <div class="mt-4 flex flex-row items-center justify-between gap-2">
              <div class="flex flex-row items-center gap-4">
                <button class="button-vote" onclick={() => vote_comment(comment)}>▲ {comment.votes ?? 0}</button>
                <button class="button-reply" onclick={() => start_reply(comment)}>Reply</button>
              </div>
              {#if is_admin}
                <ul class="post-actions">
                  <li><button class="button-edit" onclick={() => start_edit_comment(comment)}>Edit</button></li>
                  <li><button class="button-delete" onclick={() => delete_comment(comment)}>Delete</button></li>
                </ul>
              {/if}
            </div>
            {#if replying_to === comment.id}
              <form class="guestbook-form mt-4 max-w-none" onsubmit={(e) => submit_reply(e, comment)}>
                {#if reply_content}
                  <RichMarkdown md={reply_content} />
                {/if}
                <label class="username">
                  USERNAME
                  <input type="text" bind:value={reply_username} placeholder="Anonymous" maxlength="32" />
                </label>
                <label class="content">
                  CONTENT (MARKDOWN)
                  <textarea bind:value={reply_content} placeholder="Write a reply..." maxlength="800"></textarea>
                </label>
                <div class="flex flex-row gap-2">
                  <button type="submit" class="button-guestbook" disabled={is_submitting}>Reply</button>
                  <button type="button" class="button-delete" onclick={cancel_reply}>Cancel</button>
                </div>
              </form>
            {/if}
          {/if}
          {#if children_of.get(comment.id)?.length}
            <div class="comment-children">
              {#each children_of.get(comment.id) ?? [] as child}
                {@render comment_block(child, depth + 1)}
              {/each}
            </div>
          {/if}
        </div>
      {/snippet}
      <Pagination split bind:this={pagination} items={top_level_comments} bind:per_page bind:order bind:page>
        {#snippet children(visible)}
          {#each visible as comment}
            <Cell title="Comment">
              {@render comment_block(comment, 0)}
            </Cell>
          {/each}
        {/snippet}
      </Pagination>
  {/if}
</main>

<style>
 @reference "$tailcss";

 input,
 textarea {
   @apply bg-(--color-bg) text-(--color-text) p-2 w-full active:border-(--color-accent) active:outline-none active:ring-(--color-accent) focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
 }

 label {
   @apply flex flex-col text-xs text-(--color-accent);
 }

 .post-meta {
   @apply grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm items-baseline;
 }

 .post-meta dt {
   @apply text-xs uppercase tracking-wide text-(--color-subtext);
 }

 .post-meta dd {
   @apply m-0;
 }

 .post-meta-tags {
   @apply flex flex-row flex-wrap gap-2;
 }

 .post-meta-tag {
   @apply text-xs text-(--color-bg) bg-(--color-accent) px-2 py-0.5;
 }

 .comment-children {
   @apply mt-4 flex flex-col gap-2;
 }

 .comment-reply {
   @apply border-l-2 border-(--color-overlay) pl-4;
 }
</style>
