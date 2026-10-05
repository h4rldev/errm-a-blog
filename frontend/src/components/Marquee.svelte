<script module lang="ts">
 export interface Badge {
   src: string;
   href?: string;
   alt?: string;
 }
</script>

<script lang="ts">
 import type { Snippet } from "svelte";
 import Link from "$components/Link.svelte";

 let {
   badges,
   duration = 30,
   children,
 }: {
   badges: Badge[];
   duration?: number;
   children?: Snippet;
 } = $props();

 let measure_el = $state<HTMLDivElement>();
 let viewport_width = $state(0);
 let copy_width = $state(0);

 const copies = $derived(
   copy_width > 0 && viewport_width > 0 ? Math.max(2, Math.ceil(viewport_width / copy_width) + 1) : 2,
 );

 const shift = $derived(`-${100 / copies}%`);
 const looped = $derived(Array.from({ length: copies }, () => badges).flat());

 $effect(() => {
   if (!measure_el) return;
   const measure = () => {
     copy_width = measure_el!.getBoundingClientRect().width;
     viewport_width = window.innerWidth;
   };
   measure();
   const ro = new ResizeObserver(measure);
   ro.observe(measure_el);
   window.addEventListener("resize", measure);
   return () => {
     ro.disconnect();
     window.removeEventListener("resize", measure);
   };
 });
</script>

<div class="marquee">
  <div class="marquee-measure" bind:this={measure_el} aria-hidden="true">
    {#each badges as badge, i (i)}
      <span class="badge-item">
        <img src={badge.src} alt="" width="88" height="31" class="badge" />
      </span>
    {/each}
  </div>
  <div
    class="marquee-track"
    style={`animation-duration: ${duration}s; --shift: ${shift}`}
  >
    {#each looped as badge, i (i)}
      <span class="badge-item">
        {#if badge.href}
          <Link href={badge.href} target="_blank">
          <img src={badge.src} alt={badge.alt ?? ""} width="88" height="31" class="badge" loading="lazy" />
          </Link>
        {:else}
          <img src={badge.src} alt={badge.alt ?? ""} width="88" height="31" class="badge" loading="lazy" />
        {/if}
      </span>
    {/each}
  </div>
  {#if children}{@render children()}{/if}
</div>

<style>
 @reference '$tailcss';

 .marquee {
   @apply relative w-full overflow-hidden mt-2;
 }

 .marquee-measure {
   @apply invisible absolute pointer-events-none top-0 left-0 flex flex-row w-max;
 }

 .marquee-track {
   @apply flex flex-row w-max;
   animation: marquee linear infinite;
 }

 .marquee:hover .marquee-track {
   animation-play-state: paused;
 }

 .badge-item {
   @apply shrink-0;
   margin-right: 0.5rem;
 }

 .badge {
   @apply block object-cover;
   image-rendering: pixelated;
 }

 @keyframes marquee {
   from { transform: translateX(0); }
   to   { transform: translateX(var(--shift)); }
 }

 @media (prefers-reduced-motion: reduce) {
   .marquee-track { animation: none; }
 }
</style>
