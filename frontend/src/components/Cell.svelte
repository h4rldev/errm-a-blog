<script>
const { children = null } = $props();
</script>

<section class="cell-container">
  <div class="cell">
    {@render children?.()}
  </div>
</section>

<style>
  @reference '$tailcss';

  .cell-container {
    @apply flex flex-col items-center justify-center w-full font-arimo;
  }

  .cell {
    @apply border-2 p-4 m-2 w-[800px] max-w-[800px] border-[var(--color-overlay)] bg-[var(--color-bg)];
  }
</style>
