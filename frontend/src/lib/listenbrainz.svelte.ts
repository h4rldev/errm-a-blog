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
	let is_loading = $state<boolean>(true);
	let error = $state<string | null>(null);
	let interval_id: number | undefined = $state();

	const get_cover_art_url = (listen: Listen): string | null => {
		const mbid = listen.track_metadata.additional_info?.release_mbid;
		return mbid
			? `https://coverartarchive.org/release/${mbid}/front-250`
			: null;
	};

	const format_time = (timestamp: number): string => {
		return new Date(timestamp * 1000).toLocaleTimeString();
	};

	const get_elapsed_seconds = (listen: Listen | null): number => {
		if (!listen) return 0;
		return Math.floor(Date.now() / 1000 - listen.listened_at);
	};

	const fetch_now_playing = async () => {
		try {
			is_loading = true;
			error = null;

			const response = await fetch(
				`https://api.listenbrainz.org/1/user/${encodeURIComponent(username)}/playing-now`,
			);
			if (!response.ok)
				throw new Error("HTTP error!, status: " + response.status);

			const data: ApiResponse = await response.json();
			if (data.payload.listens && data.payload.listens.length > 0) {
				const listen = data.payload.listens[0];
				if (listen.playing_now) {
					current_listen = listen;
				} else {
					current_listen = null;
				}
			} else {
				current_listen = null;
			}
		} catch (e) {
			error = e instanceof Error ? e.message : "Failed to fetch data";
			current_listen = null;
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

	const restart = (new_username?: string, new_interval?: number) => {
		if (new_username) username = new_username;
		if (new_interval) refresh_interval = new_interval;
		stop();
		start();
	};

	const destroy = () => {
		stop();
	};

	return {
		get current_listen() {
			return current_listen;
		},
		get is_loading() {
			return is_loading;
		},
		get error() {
			return error;
		},
		get_cover_art_url,
		get_elapsed_seconds,
		format_time,
		start,
		stop,
		restart,
		destroy,
	};
};
