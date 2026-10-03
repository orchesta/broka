#!/usr/bin/env bash
# Writes records through the registry: orders with version 1 and then version 2 of orders-value, and
# shipments under the record name strategy, so their subject is not shipments-value.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
SR="${SCHEMA_REGISTRY_URL:-http://schema-registry:8081}"

# avro <topic> <schema file> [extra --property ...]: reads JSON records from stdin
avro() {
  local topic=$1 schema=$2
  shift 2
  kafka-avro-console-producer --bootstrap-server "$BOOT" --topic "$topic" \
    --property schema.registry.url="$SR" \
    --property value.schema="$(cat "$schema")" \
    --property auto.register.schemas=false \
    "$@"
}

if kafka-avro-console-consumer --bootstrap-server "$BOOT" --topic shipments --from-beginning \
  --max-messages 1 --timeout-ms 15000 --property schema.registry.url="$SR" 2> /dev/null | grep -q carrier; then
  echo "records already written; nothing to produce"
  exit 0
fi

for i in $(seq 1001 1010); do
  printf '{"id":"o-%d","customerId":"c-%02d","amount":%d.50}\n' "$i" $((i % 20)) $((i % 90 + 10))
done | avro orders /schemas/orders-value-v1.avsc

for i in $(seq 1011 1020); do
  printf '{"id":"o-%d","customerId":"c-%02d","amount":%d.50,"channel":{"string":"web"},"promotionCode":null}\n' \
    "$i" $((i % 20)) $((i % 90 + 10))
done | avro orders /schemas/orders-value-v2.avsc

for i in $(seq 1 5); do
  printf '{"id":"s-%d","carrier":"dhl"}\n' "$i"
done | avro shipments /schemas/shipment-v1.avsc \
  --property value.subject.name.strategy=io.confluent.kafka.serializers.subject.RecordNameStrategy

echo "produced 20 orders and 5 shipments through the registry"
