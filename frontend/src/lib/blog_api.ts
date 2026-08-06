const is_dev = import.meta.env.DEV;
const is_prod = import.meta.env.PROD;

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

export interface PostGuestbookEntry {
  username: string | "anonymous";
  content_markdown: string;
}

export interface GuestbookEntry extends PostGuestbookEntry {
  id: number;
  posted_at: number;
  edited_at: number | null;
}

export type PostComment = PostGuestbookEntry;
export type Comment = GuestbookEntry;

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

export interface Stats {
  total_posts: number;
  total_comments: number;
  total_guestbook_entries: number;
}

export interface RegisterToken {
  token: string;
}

export interface RotateRegisterToken {
  message: string;
  token: string;
}


const convert_unix_timestamp_to_date = (number: number): string => {
	const date = new Date(number * 1000);
	const now = new Date();

	const same_day =
		date.getFullYear() === now.getFullYear() &&
		date.getMonth() === now.getMonth() &&
		date.getDate() === now.getDate();

	if (same_day) return date.toLocaleTimeString();

	const time = date.toLocaleTimeString();
	const day = date.toLocaleDateString();
	return `${day} ${time}`;
};

const request = async <T = any>(
	endpoint: string,
	method: string,
	body?: any,
): Promise<T> => {
	const headers: HeadersInit = { "Content-Type": "application/json" };

	const url = is_dev
		? "http://localhost:8080"
		: is_prod
			? ""
			: "http://localhost:8080";
	const full_url = url + endpoint;

	const res = await fetch(full_url, {
		method,
		headers,
		credentials: "include",
		body: body ? JSON.stringify(body) : undefined,
	});

	let data = null;
	if (res.status !== 204) data = await res.json();
	if (!res.ok) throw new Error(data.error || "REST API error");
	if (data !== null) return data as T;
	return;
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

  create_guestbook_entry: (entry: PostGuestbookEntry): Promise<void> =>
    request<void>("/api/guestbook", "POST", entry),
  edit_guestbook_entry: (id: number, entry: GuestbookEntry): Promise<void> =>
    request<void>(`/api/guestbook/${id}`, "PUT", entry),
  delete_guestbook_entry: (id: number): Promise<void> =>
    request<void>(`/api/guestbook/${id}`, "DELETE"),

  create_comment: (comment: Comment, post_id: number): Promise<void> =>
    request<void>(`/api/post/${post_id}/comments`, "POST", comment),
  edit_comment: (id: number, comment: Comment): Promise<void> =>
    request<void>(`/api/post/comment/${id}`, "PUT", comment),
  delete_comment: (id: number): Promise<void> =>
    request<void>(`/api/post/comment/${id}`, "DELETE"),

  get_admin_stats: () => 
    request<Stats>("/api/admin/stats", "GET"),
  get_register_token: () => 
    request<RegisterToken>("/api/admin/register_token", "GET"),
  admin_secret_rotate: (secret: string) => {
    switch (secret) {
      case "register_token":
        return request<RotateRegisterToken>("/api/admin/rotate/register_token", "POST");
      default:
        return request<void>(`/api/admin/rotate/${secret}`, "POST");
    }
  },

  sleep: (ms: number) =>
    new Promise((resolve) => setTimeout(resolve, ms)),

	convert_unix_timestamp_to_date,
};
