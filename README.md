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
mkdir -p data
sudo docker build -t errm-a-blog .
sudo docker run -d --name errm-a-blog -p 8080:8080 -v "$PWD/data:/app/data" errm-a-blog
```

Then open <http://localhost:8080/>. Or `sudo docker compose up`, which bind-mounts
`./data` the same way.

The first boot applies migrations and writes `blog.db`, `errm.env`,
`errm-config.json` and (when `access_log_file` is set) `access.log` into
`/app/data` — the host directory you mounted, so you can edit and grep them
directly. Secrets are generated if absent and persisted there, so keep the
directory.

The mount directory must be writable by uid 1000 (the image's `app` user):
create it as your user, or `sudo chown -R 1000:1000 data`.

## Configuration

The container generates `errm-config.json` on first run: port, bind address, DB
path, log level, and access logging. `log_access` turns request logging on or
off; `access_log_file` is its destination (e.g. `/app/data/access.log`), empty
logs to the container console. Secrets (`JWT_SECRET`, `COOKIE_SECRET`, register
and super-admin tokens) live in `errm.env`. Environment variables win over the
file; both are read from `/app/data` by default.

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
