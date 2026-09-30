#!/usr/bin/env bash
# Rebuilds the seeded state from scratch.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose stop poller
docker compose up -d --force-recreate seed poller
docker compose logs --no-log-prefix seed
