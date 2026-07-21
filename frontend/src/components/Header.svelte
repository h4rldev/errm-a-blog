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
          <li><Link href="/" target="_self" >home</Link></li>
          <li><Link href="/blog" target="_self">blog</Link></li>
          <li><Link href="/projects" target="_self">projects</Link></li>
          <li><Link href="/contact" target="_self">contact</Link></li>
          <li><ThemeToggle /></li>
        </ul>
      </nav>
    </div>
  </div>
</header>

<style>
@reference '$tailcss';

header {
  @apply max-w-full flex flex-row items-center justify-center mt-8 text-base;
}

.header-container {
  @apply lg:w-200 w-full max-w-[90%] lg:max-w-200 flex flex-row items-end justify-between;
}

.navigation {
  @apply flex md:flex-row flex-col md:gap-4 font-arimo xl:text-left text-right;
}

.me-ascii {
  @apply whitespace-pre-wrap font-mono xl:text-sm text-xs;
}
</style>
