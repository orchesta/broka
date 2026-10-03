#!/usr/bin/env bash
# Restarts both nodes empty and seeds them again. Memcached keeps nothing across a restart.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose stop load
docker compose up -d --force-recreate --wait cache-a cache-b
docker compose up -d --force-recreate seed load
docker compose logs --no-log-prefix -f seed
