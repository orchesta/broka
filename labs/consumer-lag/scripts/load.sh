#!/usr/bin/env bash
# Produces RATE keyed page views per second to clickstream.raw until stopped.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
RATE="${RATE:-40}"
pages=(/ /catalog /catalog/lanterns /product/SKU-10007 /product/SKU-10021 /cart /checkout /account /search)

generate() {
  while true; do
    now=$(date +%s)
    for ((i = 0; i < RATE; i++)); do
      s="sess-$((RANDOM % 9000 + 1000))"
      p="${pages[$((RANDOM % ${#pages[@]}))]}"
      printf '%s|{"session":"%s","page":"%s","ts":%s000}\n' "$s" "$s" "$p" "$now"
    done
    sleep 1
  done
}

generate | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server "$BOOT" --topic clickstream.raw \
  --property parse.key=true --property key.separator='|' --producer-property linger.ms=5
