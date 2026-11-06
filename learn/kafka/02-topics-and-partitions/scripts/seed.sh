#!/usr/bin/env bash
# Creates the two topics and writes the data the lab starts with.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
BIN=/opt/kafka/bin

until "$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --list > /dev/null 2>&1; do sleep 2; done

if "$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --list | grep -qx bikes.telemetry; then
  echo "bikes.telemetry already exists; nothing to seed"
  exit 0
fi

"$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create \
  --topic rides.completed --partitions 6 --replication-factor 1
# Small segments, so that the log of one partition is several files rather than one.
"$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create \
  --topic bikes.telemetry --partitions 2 --replication-factor 1 --config segment.bytes=1048576

produce() {
  "$BIN/kafka-console-producer.sh" --bootstrap-server "$BOOT" --topic "$1" \
    --reader-property parse.key=true --reader-property key.separator='|'
}

# Three past rides for every bike. The key is the bike, so a bike's rides all land on one partition.
rides() {
  seq 1 3000 | awk '{ bike = 1000 + ($1 % 1000); printf "bike-%d|{\"bike\":\"bike-%d\",\"from\":\"station-%02d\",\"to\":\"station-%02d\",\"minutes\":%d}\n", bike, bike, ($1 * 7) % 12 + 1, ($1 * 11) % 12 + 1, ($1 * 13) % 55 + 4 }'
}

# Forty positions for every bike, about four megabytes in all: enough to fill several segments.
telemetry() {
  seq 1 40000 | awk '{ bike = 1000 + ($1 % 1000); printf "bike-%d|{\"bike\":\"bike-%d\",\"lat\":%.5f,\"lon\":%.5f,\"battery\":%d,\"seq\":%d}\n", bike, bike, 52.50 + ($1 % 97) / 1000.0, 13.40 + ($1 % 89) / 1000.0, 100 - ($1 % 100), $1 }'
}

rides | produce rides.completed
telemetry | produce bikes.telemetry

echo "seeded: rides.completed (6 partitions, 3000 rides), bikes.telemetry (2 partitions, 40000 positions, 1 MB segments)"
