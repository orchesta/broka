#!/bin/sh
# Creates the commerce vhost, its exchange and queues, and three application users with different permissions.
set -euo pipefail

API="${RABBITMQ_API:-http://rabbitmq:15672/api}"
AUTH="broka:${RABBITMQ_PASSWORD:?RABBITMQ_PASSWORD is not set}"
VHOST=commerce

# put <path> <JSON body>
put() {
  curl -sS -f -u "$AUTH" -H 'content-type: application/json' -X PUT "$API/$1" -d "$2" >/dev/null
}
# post <path> <JSON body>
post() {
  curl -sS -f -u "$AUTH" -H 'content-type: application/json' -X POST "$API/$1" -d "$2" >/dev/null
}

until curl -sf -u "$AUTH" "$API/overview" >/dev/null; do sleep 2; done

put "vhosts/$VHOST" '{"description":"Permission model lab"}'
put "permissions/$VHOST/broka" '{"configure":".*","write":".*","read":".*"}'

put "exchanges/$VHOST/orders.events" '{"type":"topic","durable":true}'
put "exchanges/$VHOST/payments.events" '{"type":"topic","durable":true}'
put "queues/$VHOST/orders.eu" '{"durable":true}'
put "queues/$VHOST/payments.settled" '{"durable":true}'
post "bindings/$VHOST/e/orders.events/q/orders.eu" '{"routing_key":"order.eu.#"}'
post "bindings/$VHOST/e/payments.events/q/payments.settled" '{"routing_key":"payment.settled"}'

put users/svc-payments "{\"password\":\"$PAYMENTS_PASSWORD\",\"tags\":\"\"}"
put users/svc-orders "{\"password\":\"$ORDERS_PASSWORD\",\"tags\":\"\"}"
put users/svc-denied "{\"password\":\"$DENIED_PASSWORD\",\"tags\":\"\"}"

put "permissions/$VHOST/svc-payments" '{"configure":".*","write":".*","read":".*"}'
put "permissions/$VHOST/svc-orders" '{"configure":"^orders\\.","write":"^orders\\.","read":"^orders\\."}'
put "permissions/$VHOST/svc-denied" '{"configure":"","write":"","read":""}'
put "topic-permissions/$VHOST/svc-orders" '{"exchange":"orders.events","write":"^order\\.eu\\.","read":"^order\\.eu\\."}'

echo "seeded vhost $VHOST: users svc-payments, svc-orders, svc-denied"
