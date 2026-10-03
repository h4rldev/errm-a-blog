import { blog_api } from "$lib/blog_api";

let tags = $state<string[]>([]);

const fetch_tags = async () => {
  const data = await blog_api.get_tags();
  tags = data.tags || [];
};

export const tags_store = {
  get tags() {
    return tags;
  },
  fetch_tags,
};
