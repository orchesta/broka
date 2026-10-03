#!/bin/sh
# Sends five payments to payments.settlement over STOMP, each scheduled for delivery one to five days from now.
# STOMP 1.2 escapes a colon in a header value as \c, so payments::payments.settlement is written escaped.
set -eu

HOST="${STOMP_HOST:-artemis}"
PORT="${STOMP_PORT:-61613}"
reply=/tmp/stomp-reply

{
  printf 'CONNECT\naccept-version:1.2\nhost:%s\nlogin:%s\npasscode:%s\n\n\000' "$HOST" "$ARTEMIS_USER" "$ARTEMIS_PASSWORD"
  for day in 1 2 3 4 5; do
    id="P-$((2000 + day))"
    printf 'SEND\ndestination:payments\\c\\cpayments.settlement\ndestination-type:ANYCAST\n'
    printf 'persistent:true\ncontent-type:application/json\n'
    printf 'AMQ_SCHEDULED_DELAY:%s\npaymentId:%s\n\n' "$((day * 86400000))" "$id"
    printf '{"paymentId":"%s","amount":%s.00}\000' "$id" "$((day * 120))"
  done
  printf 'DISCONNECT\nreceipt:sent\n\n\000'
  sleep 5
} | nc "$HOST" "$PORT" | tr '\000' '\n' > "$reply"

if grep -q '^ERROR' "$reply" || ! grep -q '^RECEIPT' "$reply"; then
  cat "$reply"
  exit 1
fi
echo "scheduled 5 payments on payments.settlement, due in 1 to 5 days"
