#!/bin/sh
set -euo pipefail
. /scripts/common.sh

echo "publishing every ${LOAD_INTERVAL:-1}s"
while :; do
  publish orders order.created '{\"id\":1}' >/dev/null
  publish orders order.shipped '{\"id\":2}' >/dev/null
  publish orders orders.created '{\"id\":3}' >/dev/null
  publish invoices invoice.paid '{\"id\":4}' >/dev/null
  sleep "${LOAD_INTERVAL:-1}"
done
