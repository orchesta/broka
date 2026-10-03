#!/bin/sh
# Registers a few subjects, so the registry is there to be found once it is registered in BROKA.
set -euo pipefail

SR="${SCHEMA_REGISTRY_URL:-http://schema-registry:8081}"
CT='content-type: application/vnd.schemaregistry.v1+json'

until curl -sf "$SR/subjects" > /dev/null; do sleep 2; done

# register <subject> <schema JSON, escaped for a JSON string> [schema type]
register() {
  type=""
  [ -z "${3:-}" ] || type=",\"schemaType\":\"$3\""
  curl -sS -f -H "$CT" -X POST "$SR/subjects/$1/versions" -d "{\"schema\":\"$2\"$type}" > /dev/null
}

curl -sS -f -H "$CT" -X PUT "$SR/config" -d '{"compatibility":"BACKWARD"}' > /dev/null
register orders-value '{\"type\":\"record\",\"name\":\"Order\",\"namespace\":\"com.example\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"}]}'
register orders-value '{\"type\":\"record\",\"name\":\"Order\",\"namespace\":\"com.example\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"},{\"name\":\"note\",\"type\":[\"null\",\"string\"],\"default\":null}]}'
register payments.ledger-value '{\"type\":\"record\",\"name\":\"Entry\",\"namespace\":\"com.example\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"},{\"name\":\"amount\",\"type\":\"double\"}]}'
register checkout.events-value '{\"type\":\"object\",\"properties\":{\"cartId\":{\"type\":\"string\"}}}' JSON

echo "subjects: $(curl -sS -f "$SR/subjects")"
