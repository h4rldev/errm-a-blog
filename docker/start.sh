#!/bin/sh
set -e
cd /app
mkdir -p /app/data

if [ ! -f errm-config.json ]; then
  printf '%s' '{
  "port": 8080,
  "server_name": "errm-a-blog",
  "internal_log_level": "info",
  "db_path": "/app/data/blog.db",
  "ip_address": "0.0.0.0",
  "log_access": true
}' > errm-config.json
fi

./migrator migrate /app/data/blog.db

exec ./errm_a_blog
