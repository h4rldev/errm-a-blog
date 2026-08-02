<script>
import Cell from "$components/Cell.svelte";
import Link from "$components/Link.svelte";

const current_year = new Date().getFullYear();

// @ts-expect-error
const commit_hash = __GIT_COMMIT_HASH__;
// @ts-expect-error
const repo_url = __REPO_URL__;
</script>

<footer>
  <Cell title="footer">
    <ul>
      <li> git: <Link href={repo_url}>{commit_hash}</Link> </li>
      <li> &copy; {current_year} h4rl </li>
      <li> Code: <Link href="{repo_url}/LICENSE">BSD-3 Clause</Link> </li>
      <li> Content: <Link href="{repo_url}/LICENSE-CONTENT">CC-BY-SA 4.0</Link> </li>
    </ul>
  </Cell>
</footer>

<style>
  @reference '$tailcss';

  footer {
    @apply relative;
  }

  ul {
    @apply flex flex-row text-(--color-text) justify-center flex-wrap;
  }

  ul > *:not(:last-child)::after {
    @apply mx-2 text-(--color-subtext-alt);
    content: "|";
  }

</style>
