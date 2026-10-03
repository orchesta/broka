#!/usr/bin/env bash
# Produces RATE keyed page views per second to clickstream.raw until stopped.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka-1:29092,kafka-2:29092,kafka-3:29092}"
RATE="${RATE:-40}"
pages=(/ /catalog /catalog/lanterns /product/SKU-10007 /cart /checkout /account /search)

generate() {
  while true; do
    now=$(date +%s)
    for ((i = 0; i < RATE; i++)); do
      s="sess-$((RANDOM % 9000 + 1000))"
      printf '%s|{"session":"%s","page":"%s","ts":%s000}\n' "$s" "$s" "${pages[$((RANDOM % ${#pages[@]}))]}" "$now"
    done
    sleep 1
  done
}

generate | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server "$BOOT" --topic clickstream.raw \
  --property parse.key=true --property key.separator='|' --producer-property linger.ms=5
