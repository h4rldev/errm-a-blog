<script lang="ts">
 import Markdown, { denylist, type Plugin } from "svelte-exmarkdown";
 import rehypeHighlight from "rehype-highlight";
 import Heading from "$components/Heading.svelte";
 import Link from "$components/Link.svelte";

 let { md, render_images = false } = $props();

 type Run = { text: string; classes: string[] };

 function flatten(nodes: any[], classes: string[] = []): Run[] {
   const runs: Run[] = [];
   for (const n of nodes) {
     if (n.type === "text") runs.push({ text: n.value, classes });
     else if (n.type === "element")
       runs.push(...flatten(n.children, [...classes, ...(n.properties?.className ?? [])]));
   }
   return runs;
 }

 function add_line_numbers(code: any): void {
   const lines: Run[][] = [[]];
   for (const run of flatten(code.children)) {
     run.text.split("\n").forEach((part, i) => {
       if (i > 0) lines.push([]);
       if (part) lines[lines.length - 1].push({ text: part, classes: run.classes });
     });
   }

   if (lines.length > 1 && lines[lines.length - 1].length === 0) lines.pop();
   code.children = lines.map((line) => ({
     type: "element",
     tagName: "span",
     properties: { className: ["code-line"] },
     children: line.map((run) =>
       run.classes.length
       ? { type: "element", tagName: "span", properties: { className: run.classes }, children: [{ type: "text", value: run.text }] }
       : { type: "text", value: run.text },
     ),
   }));
 }

 function process_code(node: any): void {
   if (!node.children) return;
   node.children.forEach((child: any, i: number) => {
     if (child.type === "element" && child.tagName === "pre") {
       const code = child.children?.find((c: any) => c.type === "element" && c.tagName === "code");
       if (!code) return;
       add_line_numbers(code);
       const lang = (code.properties?.className as string[] | undefined)?.find((c) => c.startsWith("language-"));
       if (lang) {
         node.children[i] = {
           type: "element",
           tagName: "div",
           properties: { className: ["code-block"] },
           children: [
             { type: "element", tagName: "div", properties: { className: ["code-header"] }, children: [{ type: "text", value: lang.slice(9) }] },
             child,
           ],
         };
       }
     } else {
       process_code(child);
     }
   });
 }

 const rehype_code = () => (tree: any) => process_code(tree);

 const plugins = $derived<Plugin[]>([
   { rehypePlugin: rehypeHighlight },
   { rehypePlugin: rehype_code },
   ...(render_images ? [] : [denylist(["img"])]),
 ]);
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

 .rich-markdown :global(.code-block) {
   @apply my-4 border border-(--color-overlay);
 }

 .rich-markdown :global(.code-header) {
   @apply bg-(--color-surface-secondary) text-(--color-subtext) text-xs px-4 py-1 border-b border-(--color-overlay);
 }

 .rich-markdown :global(.code-block pre) {
   @apply my-0 border-0 rounded-none px-4 py-3;
 }

 .rich-markdown :global(.code-block pre code) {
   @apply block;
   counter-reset: line;
 }

 .rich-markdown :global(.code-line) {
   @apply block min-h-[1lh];
   counter-increment: line;
 }

 .rich-markdown :global(.code-line)::before {
   content: counter(line);
   @apply inline-block w-5 mr-2 text-(--color-overlay) select-none;
 }
</style>
