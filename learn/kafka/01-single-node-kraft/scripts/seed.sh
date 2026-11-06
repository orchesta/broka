#!/usr/bin/env bash
# Creates the topics, writes the history the lab starts with, and positions ride-billing at its end.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
BIN=/opt/kafka/bin

until "$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --list > /dev/null 2>&1; do sleep 2; done

"$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create --if-not-exists \
  --topic rides.completed --partitions 6 --replication-factor 1
"$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create --if-not-exists \
  --topic stations.status --partitions 3 --replication-factor 1 --config cleanup.policy=compact

if "$BIN/kafka-consumer-groups.sh" --bootstrap-server "$BOOT" --list | grep -qx ride-billing; then
  echo "ride-billing already exists; nothing to seed"
  exit 0
fi

produce() {
  "$BIN/kafka-console-producer.sh" --bootstrap-server "$BOOT" --topic "$1" \
    --reader-property parse.key=true --reader-property key.separator='|'
}

# Twenty updates for each of the twelve stations: the compacted topic holds more records than keys.
stations() {
  for round in $(seq 1 20); do
    for station in $(seq -w 1 12); do
      bikes=$(( (round * 7 + 10#$station * 3) % 16 ))
      printf 'station-%s|{"station":"station-%s","bikesAvailable":%d,"docksFree":%d}\n' \
        "$station" "$station" "$bikes" $(( 16 - bikes ))
    done
  done
}

# Three past rides for every bike. The key is the bike, so a bike's rides all land on one partition.
rides() {
  seq "$1" "$2" | awk '{ bike = 1000 + ($1 % 1000); printf "bike-%d|{\"bike\":\"bike-%d\",\"from\":\"station-%02d\",\"to\":\"station-%02d\",\"minutes\":%d}\n", bike, bike, ($1 * 7) % 12 + 1, ($1 * 11) % 12 + 1, ($1 * 13) % 55 + 4 }'
}

stations | produce stations.status
rides 1 3000 | produce rides.completed

"$BIN/kafka-consumer-groups.sh" --bootstrap-server "$BOOT" --group ride-billing \
  --topic rides.completed --reset-offsets --to-latest --execute

echo "seeded: stations.status (3 partitions, compacted, 240 updates), rides.completed (6 partitions, 3000 rides), ride-billing positioned at the end"
