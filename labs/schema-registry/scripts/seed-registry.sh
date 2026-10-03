#!/bin/sh
# Registers the subjects and versions, sets the compatibility levels and soft-deletes one subject.
set -euo pipefail

SR="${SCHEMA_REGISTRY_URL:-http://schema-registry:8081}"
DIR=/schemas
CT='content-type: application/vnd.schemaregistry.v1+json'

until curl -sf "$SR/subjects" > /dev/null; do sleep 2; done

if curl -sf "$SR/subjects?deleted=true" | grep -q '"orders-value"'; then
  echo "subjects already registered; nothing to seed"
  exit 0
fi

# escaped <file>: the file's content as the inside of a JSON string
escaped() { sed 's/\\/\\\\/g; s/"/\\"/g' "$1" | tr '\n\t' '  '; }

# register <subject> <file> [schema type] [references JSON]
register() {
  type=""
  [ -z "${3:-}" ] || type=",\"schemaType\":\"$3\""
  refs=""
  [ -z "${4:-}" ] || refs=",\"references\":$4"
  printf '  %s: ' "$1"
  curl -sS -f -H "$CT" -X POST "$SR/subjects/$1/versions" \
    -d "{\"schema\":\"$(escaped "$2")\"$type$refs}"
  echo
}

# level <subject or empty for the registry> <level>
level() {
  path=config
  [ -z "$1" ] || path="config/$1"
  curl -sS -f -H "$CT" -X PUT "$SR/$path" -d "{\"compatibility\":\"$2\"}" > /dev/null
}

level "" BACKWARD

echo "registering"
register orders-key "$DIR/orders-key-v1.avsc"
register orders-value "$DIR/orders-value-v1.avsc"
register orders-value "$DIR/orders-value-v2.avsc"
register payments-value "$DIR/payments-value-v1.avsc"
register payments-value "$DIR/payments-value-v2.avsc"
register payments-value "$DIR/payments-value-v3.avsc"
register customers-value "$DIR/customers-value-v1.json" JSON
level customers-value FULL
register com.example.common.Money "$DIR/money-v1.avsc"
register invoices-value "$DIR/invoices-value-v1.avsc" "" \
  '[{"name":"com.example.common.Money","subject":"com.example.common.Money","version":1}]'
register com.example.shipping.Shipment "$DIR/shipment-v1.avsc"
register orders-legacy-value "$DIR/orders-legacy-value-v1.avsc"

echo "soft-deleting orders-legacy-value"
curl -sS -f -X DELETE "$SR/subjects/orders-legacy-value" > /dev/null

echo "subjects: $(curl -sS -f "$SR/subjects")"
echo "seed complete"
