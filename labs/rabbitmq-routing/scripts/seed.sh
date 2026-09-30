#!/bin/sh
set -euo pipefail
. /scripts/common.sh

until curl -sf -u "$AUTH" "$API/overview" >/dev/null; do sleep 2; done

echo "importing definitions"
curl -sS -f -u "$AUTH" -H "content-type: application/json" -X POST "$API/definitions" -d @/definitions.json
echo

for q in orders.processing orders.audit orders.audit.archive orders.unrouted orders.dlq shipments.express; do
  curl -sS -f -u "$AUTH" -X DELETE "$API/queues/$VHOST/$q/contents" >/dev/null
done

send() {
  n=$1; shift
  i=1
  while [ "$i" -le "$n" ]; do
    publish "$@" >/dev/null
    i=$((i + 1))
  done
  echo "  $n to $1 ${2:+key $2}${4:+headers $4}"
}

echo "publishing"
send 30 orders order.created '{\"id\":1}'
send 10 orders order.shipped '{\"id\":2}'
send 5 orders orders.created '{\"id\":3}'
send 5 invoices invoice.paid '{\"id\":4}'
send 5 shipments '' '{\"id\":5}' '{"region":"eu","priority":3}'
send 2 shipments '' '{\"id\":6}' '{"region":"us","priority":3}'

echo "seed complete"
