<script>
const {
	href,
	class: className = "",
	target = 'target: "_blank"',
	aria_label = "",
	children,
} = $props();
</script>

<a {href} aria-label={aria_label} {target} class={className}>
{@render children?.()}
</a>


<style>
  a {
    @apply text-[var(--color-link)] hover:text-[var(--color-accent)] hover:underline;
  }
</style>
