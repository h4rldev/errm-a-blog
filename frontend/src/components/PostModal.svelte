<script lang="ts">
 import Cell from "$components/Cell.svelte";
 import Heading from "$components/Heading.svelte";
 import TagInput from "$components/TagInput.svelte";
 import RichMarkdown from "$components/RichMarkdown.svelte";

 import { blog_api, type Post } from "$lib/blog_api";

 let { show, on_close, on_saved, post_id = undefined, post_slug = undefined } = $props();

 let is_editing = $derived(post_id !== undefined || post_slug !== undefined);
 let is_submitting = $state<boolean>(false);
 let error = $state<string | null>(null);
 let slug_manually_edited = $state<boolean>(false);
 let current_post = $state<Post | null>(null);

 interface ModalFormData {
   title: string;
   slug: string;
   summary: string;
   content_markdown: string;
   tags: string[];
 }

 let form_data = $state<ModalFormData>({
   title: "",
   slug: "",
   summary: "",
   content_markdown: "",
   tags: [],
 });

 const slugify = (str: string) => {
   return str
     .toLowerCase()
     .trim()
     .replace(/\s+/g, "-")
     .replace(/[^a-z0-9-]/g, "");
 };

 $effect(() => {
   if (is_editing) {
     blog_api.get_post(String(post_id ?? post_slug)).then((data) => {
       current_post = data;
     }).catch((e: any) => {
       error = e.message || "Failed to get post";
     });
   }
 });

 $effect(() => {
   form_data.title = current_post?.title ?? "";
   form_data.slug = current_post?.slug ?? "";
   form_data.summary = current_post?.summary ?? "";
   form_data.content_markdown = current_post?.content_markdown ?? "";
   form_data.tags = current_post?.tags ?? [];
 });

 $effect(() => {
   if (!slug_manually_edited && form_data.title) {
     form_data.slug = slugify(form_data.title);
   }
 });

 const handle_submit = async (e: Event) => {
   e.preventDefault();
   is_submitting = true;
   error = "";

   const payload = {
     title: form_data.title.trim(),
     slug: form_data.slug.trim(),
     summary: form_data.summary.trim(),
     content_markdown: form_data.content_markdown.trim(),
     tags: form_data.tags.map((t) => t.trim()),
   };

   if (!payload.title || !payload.slug || !payload.content_markdown) {
     error = "Title, slug, and content are required";
     is_submitting = false;
     return;
   }

   try {
     if (is_editing) {
       await blog_api.update_post(String(post_id ?? post_slug), payload);
     } else {
       await blog_api.create_post(payload);
     }
     close_modal();
     on_saved();
   } catch (e: any) {
     error = e.message || `Failed to ${is_editing ? "edit" : "create"} post`;
   } finally {
     is_submitting = false;
   }
 };

 const close_modal = () => {
   if (on_close) on_close();
 };

 const handle_keydown = (e: KeyboardEvent) => {
   if (e.key === "Escape" && show) close_modal();
 };

 $effect(() => {
   if (show) {
     window.addEventListener("keydown", handle_keydown);
     return () => window.removeEventListener("keydown", handle_keydown);
   }
 });
</script>

{#if show}
  <div class="modal-overlay">
    <div class="modal-content">
      {#if form_data.content_markdown}
        <Cell title="Preview">
          <RichMarkdown md={form_data.content_markdown} render_images={true} />
        </Cell>
      {/if}
      <Cell title={is_editing ? "Edit post" : "Create post"}>
        <div class="form-container">
          <Heading level="2">{is_editing ? "Edit a post" : "Create a new post"}</Heading>

          {#if error}
            <p class="text-(--color-error)">{error}</p>
          {/if}

          <form onsubmit={handle_submit} class="post-form">
            <label for="post-title">
              <div>TITLE <span class="text-(--color-error)">*</span></div>
              <input id="post-title" name="title" type="text" bind:value={form_data.title} placeholder="Title" required />
            </label>

            <label for="post-slug">
              SLUG
              <input id="post-slug" name="slug" type="text" bind:value={form_data.slug} oninput={() => { slug_manually_edited = true; }} placeholder="Slug (auto-generated from title)" />
              <p class="text-(--color-subtext)">Leave blank to auto-generate, or type a custom slug</p>
            </label>

            <label for="post-summary">
              SUMMARY
              <textarea id="post-summary" name="summary" bind:value={form_data.summary} placeholder="Summary" rows="2"></textarea>
            </label>

            <label for="post-content">
              <div> CONTENT (MARKDOWN) <span class="text-(--color-error)">*</span></div>
              <textarea id="post-content" name="content_markdown" bind:value={form_data.content_markdown} placeholder="Content" rows="6"></textarea>
            </label>

            <div>
              <label for="tag-input">
                TAGS
              </label>
              <TagInput bind:tags={form_data.tags} id="tag-input" placeholder="Type to search or add tags..." />
            </div>

            <div class="actions">
              <button type="button" class="button-secondary" onclick={close_modal}>Cancel</button>
              <button type="submit" class="button-primary" disabled={is_submitting}>{is_submitting ? (is_editing ? "Editing..." : "Creating...") : (is_editing ? "Edit" : "Create")}</button>
            </div>
          </form>
        </div>
      </Cell>
    </div>
  </div>
{/if}

<style>
 @reference "$tailcss";

 .modal-overlay {
   @apply bg-(--color-bg) transition-opacity duration-200 ease-in-out z-999;
 }

 .post-form {
   @apply flex flex-col gap-4 w-[90%];
 }

 label {
   @apply flex flex-col text-xs text-(--color-accent);
 }

 label > div {
   @apply text-xs text-(--color-accent);
 }

 input {
   @apply bg-(--color-bg) text-(--color-text) p-2 w-full focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
 }

 textarea {
   @apply bg-(--color-bg) text-(--color-text) p-2 w-full focus:border-(--color-accent) focus:outline-none focus:ring-(--color-accent);
 }

 .actions {
   @apply flex flex-row justify-end gap-4;
 }

 .button-secondary {
   @apply hover:cursor-pointer bg-(--color-error) text-(--color-bg) font-bold py-1 px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay);
 }

 .button-primary {
   @apply hover:cursor-pointer bg-(--color-confirm) text-(--color-bg) font-bold py-1 px-2 active:bg-(--color-secondary) active:text-(--color-text) focus:outline-none transition-colors duration-200 ease-in-out border-2 border-(--color-text) active:border-(--color-overlay);
 }

</style>
