<script>
  const {
    title = null,
    description = "h4rl - Welcome to my little corner of the internet :3",
    path = "",
    image = "/og.webp",
  } = $props();

  const site = "h4rl's webpage!";
  const full_title = $derived(title ? `${title} - ${site}` : site);
  const url = $derived(`https://h4rl.dev${path}`);
</script>

<svelte:head>
  <title>{full_title}</title>
  <meta name="description" content={description} />
  <link rel="canonical" href={url} />

  <meta property="og:type" content="website" />
  <meta property="og:site_name" content={site} />
  <meta property="og:title" content={full_title} />
  <meta property="og:description" content={description} />
  <meta property="og:url" content={url} />
  <meta property="og:image" content={`https://h4rl.dev${image}`} />

  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={full_title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content={`https://h4rl.dev${image}`} />
</svelte:head>
