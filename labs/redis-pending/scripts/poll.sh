#!/bin/sh
# A healthy consumer in fulfilment: reads, acknowledges, and keeps asking once the stream is quiet.
set -euo pipefail

STREAM=broka:orders
R() { redis-cli -h "${REDIS_HOST:-redis}" -p "${REDIS_PORT:-6379}" "$@"; }

while true; do
  ids=$(R XREADGROUP GROUP fulfilment picker-3 COUNT 1 BLOCK 5000 STREAMS "$STREAM" '>' \
    | grep -E '^[0-9]+-[0-9]+$' || true)
  [ -z "$ids" ] || R XACK "$STREAM" fulfilment $ids >/dev/null
  sleep 1
done
