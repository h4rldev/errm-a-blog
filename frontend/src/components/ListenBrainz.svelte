<script lang="ts">
 import { onDestroy, onMount } from "svelte";
 import { create_listenbrainz, type Listen } from "$lib/listenbrainz.svelte";

 let {
   username = "h4rl",
   refresh_interval = 15000,
   show_album_art = true,
   recent_count = 5,
 } = $props();

 const listenbrainz = create_listenbrainz(username, refresh_interval, recent_count);

 onMount(() => {
   listenbrainz.start();
 });

 onDestroy(() => {
   listenbrainz.destroy();
 });
</script>

{#if listenbrainz.is_loading && !listenbrainz.current_listen && !listenbrainz.last_listen}
  <div class="lb-now-playing lb-loading">
    <span> Loading... </span>
  </div>
{:else if listenbrainz.error}
  <div class="lb-now-playing lb-error">
    <span> Error: {listenbrainz.error} </span>
  </div>
{:else if listenbrainz.current_listen || listenbrainz.last_listen}
  {@const listen = (listenbrainz.current_listen ?? listenbrainz.last_listen) as Listen}
  {@const playing_now = !!listenbrainz.current_listen}
  {@const recent = playing_now ? listenbrainz.recent_listens.slice(0, recent_count) : listenbrainz.recent_listens.slice(1, recent_count + 1)}
  <div class="lb-layout">
    <div class="lb-now-playing">
      {#if show_album_art}
        {@const cover_art_url = listenbrainz.get_cover_art_url(listen)}
        {#if cover_art_url}
          {#if listen.track_metadata.additional_info?.release_mbid}
            <a
              class="lb-cover-link"
              href="https://musicbrainz.org/release/{listen.track_metadata.additional_info.release_mbid}"
              target="_blank"
              rel="noopener noreferrer"
            >
              <img src={cover_art_url} alt="Album art" class="lb-cover-art" loading="lazy" />
            </a>
          {:else}
            <img src={cover_art_url} alt="Album art" class="lb-cover-art" loading="lazy" />
          {/if}
        {:else}
          <div class="lb-cover-art lb-placeholder">💿</div>
        {/if}
      {/if}
      <div class="lb-track-info">
        <div class="lb-track-name">
          {#if listen.track_metadata.additional_info?.track_mbid}
            <a href="https://musicbrainz.org/track/{listen.track_metadata.additional_info?.track_mbid}" target="_blank" rel="noopener noreferrer">
              {listen.track_metadata.track_name}
            </a>
          {:else}
            {listen.track_metadata.track_name}
          {/if}
        </div>
        <div class="lb-artist-name">
          {#if listen.track_metadata.additional_info?.artist_mbids}
            {#each listen.track_metadata.additional_info?.artist_mbids as artist_mbid}
              <a href="https://musicbrainz.org/artist/{artist_mbid}" target="_blank" rel="noopener noreferrer">
                {listen.track_metadata.artist_name}
              </a>
            {/each}
          {:else}
            {listen.track_metadata.artist_name}
          {/if}
        </div>
        {#if listen.track_metadata.release_name}
          <div class="lb-release-name">
            {#if listen.track_metadata.additional_info?.release_mbid}
              <a class="special-link" href="https://musicbrainz.org/release/{listen.track_metadata.additional_info?.release_mbid}" target="_blank" rel="noopener noreferrer">
                {listen.track_metadata.release_name}
              </a>
            {:else}
              {listen.track_metadata.release_name}
            {/if}
          </div>
        {/if}
        {#if playing_now}
          <div class="lb-playing-indicator">● Now Playing</div>
        {:else}
          <div class="lb-playing-indicator lb-last-played">Last played</div>
        {/if}
      </div>
    </div>
    {#if recent.length}
      <ul class="lb-recent">
        {#each recent as item}
          {@const art = listenbrainz.get_cover_art_url(item)}
          <li class="lb-recent-item">
            {#if show_album_art && art}
              <img class="lb-recent-art" src={art} alt="" />
            {:else}
              <div class="lb-recent-art lb-placeholder"></div>
            {/if}
            <div class="lb-recent-text">
              <span class="lb-recent-track">
                {#if item.track_metadata.additional_info?.track_mbid}
                  <a href="https://musicbrainz.org/track/{item.track_metadata.additional_info?.track_mbid}" target="_blank" rel="noopener noreferrer">{item.track_metadata.track_name}</a>
                {:else}
                  {item.track_metadata.track_name}
                {/if}
              </span>
              <span class="lb-recent-artist"> ·
                {#if item.track_metadata.additional_info?.artist_mbids?.[0]}
                  <a href="https://musicbrainz.org/artist/{item.track_metadata.additional_info?.artist_mbids?.[0]}" target="_blank" rel="noopener noreferrer">{item.track_metadata.artist_name}</a>
                {:else}
                  {item.track_metadata.artist_name}
                {/if}
              </span>
              {#if item.track_metadata.release_name}
                <span class="lb-recent-album"> ·
                  {#if item.track_metadata.additional_info?.release_mbid}
                    <a href="https://musicbrainz.org/release/{item.track_metadata.additional_info?.release_mbid}" target="_blank" rel="noopener noreferrer">{item.track_metadata.release_name}</a>
                  {:else}
                    {item.track_metadata.release_name}
                  {/if}
                </span>
              {/if}
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
{:else}
  <div class="lb-now-playing lb-idle">
    <span> Not currently listening to anything. </span>
  </div>
{/if}

<style>
 @reference '$tailcss';

 .lb-now-playing {
   @apply flex items-center justify-center py-3 px-4 font-arimo flex-1 min-w-0 transition-all duration-200;
 }

 a {
   @apply text-(--color-text) hover:text-(--color-accent) hover:underline;
 }

 .lb-layout {
   @apply flex flex-col sm:flex-row items-stretch gap-4 sm:gap-0 w-full;
 }

 .lb-recent {
   @apply flex flex-col gap-1 min-w-0 py-3 sm:flex-1 sm:border-l sm:border-(--color-overlay) sm:pl-4;
 }

 .lb-recent-item {
   @apply flex flex-row items-center gap-2 min-w-0;
 }

 .lb-recent-art {
   @apply w-6 h-6 object-cover rounded-sm shrink-0 bg-(--color-secondary);
 }

 .lb-recent-text {
   @apply min-w-0 text-sm whitespace-nowrap overflow-hidden text-ellipsis;
 }

 .lb-recent-track {
   @apply font-bold text-(--color-text);
 }

 .lb-recent-artist,
 .lb-recent-album {
   @apply text-(--color-overlay);
 }
 
 .lb-loading,
 .lb-idle {
   @apply justify-center text-(--color-overlay);
 }

 .lb-error {
   @apply justify-center text-(--color-error);
 }

 .lb-cover-art {
   @apply w-32 h-32 object-cover rounded-sm shrink-0 bg-(--color-secondary);
 }

 .lb-cover-link {
   @apply shrink-0;
 }
 
 .lb-placeholder {
   @apply flex items-center justify-center text-lg bg-(--color-surface-secondary);
 }

 .lb-track-info {
   @apply flex flex-col min-w-0;
 }

 .lb-track-name {
   @apply mx-4 font-bold text-base text-(--color-text) whitespace-nowrap overflow-hidden text-ellipsis inline;
 }

 .lb-artist-name {
   @apply mx-4 text-sm text-(--color-text) whitespace-nowrap overflow-hidden text-ellipsis inline;
 }

 .lb-release-name {
   @apply mx-4 text-xs text-(--color-text) whitespace-nowrap overflow-hidden text-ellipsis inline;
 }

 .lb-recent-artist a,
 .lb-recent-album a {
   @apply text-(--color-overlay) hover:text-(--color-accent) hover:underline;
 }
 
 .lb-playing-indicator {
   @apply mx-4 text-xs text-(--color-accent) inline;
   animation: lb-pulse 1.5s ease-in-out infinite;
 }

 .lb-last-played {
   @apply text-(--color-overlay);
   animation: none;
 }


 @keyframes lb-pulse {
   0%,
   100% {
     opacity: 1;
   }
   50% {
     opacity: 0.4;
   }
 }

</style>
