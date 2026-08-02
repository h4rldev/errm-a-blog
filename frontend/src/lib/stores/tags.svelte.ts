const is_dev = import.meta.env.DEV;
const is_prod = import.meta.env.PROD;

let tags = $state<string[]>([]);
let loading = $state<boolean>(false);
let error = $state<string | null>(null);

const fetch_tags = async () => {
	if (loading) return;

	const url = is_dev
		? "http://localhost:8080"
		: is_prod
			? ""
			: "http://localhost:8080";
	const endpoint = url + "/api/tags";

	loading = true;
	error = null;

	try {
		const response = await fetch(endpoint);
		const data = await response.json();
		if (!response.ok) throw new Error(data.error || "Failed to fetch tags");
		tags = data.tags || [];
	} catch (e: any) {
		error = e.message;
	} finally {
		loading = false;
	}
};

export const tags_store = {
	get tags() {
		return tags;
	},
	get loading() {
		return loading;
	},
	get error() {
		return error;
	},
	fetch_tags,
};
