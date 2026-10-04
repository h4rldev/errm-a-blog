<script lang="ts">
 import Markdown, { denylist, type Plugin } from "svelte-exmarkdown";
 import rehypeHighlight from "rehype-highlight";
 import Heading from "$components/Heading.svelte";
 import Link from "$components/Link.svelte";

 let { md, render_images = false } = $props();

 const plugins: Plugin[] = [
   { rehypePlugin: rehypeHighlight },
   ...(render_images ? [] : [denylist(["img"])]),
 ];
</script>

<div class="prose prose-neutral max-w-none rich-markdown">
  <Markdown md={md} {plugins}>
    {#snippet h1(props)}
      {@const { children } = props}
      <Heading level="1">{@render children?.()}</Heading>
    {/snippet}
    {#snippet h2(props)}
      {@const { children } = props}
      <Heading level="2">{@render children?.()}</Heading>
    {/snippet}
    {#snippet h3(props)}
      {@const { children } = props}
      <Heading level="3">{@render children?.()}</Heading>
    {/snippet}
    {#snippet h4(props)}
      {@const { children } = props}
      <Heading level="4">{@render children?.()}</Heading>
    {/snippet}
    {#snippet h5(props)}
      {@const { children } = props}
      <Heading level="5">{@render children?.()}</Heading>
    {/snippet}
    {#snippet h6(props)}
      {@const { children } = props}
      <Heading level="6">{@render children?.()}</Heading> 
    {/snippet}
    {#snippet a(props)}
      {@const { children,  download, href, hreflang, media, ping, rel, target, type, referrerpolicy } = props}
      <Link {href} target={target ?? undefined} {download} {media} {hreflang} {ping} {rel} {type} {referrerpolicy}>
      {@render children?.()}
        </Link>
    {/snippet}
  </Markdown>
</div>

<style>
 @reference '$tailcss';

 .rich-markdown {
   --tw-prose-body: var(--color-text);
   --tw-prose-headings: var(--color-text);
   --tw-prose-links: var(--color-link);
   --tw-prose-bold: var(--color-text);
   --tw-prose-counters: var(--color-subtext);
   --tw-prose-bullets: var(--color-accent);
   --tw-prose-hr: var(--color-overlay);
   --tw-prose-quotes: var(--color-subtext);
   --tw-prose-quote-borders: var(--color-accent);
   --tw-prose-captions: var(--color-subtext);
   --tw-prose-code: var(--color-accent);
   --tw-prose-pre-code: var(--color-text);
   --tw-prose-pre-bg: var(--color-surface);
   --tw-prose-th-borders: var(--color-overlay);
   --tw-prose-td-borders: var(--color-surface-secondary);
   @apply text-(--color-text);
 }
</style>
