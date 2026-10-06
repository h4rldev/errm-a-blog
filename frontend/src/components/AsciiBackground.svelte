<script lang="ts">
 import { onMount } from "svelte";
 import { theme } from "$lib/stores/theme.svelte";

 let canvas: HTMLCanvasElement;
 let color = $state("rgb(148, 226, 213)");
 let alpha = $state(0.28);

 $effect(() => {
   theme.value;
   const cs = getComputedStyle(document.documentElement);
   const c = cs.getPropertyValue("--color-accent").trim();
   if (c) color = c;
   alpha = document.documentElement.classList.contains("dark") ? 0.28 : 0.14;
 });

 onMount(() => {
   const ctx = canvas.getContext("2d");
   if (!ctx) return;
   if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;

   const CHARS = " .,-:;~=+ic*xozXZ#%W@&$08B█▓▒░";
   const CELL = 16;
   const FPS = 15;
   const dpr = Math.min(window.devicePixelRatio || 1, 2);
   let raf = 0;
   let last = 0;

   const resize = () => {
     canvas.width = Math.floor(window.innerWidth * dpr);
     canvas.height = Math.floor(window.innerHeight * dpr);
     canvas.style.width = `${window.innerWidth}px`;
     canvas.style.height = `${window.innerHeight}px`;
     ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
     ctx.font = `${CELL}px monospace`;
     ctx.textBaseline = "top";
   };
   resize();
   window.addEventListener("resize", resize);

   const draw = (t: number) => {
     raf = requestAnimationFrame(draw);
     if (document.hidden || t - last < 1000 / FPS) return;
     last = t;
     const time = t / 1000;
     ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
     ctx.fillStyle = color;
     ctx.globalAlpha = alpha;
     const cols = Math.ceil(window.innerWidth / CELL);
     const rows = Math.ceil(window.innerHeight / CELL);
     for (let y = 0; y < rows; y++) {
       const fy = y / rows;
       const warp = Math.sin(fy * 3.1 + time * 0.4) * 0.5;
       for (let x = 0; x < cols; x++) {
         const fx = x / cols + warp;
         const a = Math.sin(fx * 8.0 + fy * 3.0 + time * 1.1);
         const b = Math.sin(fx * -4.0 + fy * 7.0 - time * 1.3 + 1.7);
         const c = Math.sin((fx + fy) * 6.0 + time * 0.8 + 0.4);
         const d = Math.sin((fx - fy) * 11.0 - time * 1.6);
         const v = (a + b + c + d) / 8 + 0.5;
         if (v > 0.94) {
           ctx.globalAlpha = alpha * 2;
           ctx.fillText("*", x * CELL, y * CELL);
           ctx.globalAlpha = alpha;
         } else {
           const ch = CHARS[(v * (CHARS.length - 1)) | 0];
           if (ch !== " ") ctx.fillText(ch, x * CELL, y * CELL);
         }
       }
     }
   };
   
   raf = requestAnimationFrame(draw);

   return () => {
     cancelAnimationFrame(raf);
     window.removeEventListener("resize", resize);
   };
 });
</script>

<canvas bind:this={canvas} class="ascii-bg" aria-hidden="true"></canvas>

<style>
 @reference "$tailcss";

 .ascii-bg {
   @apply fixed inset-0 -z-10 pointer-events-none select-none;
 }
</style>
