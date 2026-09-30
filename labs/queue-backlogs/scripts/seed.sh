#!/bin/sh
set -euo pipefail

API="${RABBITMQ_API:-http://rabbitmq:15672/api}"
AUTH="broka:${RABBITMQ_PASSWORD:?RABBITMQ_PASSWORD is not set}"
VHOST=shop

api() {
  method=$1; path=$2; shift 2
  curl -sS -f -u "$AUTH" -H 'content-type: application/json' -X "$method" "$API/$path" "$@"
}

until curl -sf -u "$AUTH" "$API/overview" >/dev/null; do sleep 2; done

echo "importing definitions"
api POST definitions -d @/definitions.json
echo

for q in orders.audit orders.audit.overflow orders.dlq payments.charge payments.dlq; do
  api DELETE "queues/$VHOST/$q/contents" >/dev/null
done

echo "publishing 12 charges to payments"
i=1
while [ "$i" -le 12 ]; do
  api POST "exchanges/$VHOST/payments/publish" >/dev/null -d "{\"properties\":{\"content_type\":\"application/json\",\"delivery_mode\":2},\"routing_key\":\"payment.charge\",\"payload\":\"{\\\"paymentId\\\":$i,\\\"amount\\\":$((i * 13))}\",\"payload_encoding\":\"string\"}"
  i=$((i + 1))
done

# Rejected without requeue, so the queue's own dead-letter target decides where they go.
echo "rejecting 7 of them"
api POST "queues/$VHOST/payments.charge/get" >/dev/null \
  -d '{"count":7,"ackmode":"reject_requeue_false","encoding":"auto"}'

echo "seed complete"
