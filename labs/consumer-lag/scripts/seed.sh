#!/usr/bin/env bash
# Creates the topics and leaves order-service stopped with committed offsets and a backlog.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
BIN=/opt/kafka/bin

until "$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --list > /dev/null 2>&1; do sleep 2; done

"$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create --if-not-exists \
  --topic clickstream.raw --partitions 12 --replication-factor 1
"$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create --if-not-exists \
  --topic orders.v2 --partitions 6 --replication-factor 1

if "$BIN/kafka-consumer-groups.sh" --bootstrap-server "$BOOT" --list | grep -qx order-service; then
  echo "order-service already exists; nothing to seed"
  exit 0
fi

orders() {
  seq "$1" "$2" | awk '{ printf "order-%d|{\"orderId\":\"order-%d\",\"status\":\"created\",\"amount\":%d.%02d}\n", $1, $1, ($1 * 37) % 500, $1 % 100 }'
}
produce() {
  "$BIN/kafka-console-producer.sh" --bootstrap-server "$BOOT" --topic orders.v2 \
    --property parse.key=true --property key.separator='|'
}

orders 1 1000 | produce
"$BIN/kafka-consumer-groups.sh" --bootstrap-server "$BOOT" --group order-service \
  --topic orders.v2 --reset-offsets --to-latest --execute
orders 1001 5000 | produce

echo "seeded: clickstream.raw (12 partitions), orders.v2 (6 partitions), order-service stopped with 4000 records of lag"
