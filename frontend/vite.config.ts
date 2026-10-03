import adapter from "@sveltejs/adapter-static";
import { sveltekit } from "@sveltejs/kit/vite";
import tailwindcss from "@tailwindcss/vite";
import { execSync } from "child_process";
import { defineConfig } from "vite";

const commitHash =
  process.env.GIT_COMMIT_HASH ||
  (() => {
    try {
      return execSync("git rev-parse --short HEAD").toString().trim();
    } catch {
      return "unknown";
    }
  })();
const repoUrl = "https://codeberg.org/h4rl/errm-A-blog";
const commitLink = `${repoUrl}/commit/${commitHash}`;
const commitTreeLink = `${repoUrl}/src/commit/${commitHash}`;

export default defineConfig({
  define: {
    __GIT_COMMIT_HASH__: JSON.stringify(commitHash),
    __COMMIT_URL__: JSON.stringify(commitLink),
    __REPO_URL__: JSON.stringify(commitTreeLink),
  },
  plugins: [
    tailwindcss(),
    sveltekit({
      compilerOptions: {
        runes: ({ filename }) =>
          filename.split(/[/\\]/).includes("node_modules") ? undefined : true,
      },
      alias: {
        $tailcss: "src/app.css",
        $components: "src/components",
      },
      adapter: adapter({
        pages: "build",
        assets: "build",
        fallback: "200.html",
        precompress: true,
        strict: true,
      }),
    }),
  ],
});
