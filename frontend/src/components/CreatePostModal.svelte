<script lang="ts">
import Cell from "$components/Cell.svelte";
import Heading from "$components/Heading.svelte";
import TagInput from "$components/TagInput.svelte";

import { blog_api } from "$lib/blog_api";

let { show, on_close, on_post } = $props();

let is_submitting = $state<boolean>(false);
let error = $state<string | null>(null);
let slug_manually_edited = $state<boolean>(false);

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
		await blog_api.create_post(payload);
		close_modal();
    on_post();
	} catch (e: any) {
		error = e.message || "Failed to create post";
	} finally {
		is_submitting = false;
	}
};

const close_modal = () => {
	if (on_close) on_close();
};

const handle_keydown = (e: KeyboardEvent) => {
	if (e.key === "Escape" && show_modal) close_modal();
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
      <Cell title="Create post">
        <div class="form-container">
          <Heading level="2">Create a new post</Heading>

          {#if error}
            <p class="text-(--color-error)">{error}</p>
          {/if}

          <form onsubmit={handle_submit} class="post-form">
            <label>
              <div>TITLE <span class="text-(--color-error)">*</span></div>
              <input type="text" bind:value={form_data.title} placeholder="Title" required />
            </label>

            <label>
              SLUG
              <input type="text" bind:value={form_data.slug} oninput={() => { slug_manually_edited = true; }} placeholder="Slug (auto-generated from title)" />
              <p class="text-(--color-subtext)">Leave blank to auto-generate, or type a custom slug</p>
            </label>

            <label>
              SUMMARY
              <textarea bind:value={form_data.summary} placeholder="Summary" rows="2"></textarea>
            </label>

            <label>
              <div> CONTENT (MARKDOWN) <span class="text-(--color-error)">*</span></div>
              <textarea bind:value={form_data.content_markdown} placeholder="Content" rows="6"></textarea>
            </label>
            <div>
              <label for="tag-input">
                TAGS
              </label>
              <TagInput bind:tags={form_data.tags} id="tags" placeholder="Type to search or add tags..." />
            </div>
            <div class="actions">
              <button type="button" class="button-secondary" onclick={close_modal}>Cancel</button>
              <button type="submit" class="button-primary" disabled={is_submitting}>{is_submitting ? "Creating..." : "Create"}</button>
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

  .form-container {
    @apply flex flex-col justify-center items-center font-arimo mb-4;
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
