<script>
const { children = null, title = null } = $props();

const actual_title = $derived(title.toUpperCase());
</script>

<section class="cell-container">
  <div class="cell">
    {#if title}
      <div class="title-holder">
        {actual_title}
      </div>
    {/if}
    {@render children?.()}
  </div>
</section>

<style>
  @reference '$tailcss';

  .title-holder {
    @apply absolute top-2 right-2 text-(--color-accent) text-[7px] select-none;
  }

  .cell-container {
    @apply flex flex-col items-center justify-center w-full font-arimo;
  }

  .cell {
    @apply border-2 p-4 m-2 lg:w-200 lg:max-w-200 w-[90%] max-w-[90%] border-(--color-overlay) bg-(--color-bg) relative;
  }
</style>
