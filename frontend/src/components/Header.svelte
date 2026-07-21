<script>
import Link from "$components/Link.svelte";
import ThemeToggle from "$components/ThemeToggle.svelte";
</script>

<header>
  <div class="header-container">
    <div class="me-ascii">
      <p>
.__        _____        .__
|  |__    /  |  |_______|  |
|  |  \  /   |  |\_  __ \  |
|   Y  \/    ^   /|  | \/  |__
|___|  /\____   | |__|  |____/
     \/      |__|
      </p>
    </div>
    <div>
      <nav>
        <ul class="navigation">
          <li><Link href="/">home</Link></li>
          <li><Link href="/blog">blog</Link></li>
          <li><Link href="/about">about</Link></li>
          <li><Link href="/contact">contact</Link></li>
          <li><ThemeToggle /></li>
        </ul>
      </nav>
    </div>
  </div>
</header>

<style>
@reference '$tailcss';

header {
  @apply w-full flex flex-row items-center justify-center mt-8;
}

.header-container {
  @apply w-[800px] max-w-[800px] flex flex-row items-end justify-between;
}

.navigation {
  @apply flex flex-row gap-4 font-arimo;
}

.me-ascii {
  @apply whitespace-pre-wrap font-mono text-sm;
}
</style>
