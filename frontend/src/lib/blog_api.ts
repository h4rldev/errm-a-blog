export interface Post {
	id: number;
	slug: string;
	author_id: string;
	title: string;
	summary: string;
	content_markdown: string;
	tags: string[];
}

export interface PostsResponse {
	amount: number;
	posts: Post[];
}

export interface User {
	username: string;
	uuid: string;
	role: string;
}

export interface Login {
	username: string;
	password: string;
}

export interface Register {
	username: string;
	password: string;
	register_token: string;
}

const request = async <T = any>(
	endpoint: string,
	method: string,
	body?: any,
): Promise<T> => {
	const headers: HeadersInit = { "Content-Type": "application/json" };
	const res = await fetch(endpoint, {
		method,
		headers,
		credentials: "include",
		body: body ? JSON.stringify(body) : undefined,
	});

	const data = await res.json();
	if (!res.ok) throw new Error(data.message || "REST API error");
	return data as T;
};

export const blog_api = {
	register: (creds: Register) => request("/api/auth/register", "POST", creds),
	login: (creds: Login) => request("/api/auth/login", "POST", creds),
	logout: () => request("/api/auth/logout", "GET"),

	get_me: () => request<User>("/api/me", "GET"),

	get_posts: (amount?: string | number): Promise<PostsResponse> => {
		const url = amount !== undefined ? `/api/posts/${amount}` : "/api/posts";
		return request<PostsResponse>(url, "GET");
	},

	get_post: (id_or_slug: undefined | string): Promise<Post> => {
		if (id_or_slug === undefined) throw new Error("id_or_slug is undefined");
		return request<Post>(`/api/post/${id_or_slug}`, "GET");
	},
	create_post: (post: Post): Promise<Post> =>
		request<Post>("/api/post", "POST", post),
	update_post: (id_or_slug: string, post: Partial<Post>): Promise<Post> =>
		request<Post>(`/api/post/${id_or_slug}`, "PUT", post),
	delete_post: (id_or_slug: string): Promise<void> =>
		request<void>(`/api/post/${id_or_slug}`, "DELETE"),
};
