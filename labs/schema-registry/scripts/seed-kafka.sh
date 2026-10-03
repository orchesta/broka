#!/usr/bin/env bash
# Creates the topics and writes three records to orders that a producer sent without the registry.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
BIN=/opt/kafka/bin

until "$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --list > /dev/null 2>&1; do sleep 2; done

for topic in orders payments customers invoices shipments; do
  "$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" --create --if-not-exists \
    --topic "$topic" --partitions 3 --replication-factor 1
done

if [ "$("$BIN/kafka-get-offsets.sh" --bootstrap-server "$BOOT" --topic orders | awk -F: '{ s += $3 } END { print s + 0 }')" = 0 ]; then
  printf '%s\n' \
    '{"id":"o-0997","customerId":"c-03","amount":12.5}' \
    '{"id":"o-0998","customerId":"c-11","amount":80.0}' \
    '{"id":"o-0999","customerId":"c-03","amount":7.25}' |
    "$BIN/kafka-console-producer.sh" --bootstrap-server "$BOOT" --topic orders
fi
echo "topics ready"
