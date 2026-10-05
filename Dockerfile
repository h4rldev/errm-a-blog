# syntax=docker/dockerfile:1

FROM alpine:3.22 AS erlbuild-base
ARG TARGETARCH
ENV ERL_ROOT=/usr/lib/erlang

RUN --mount=type=secret,id=gh_token,env=GITHUB_TOKEN,required=false set -eu; \
  case "$TARGETARCH" in arm64) A=aarch64 ;; *) A=x86_64 ;; esac; \
  apk add --no-cache erlang28 erlang28-dev git bash curl gcc musl-dev make pkgconf file-dev sqlite-dev argon2-dev brotli-dev jq; \
  curl -fsSL --retry 8 --retry-all-errors --retry-delay 3 -o /usr/local/bin/rebar3 https://s3.amazonaws.com/rebar3/rebar3 \
  && chmod +x /usr/local/bin/rebar3; \
  ASSET_URL=$(curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN:-}" "https://api.github.com/repos/casey/just/releases/tags/1.58.0" | jq -r --arg a "$A" '.assets[] | select(.name | test("^just-1\\.58\\.0-" + $a + "-unknown-linux-musl\\.tar\\.gz$")) | .url' | head -n1); \
  curl -fsSL --retry 8 --retry-all-errors --retry-delay 3 \
    --resolve release-assets.githubusercontent.com:443:185.199.111.133 \
    -H "Authorization: Bearer ${GITHUB_TOKEN:-}" -H "Accept: application/octet-stream" \
    -o /tmp/just.tar.gz "$ASSET_URL" \
  && tar -xzf /tmp/just.tar.gz -C /usr/local/bin just \
  && rm /tmp/just.tar.gz
WORKDIR /build
COPY rebar.config rebar.lock ./

FROM erlbuild-base AS migbuild
ENV REBAR_PROFILE=migrations
COPY migrator ./migrator
COPY migrations ./migrations
RUN DIAGNOSTIC=1 rebar3 as migrations escriptize

FROM erlbuild-base AS prod
ENV REBAR_PROFILE=prod
COPY src ./src
COPY errm_a_blog ./errm_a_blog
COPY blog_test ./blog_test
RUN DIAGNOSTIC=1 rebar3 as prod escriptize

FROM denoland/deno:debian-2.9.7 AS febuild
ARG GIT_COMMIT_HASH=unknown
ENV GIT_COMMIT_HASH=$GIT_COMMIT_HASH
WORKDIR /build
COPY frontend ./
RUN deno install --allow-scripts
RUN deno run -A npm:vite build

FROM alpine:3.22 AS runtime
RUN apk add --no-cache \
      erlang28 sqlite-libs argon2-libs brotli ncurses-libs file \
      ca-certificates tini \
 && adduser -D -u 1000 -s /bin/sh app
WORKDIR /app
COPY --from=prod /build/_build/prod/bin/errm_a_blog ./errm_a_blog
COPY --from=migbuild /build/_build/migrations/bin/migrator ./migrator
COPY --from=migbuild /build/migrations ./migrations
COPY --from=febuild /build/build ./site-root
COPY docker/start.sh ./start.sh
RUN chmod +x ./errm_a_blog ./migrator ./start.sh \
 && mkdir -p /app/data && chown -R app:app /app
USER app
ENV HOME=/app
VOLUME ["/app/data"]
EXPOSE 8080
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/start.sh"]
