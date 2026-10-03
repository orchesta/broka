#!/bin/sh
# Imports the vhost, its queues and user policies, then adds the operator policy, which definitions do not carry.
set -euo pipefail

API="${RABBITMQ_API:-http://rabbitmq:15672/api}"
AUTH="broka:${RABBITMQ_PASSWORD:?RABBITMQ_PASSWORD is not set}"
VHOST=shop

api() {
  method=$1; path=$2; shift 2
  curl -sS -f -u "$AUTH" -H 'content-type: application/json' -X "$method" "$API/$path" "$@"
}

until curl -sf -u "$AUTH" "$API/overview" > /dev/null; do sleep 2; done

echo "importing definitions"
api POST definitions -d @/definitions.json
echo

echo "operator policy ttl-ceiling"
api PUT "operator-policies/$VHOST/ttl-ceiling" \
  -d '{"pattern":"^orders\\.processing$","apply-to":"queues","priority":0,"definition":{"message-ttl":600000}}'

# The broker applies a policy change to its queues a few seconds later; wait until both layers show.
for _ in $(seq 1 30); do
  api GET "queues/$VHOST/orders.processing" | grep -q '"operator_policy":"ttl-ceiling"' &&
    api GET "queues/$VHOST/orders.audit" | grep -q '"policy":"audit-retention"' && break
  sleep 1
done
echo "policy in force, per queue:"
api GET "queues/$VHOST?columns=name,type,policy,operator_policy" | tr '{' '\n' | tr -d '}"[]' | sed '/^$/d'
echo
echo "seed complete"
