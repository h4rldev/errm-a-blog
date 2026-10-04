export interface TrackMetadata {
  artist_name: string;
  track_name: string;
  release_name?: string;
  additional_info?: {
    release_mbid?: string;
    artist_mbids?: string[];
    track_mbid?: string;
    recording_mbid?: string;
    cover_art_url?: string;
  };
}

export interface Listen {
  listened_at: number;
  track_metadata: TrackMetadata;
  playing_now?: boolean;
}

interface ApiResponse {
  payload: {
    count: number;
    user_id: string;
    listens: Listen[];
    playing_now?: boolean;
  };
}

export const create_listenbrainz = (
  username: string,
  refresh_interval: number = 15000,
) => {
  let current_listen = $state<Listen | null>(null);
  let last_listen = $state<Listen | null>(null);
  let is_loading = $state<boolean>(true);
  let error = $state<string | null>(null);
  let interval_id = $state<ReturnType<typeof setInterval> | undefined>(
    undefined,
  );

  const get_cover_art_url = (listen: Listen): string | null => {
    const mbid = listen.track_metadata.additional_info?.release_mbid;
    return mbid
      ? `https://coverartarchive.org/release/${mbid}/front-250`
      : null;
  };

  const fetch_now_playing = async () => {
    try {
      error = null;

      const [playing_res, recent_res] = await Promise.all([
        fetch(
          `https://api.listenbrainz.org/1/user/${encodeURIComponent(username)}/playing-now`,
          { signal: AbortSignal.timeout(8000) },
        ),
        fetch(
          `https://api.listenbrainz.org/1/user/${encodeURIComponent(username)}/listens?count=1`,
          { signal: AbortSignal.timeout(8000) },
        ),
      ]);

      if (playing_res.ok) {
        const data: ApiResponse = await playing_res.json();
        const listen = data.payload.listens?.[0] ?? null;
        current_listen = listen?.playing_now ? listen : null;
      }

      if (recent_res.ok) {
        const recent: ApiResponse = await recent_res.json();
        last_listen = recent.payload.listens?.[0] ?? last_listen;
      }
    } catch (e) {
      if (!current_listen && !last_listen) {
        error = e instanceof Error ? e.message : "Failed to fetch data";
      }
    } finally {
      is_loading = false;
    }
  };

  const start = () => {
    fetch_now_playing();
    if (interval_id) clearInterval(interval_id);
    interval_id = setInterval(fetch_now_playing, refresh_interval);
  };

  const stop = () => {
    if (interval_id) {
      clearInterval(interval_id);
      interval_id = undefined;
    }
  };

  const destroy = () => {
    stop();
  };

  return {
    get current_listen() {
      return current_listen;
    },
    get last_listen() {
      return last_listen;
    },
    get is_loading() {
      return is_loading;
    },
    get error() {
      return error;
    },
    get_cover_art_url,
    start,
    stop,
    destroy,
  };
};
