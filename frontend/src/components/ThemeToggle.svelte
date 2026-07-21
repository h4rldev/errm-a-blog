<script>
import { theme } from "$lib/stores/theme.svelte";
</script>

<button onclick={() => theme.toggle()} class="theme_toggler">
  {theme.value === 'light' ? '🌙' : '☀️'}
</button>

<style>
  @reference '$tailcss';
  .theme_toggler {
    @apply hover:text-[var(--color-text)] hover:cursor-pointer;
  }
</style>
