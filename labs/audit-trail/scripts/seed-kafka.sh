#!/usr/bin/env bash
# Creates a topic with a stopped consumer group 400 records behind, and a scratch topic to delete.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
BIN=/opt/kafka/bin

until "$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --list > /dev/null 2>&1; do sleep 2; done

"$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create --if-not-exists --topic orders.v2 --partitions 3 --replication-factor 1
"$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create --if-not-exists --topic scratch.tmp --partitions 1 --replication-factor 1

if "$BIN/kafka-consumer-groups.sh" --bootstrap-server "$BOOT" --list | grep -qx order-service; then
  echo "order-service already exists; nothing to seed"
  exit 0
fi

orders() {
  seq "$1" "$2" | awk '{ printf "order-%d|{\"orderId\":\"order-%d\",\"status\":\"created\"}\n", $1, $1 }' |
    "$BIN/kafka-console-producer.sh" --bootstrap-server "$BOOT" --topic orders.v2 \
      --property parse.key=true --property key.separator='|'
}
orders 1 200
"$BIN/kafka-consumer-groups.sh" --bootstrap-server "$BOOT" --group order-service \
  --topic orders.v2 --reset-offsets --to-latest --execute > /dev/null
orders 201 600

echo "seeded: orders.v2 with order-service 400 records behind, scratch.tmp"
