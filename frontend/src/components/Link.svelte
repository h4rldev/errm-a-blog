<script>
 const {
   href,
   class: className = null,
   target = "_blank",
   aria_label = null,
   download = null,
   hreflang = null,
   media = null,
   ping = null,
   rel = null,
   type = null,
   referrerpolicy = null,
   children,
 } = $props();
</script>

<a {href} aria-label={aria_label} {type} {media} {hreflang} {download} {rel} {referrerpolicy} {ping} {target} class={className}>
  {@render children?.()}
</a>


<style>
 a {
   @apply text-(--color-link) hover:text-(--color-accent) hover:underline;
 }
</style>
