<script>
  const {
    title = null,
    description = "Welcome to my little corner of the internet :3 - programming, music, and other ramblings.",
    path = "",
    image = "/og.webp",
  } = $props();

  const site = "h4rl.dev";
  const full_title = $derived(title ? `${title} - ${site}` : site);
  const url = $derived(`https://h4rl.dev${path}`);
  const image_url = $derived(`https://h4rl.dev${image}`);
</script>

<svelte:head>
  <title>{full_title}</title>
  <meta name="description" content={description} />
  <link rel="canonical" href={url} />
  <link rel="alternate" type="application/rss+xml" title={site} href="https://h4rl.dev/blog/feed.xml" />

  <meta property="og:type" content="website" />
  <meta property="og:site_name" content={site} />
  <meta property="og:title" content={full_title} />
  <meta property="og:description" content={description} />
  <meta property="og:url" content={url} />
  <meta property="og:image" content={image_url} />
  <meta property="og:image:alt" content={site} />
  <meta property="og:locale" content="en_US" />

  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={full_title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content={image_url} />
</svelte:head>
