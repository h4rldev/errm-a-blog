import { browser } from "$app/environment";
import { goto } from "$app/navigation";
import type { Post, User } from "./blog_api";
import { blog_api } from "./blog_api";

let user = $state<User | null>(null);
let loading = $state<boolean>(true);

export const blog = {
	get user() {
		return user;
	},
	get is_logged_in() {
		return !!user;
	},
	get loading() {
		return loading;
	},

	async check() {
		if (!browser) return;
		loading = true;

		try {
			const data = await blog_api.get_me();
			user = data;
		} catch (e) {
			console.error(e || "Failed to get user");
			user = null;
		} finally {
			loading = false;
		}
	},

	async login(username: string, password: string) {
		await blog_api.login({ username, password });
		await this.check();
	},

	async logout() {
		await blog_api.logout();
		user = null;
		goto("/login");
	},
};
