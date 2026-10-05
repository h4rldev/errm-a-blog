const is_prod = import.meta.env.PROD;
const base_url = is_prod ? "" : "http://localhost:8080";
export const ws_url = is_prod ? "/ws" : "http://localhost:8080/ws";

export interface PostPost {
  slug: string;
  title: string;
  summary: string;
  content_markdown: string;
  tags: string[];
}

export interface Author {
  uuid: string;
  username: string;
  role: string;
}

export interface Post extends PostPost {
  id: number;
  author: Author;
  posted_at: number;
  edited_at: number | null;
}

export interface AdminNotification {
  id: number;
  kind: string;
  action: string;
  username: string | null;
  content: string | null;
  ref_id: string | null;
  target: string | null;
  created_at: number;
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

export interface UsersResponse {
  users: User[];
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

export interface BlockedWords {
  scope?: string;
  keywords: string[];
  patterns: string[];
  enforced_by?: string;
  updated_at?: number;
}

export interface EditUser {
  uuid: string;
  username?: string;
  role?: string;
  password?: string;
}

export interface RegisterToken {
  token: string;
}

export interface RotateRegisterToken {
  message: string;
  token: string;
}

export const normalize_entry = (e: any): GuestbookEntry => ({
  id: Number(e.id),
  username: e.username,
  content_markdown: e.content_markdown,
  posted_at: Number(e.posted_at),
  edited_at: e.edited_at == null ? null : Number(e.edited_at),
});

const convert_unix_timestamp_to_date = (number: number): string => {
  const date = new Date(number * 1000);
  const now = new Date();
  const time_opts: Intl.DateTimeFormatOptions = { hour12: false };

  const same_day =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();

  if (same_day) return date.toLocaleTimeString([], time_opts);

  const time = date.toLocaleTimeString([], time_opts);
  const day = date.toLocaleDateString();
  return `${day} ${time}`;
};

const request = async <T = any>(
  endpoint: string,
  method: string,
  body?: any,
): Promise<T> => {
  const headers: HeadersInit = { "Content-Type": "application/json" };
  const full_url = base_url + endpoint;

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
  return null as T;
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
  create_post: (post: PostPost): Promise<Post> =>
    request<Post>("/api/post", "POST", post),
  update_post: (id_or_slug: string, post: Partial<PostPost>): Promise<Post> =>
    request<Post>(`/api/post/${id_or_slug}`, "PUT", post),
  delete_post: (id_or_slug: string): Promise<void> =>
    request<void>(`/api/post/${id_or_slug}`, "DELETE"),

  create_guestbook_entry: (entry: PostGuestbookEntry): Promise<void> =>
    request<void>("/api/guestbook", "POST", entry),
  edit_guestbook_entry: (
    id: number,
    entry: PostGuestbookEntry,
  ): Promise<void> => request<void>(`/api/guestbook/${id}`, "PUT", entry),
  delete_guestbook_entry: (
    id: number,
    entry: PostGuestbookEntry,
  ): Promise<void> => request<void>(`/api/guestbook/${id}`, "DELETE", entry),

  create_comment: (comment: PostComment, post_id: number): Promise<void> =>
    request<void>(`/api/post/${post_id}/comments`, "POST", comment),
  edit_comment: (
    post_id: number,
    comment_id: number,
    comment: PostComment,
  ): Promise<void> =>
    request<void>(
      `/api/post/${post_id}/comments/${comment_id}`,
      "PUT",
      comment,
    ),
  delete_comment: (
    post_id: number,
    comment_id: number,
    comment: PostComment,
  ): Promise<void> =>
    request<void>(
      `/api/post/${post_id}/comments/${comment_id}`,
      "DELETE",
      comment,
    ),

  admin_get_stats: () => request<Stats>("/api/admin/stats", "GET"),
  admin_get_register_token: () =>
    request<RegisterToken>("/api/admin/register_token", "GET"),
  admin_secret_rotate: (secret: string): Promise<RotateRegisterToken> =>
    request<RotateRegisterToken>(`/api/admin/rotate/${secret}`, "POST"),
  admin_get_users: () => request<UsersResponse>("/api/admin/users", "GET"),
  admin_edit_user: (user: EditUser): Promise<void> =>
    request<void>(`/api/admin/edit_user`, "PATCH", user),

  admin_get_notifications: (): Promise<{
    notifications: AdminNotification[];
  }> =>
    request<{ notifications: AdminNotification[] }>(
      "/api/admin/notifications",
      "GET",
    ),
  admin_clear_notifications: (): Promise<void> =>
    request<void>("/api/admin/notifications", "DELETE"),

  admin_get_blocked_words: (
    scope: string,
  ): Promise<{ blocked_words?: BlockedWords[] }> =>
    request(`/api/admin/blocked_words/${scope}`, "GET"),
  admin_save_blocked_words: (
    scope: string,
    words: { keywords: string[]; patterns: string[]; enforced_by: string },
  ): Promise<{ message?: string }> =>
    request(`/api/admin/blocked_words/${scope}`, "PUT", words),

  convert_unix_timestamp_to_date,
  get_tags: (): Promise<{ tags: string[] }> => request("/api/tags", "GET"),
};
