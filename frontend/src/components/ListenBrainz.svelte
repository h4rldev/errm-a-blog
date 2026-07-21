<script>
import { onDestroy, onMount } from "svelte";
import { create_listenbrainz } from "$lib/listenbrainz.svelte";

let {
	username = "h4rl",
	refresh_interval = 15000,
	show_album_art = true,
	show_timestamp = false,
} = $props();

const listenbrainz = $derived(create_listenbrainz(username, refresh_interval));

onMount(() => {
	listenbrainz.start();
});

onDestroy(() => {
	listenbrainz.destroy();
});

let elapsed = $state("0:00");
$effect(() => {
	if (!listenbrainz.current_listen) return;
	const interval = setInterval(() => {
		const seconds = listenbrainz.get_elapsed_seconds(
			listenbrainz.current_listen,
		);
		const mins = Math.floor(seconds / 60);
		const secs = seconds % 60;
		elapsed = `${mins}:${secs.toString().padStart(2, "0")}`;
	}, 1000);
	return () => clearInterval(interval);
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
        <img src={cover_art_url} alt="Album art" class="lb-cover-art" loading="lazy" />
      {:else}
        <div class="lb-cover-art lb-placeholder">💿</div>
      {/if}
    {/if}
    <div class="lb-track-info">
      <div class="lb-track-name">
        {listenbrainz.current_listen.track_metadata.track_name}
      </div>
      <div class="lb-artist-name">
        {listenbrainz.current_listen.track_metadata.artist_name}
      </div>
      {#if listenbrainz.current_listen.track_metadata.release_name}
        <div class="lb-release-name">
          {listenbrainz.current_listen.track_metadata.release_name}
        </div>
      {/if}
      {#if show_timestamp}
        <div class="lb-timestamp">
          Started: {listenbrainz.format_time(listenbrainz.current_listen.listened_at)}
        </div>
        <div class="lb-elapsed">⏱ {elapsed}</div>
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
  @apply flex items-center justify-center py-[0.75rem] px-[1rem] font-arimo w-full transition-all duration-200;
}

.lb-loading,
.lb-idle {
  @apply justify-center text-[var(--color-secondary)];
}

.lb-error {
  @apply justify-center text-[var(--color-error)];
}

.lb-cover-art {
  @apply w-[8rem] h-[8rem] object-cover rounded-sm shrink-0 bg-[--color-secondary];
}

.lb-placeholder {
  @apply flex items-center justify-center text-lg bg-[var(--color-surface-secondary)];
}

.lb-track-info {
  @apply flex flex-col min-w-[0];
}

.lb-track-name {
  @apply mx-4 font-bold text-base text-[var(--color-text)] whitespace-nowrap overflow-hidden overflow-ellipsis inline;
}

.lb-artist-name {
  @apply mx-4 text-sm text-[var(--color-text)] whitespace-nowrap overflow-hidden overflow-ellipsis inline;
}

.lb-release-name {
  @apply mx-4 text-xs text-[var(--color-text)] whitespace-nowrap overflow-hidden overflow-ellipsis inline;
}

.lb-timestamp,
.lb-elapsed {
  @apply text-xs text-[var(--color-text)] inline;
}

.lb-playing-indicator {
  @apply mx-4 text-xs text-[var(--color-accent)] inline;
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
