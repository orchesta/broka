#!/usr/bin/env bash
# Produces RATE finished rides per second to rides.completed until stopped.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
RATE="${RATE:-10}"

generate() {
  while true; do
    for ((i = 0; i < RATE; i++)); do
      bike="bike-$((RANDOM % 1000 + 1000))"
      printf '%s|{"bike":"%s","from":"station-%02d","to":"station-%02d","minutes":%d}\n' \
        "$bike" "$bike" $((RANDOM % 12 + 1)) $((RANDOM % 12 + 1)) $((RANDOM % 55 + 4))
    done
    sleep 1
  done
}

generate | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server "$BOOT" --topic rides.completed \
  --reader-property parse.key=true --reader-property key.separator='|' --command-property linger.ms=5
