<script>
  import { theme } from "$lib/stores/theme.svelte";
</script>

<button onclick={() => theme.toggle()} class="theme_toggler">
  <span class="icon-light">🌙</span><span class="icon-dark">☀️</span>
</button>

<style>
  @reference '$tailcss';
  .theme_toggler {
    @apply hover:text-[var(--color-text)] hover:cursor-pointer;
  }
  .icon-dark { display: none; }
  :global(html.dark) .icon-light { display: none; }
  :global(html.dark) .icon-dark { display: inline; }
</style>
