#!/usr/bin/env bash
# Stops the load and moves analytics-loader to the end of clickstream.raw.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose stop producer loader-1 loader-2

docker compose exec -T kafka bash -c '
  groups() { /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 --group analytics-loader "$@"; }
  for _ in $(seq 1 30); do
    groups --describe --state 2> /dev/null | grep -qw Empty && break
    sleep 2
  done
  groups --topic clickstream.raw --reset-offsets --to-latest --execute
'
