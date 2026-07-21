<script>
import { onDestroy, onMount } from "svelte";
import { create_listenbrainz } from "$lib/listenbrainz.svelte";

let {
	username = "h4rl",
	refresh_interval = 15000,
	show_album_art = true,
} = $props();

const listenbrainz = $derived(create_listenbrainz(username, refresh_interval));

onMount(() => {
	listenbrainz.start();
});

onDestroy(() => {
	listenbrainz.destroy();
});
</script>

{#if listenbrainz.is_loading && !listenbrainz.current_listen}
  <div class="lb-now-playing lb-loading">
    <span> Loading... </span>
  </div>
{:else if listenbrainz.error}
  <div class="lb-now-playing lb-error">
    <span> Error: {listenbrainz.error} </span>
  </div>
{:else if listenbrainz.current_listen}
  <div class="lb-now-playing">
    {#if show_album_art}
      {@const cover_art_url = listenbrainz.get_cover_art_url(listenbrainz.current_listen)}
      {#if cover_art_url}
        {#if listenbrainz.current_listen.track_metadata.additional_info?.release_mbid}
          <a href="https://musicbrainz.org/release/{listenbrainz.current_listen.track_metadata.additional_info?.release_mbid}" target="_blank" rel="noopener noreferrer">
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
        {#if listenbrainz.current_listen.track_metadata.additional_info?.track_mbid}
          <a href="https://musicbrainz.org/track/{listenbrainz.current_listen.track_metadata.additional_info?.track_mbid}" target="_blank" rel="noopener noreferrer">
          {listenbrainz.current_listen.track_metadata.track_name}
          </a>
        {:else}
          {listenbrainz.current_listen.track_metadata.track_name}
        {/if}
      </div>
      <div class="lb-artist-name">
        {#if listenbrainz.current_listen.track_metadata.additional_info?.artist_mbids}
          {#each listenbrainz.current_listen.track_metadata.additional_info?.artist_mbids as artist_mbid}
            <a href="https://musicbrainz.org/artist/{artist_mbid}" target="_blank" rel="noopener noreferrer">
              {listenbrainz.current_listen.track_metadata.artist_name}
            </a>
          {/each}
        {:else}
          {listenbrainz.current_listen.track_metadata.artist_name}
        {/if}
      </div>
      {#if listenbrainz.current_listen.track_metadata.release_name}
        <div class="lb-release-name">
          {#if listenbrainz.current_listen.track_metadata.additional_info?.release_mbid}
            <a class="special-link" href="https://musicbrainz.org/release/{listenbrainz.current_listen.track_metadata.additional_info?.release_mbid}" target="_blank" rel="noopener noreferrer">
            {listenbrainz.current_listen.track_metadata.release_name}
            </a>
          {:else}
            {listenbrainz.current_listen.track_metadata.release_name}
          {/if}
        </div>
      {/if}
      <div class="lb-playing-indicator">● Now Playing</div>
    </div>
  </div>
{:else}
  <div class="lb-now-playing lb-idle">
    <span> Not currently listening to anything. </span>
  </div>
{/if}

<style>
@reference '$tailcss';

.lb-now-playing {
  @apply flex items-center justify-center py-3 px-4 font-arimo w-full transition-all duration-200;
}

a {
  @apply text-(--color-text) hover:text-(--color-accent) hover:underline;
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

.lb-playing-indicator {
  @apply mx-4 text-xs text-(--color-accent) inline;
  animation: lb-pulse 1.5s ease-in-out infinite;
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
