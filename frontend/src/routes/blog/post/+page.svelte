<script lang="ts">
 import Cell from "$components/Cell.svelte";
 import Link from "$components/Link.svelte";
 import Meta from "$components/Meta.svelte";
</script>

<Meta title="Not found" path="/blog/post/" />
<main>
  <Cell title="Not found">
    <p>There's no post here, did you mean <code>/blog/post/{`{`}slug{`}`}</code> or <code>/blog/post/{`{`}id{`}`}</code>?</p>
    <p> Return to the <Link href="/blog/">blog</Link>?</p>
  </Cell>
</main>
