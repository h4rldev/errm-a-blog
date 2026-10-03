# Errm... A blog?

A blog backend written in Erlang/OTP 28 on the "errm" stack, with a SvelteKit
frontend the backend serves as a static site. The whole thing ships as one
self-contained Docker image.

## What it does

The backend handles everything dynamic: cookie-based JWT auth, posts, comments,
guestbook, blocked-word filtering, notifications, and a WebSocket channel that
pushes live updates. The frontend is a prerendered SvelteKit app that talks to
the REST API under `/api` and the WebSocket at `/ws`.

Roles run `poster` < `administrator` < `super-administrator`, and `/admin/*`
needs administrator or above. Registration requires a `register_token`, which
is generated on boot and expires after 24 hours.

The frontend here is my personal one. The backend is the reusable part: you can
build your own frontend and drop it in, as long as it speaks the same API.

## Running

Build and run the image:

```sh
sudo docker build -t errm-a-blog .
sudo docker run -d --name errm-a-blog -p 8080:8080 -v errm-data:/app/data errm-a-blog
```

Then open <http://localhost:8080/>.

The first boot applies migrations and writes `blog.db`, `errm.env` and
`errm-config.json` into `/app/data`. Secrets are generated if absent and
persisted there, so keep the volume.

## Configuration

The container generates `errm-config.json` on first run: port, bind address, DB
path and log level. Secrets (`JWT_SECRET`, `COOKIE_SECRET`, register and
super-admin tokens) live in `errm.env`. Environment variables win over the file;
both are read from `/app/data` by default.

## Building multi-arch images

The image builds for `linux/amd64` and `linux/arm64`. The CI workflow in
[.github/workflows/build.yml](.github/workflows/build.yml) builds each
architecture on a native runner and merges them into one manifest, publishing to
the GitHub Container Registry.

## Development

A single Nix devShell (via `direnv` + `use flake`) provides the Erlang and
frontend tooling. Once in the shell:

```sh
rebar3 shell                         # backend
rebar3 as migrations escriptize      # build the migrator
cd frontend && deno task dev         # frontend dev server
```

Dependencies are the errm-* libraries, symlinked into `_checkouts/` by the
devShell.

## License

This project is licensed under the BSD 3-Clause License - see the
[LICENSE](LICENSE) file for details.
