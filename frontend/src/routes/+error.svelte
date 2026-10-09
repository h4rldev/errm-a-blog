<script lang="ts">
 import { page } from "$app/state";

 import Cell from "$components/Cell.svelte";
 import Heading from "$components/Heading.svelte";
 import Meta from "$components/Meta.svelte";
 import Link from "$components/Link.svelte";

 const message = $derived(page.error?.message ?? "Something went wrong");
</script>

<Meta title={`${page.status}`} path="/" />

<main>
  <Cell title="error">
    <Heading level="2">{page.status} - {message}</Heading>
    <p>Whatever you were looking for isn't here.</p>
    <p><Link href="/" target="_self">Go home</Link></p>
  </Cell>
</main>
