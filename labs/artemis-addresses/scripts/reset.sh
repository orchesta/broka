#!/usr/bin/env bash
# Returns every queue to its seeded state: stops the consumers, seeds again, schedules again, restarts them.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose stop dispatch-worker returns-worker
docker compose run --rm seed
docker compose run --rm schedule
docker compose start dispatch-worker returns-worker
