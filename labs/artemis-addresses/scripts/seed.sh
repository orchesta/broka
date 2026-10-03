#!/bin/sh
# Builds the addresses, queues and diverts over Jolokia, empties the lab's queues and sends the messages each
# step of the guide reads. Safe to run again: it returns the queues to the same state.
set -eu

JOLOKIA="${JOLOKIA_URL:-http://artemis:8161/console/jolokia/}"
PASS="${ARTEMIS_PASSWORD:?ARTEMIS_PASSWORD is not set}"
AUTH="broka:$PASS"
SEND='sendMessage(java.util.Map,int,java.lang.String,boolean,java.lang.String,java.lang.String)'

# The body goes through stdin: a bulk send is larger than one command-line argument may be.
post() { printf '%s' "$1" | curl -sS -u "$AUTH" -H 'content-type: application/json' --data-binary @- "$JOLOKIA"; }

until post '{"type":"version"}' 2> /dev/null | grep -q '"status":200'; do sleep 2; done

# Object names quote their values, and inside a JSON string each quote is \".
q='\"'
name=$(post '{"type":"search","mbean":"org.apache.activemq.artemis:broker=*"}' | sed 's/.*broker=\\"\([^\\]*\)\\".*/\1/')
[ -n "$name" ] || { echo "could not find the broker's name" >&2; exit 1; }
BROKER="org.apache.activemq.artemis:broker=$q$name$q"
address_mbean() { printf '%s,component=addresses,address=%s%s%s' "$BROKER" "$q" "$1" "$q"; }
queue_mbean() {
  printf '%s,component=addresses,address=%s%s%s,subcomponent=queues,routing-type=%s%s%s,queue=%s%s%s' \
    "$BROKER" "$q" "$1" "$q" "$q" "$2" "$q" "$q" "$3" "$q"
}

# Jolokia answers HTTP 200 for a failed operation too; the operation's status is in the body.
# call <mbean> <operation> <JSON arguments> [tolerate]
call() {
  out=$(post "{\"type\":\"exec\",\"mbean\":\"$1\",\"operation\":\"$2\",\"arguments\":$3}")
  case "$out" in *'"status":200'*) return 0 ;; esac
  [ "${4:-}" = tolerate ] && return 0
  echo "failed: $2 $3" >&2
  echo "$out" >&2
  exit 1
}

# msg <address> <properties JSON> <body, already escaped for a JSON string>: one send request
msg() {
  printf '{"type":"exec","mbean":"%s","operation":"%s","arguments":[%s,3,"%s",true,"broka","%s"]}\n' \
    "$(address_mbean "$1")" "$SEND" "$2" "$3" "$PASS"
}

# Reads send requests, one per line, and posts them as one bulk request.
send_all() {
  out=$(post "$(awk 'BEGIN { printf "[" } NR > 1 { printf "," } { printf "%s", $0 } END { printf "]" }')")
  failed=$(echo "$out" | grep -o '"status":[0-9]*' | grep -vc '"status":200' || true)
  [ "$failed" = 0 ] || { echo "$failed send(s) failed: $out" >&2; exit 1; }
}

address() { call "$BROKER" 'createAddress(java.lang.String,java.lang.String)' "[\"$1\",\"$2\"]" tolerate; }

# queue <address> <routing type> <name> [filter]
queue() {
  filter=""
  [ -z "${4:-}" ] || filter=",${q}filter-string${q}:${q}$4${q}"
  call "$BROKER" 'createQueue(java.lang.String)' \
    "[\"{${q}name${q}:${q}$3${q},${q}address${q}:${q}$1${q},${q}routing-type${q}:${q}$2${q},${q}durable${q}:true$filter}\"]" \
    tolerate
}

# divert <name> <from> <to> <exclusive> [filter]. The keys are kebab-case; the broker ignores any it does not know.
divert() {
  filter=""
  [ -z "${5:-}" ] || filter=",${q}filter-string${q}:${q}$5${q}"
  call "$BROKER" 'createDivert(java.lang.String)' \
    "[\"{${q}name${q}:${q}$1${q},${q}routing-name${q}:${q}$1${q},${q}address${q}:${q}$2${q},${q}forwarding-address${q}:${q}$3${q},${q}exclusive${q}:${q}$4${q}$filter}\"]"
}

echo "broker $name: message counters and address settings"
call "$BROKER" 'enableMessageCounters()' '[]'
call "$BROKER" 'addAddressSettings(java.lang.String,java.lang.String)' \
  "[\"telemetry\",\"{${q}maxSizeBytes${q}:65536,${q}pageSizeBytes${q}:32768,${q}addressFullMessagePolicy${q}:${q}PAGE${q}}\"]"
call "$BROKER" 'addAddressSettings(java.lang.String,java.lang.String)' \
  "[\"payments\",\"{${q}maxDeliveryAttempts${q}:3}\"]"

echo "addresses and queues"
address orders ANYCAST
queue orders ANYCAST orders.fulfilment
queue orders ANYCAST orders.billing
queue orders ANYCAST orders.acme "tenant = 'acme'"
address events MULTICAST
queue events MULTICAST events.audit
queue events MULTICAST events.search
queue events MULTICAST events.legacy
address analytics ANYCAST
queue analytics ANYCAST analytics.ingest
address notifications MULTICAST
address invoices ANYCAST
queue invoices ANYCAST invoices.mailer
address invoices.held ANYCAST
queue invoices.held ANYCAST invoices.held
address payments ANYCAST
queue payments ANYCAST payments.settlement
address shipments ANYCAST
queue shipments ANYCAST shipments.dispatch
address returns ANYCAST
queue returns ANYCAST returns.inbound
address telemetry MULTICAST
queue telemetry MULTICAST telemetry.raw

echo "emptying the queues"
for spec in orders/anycast/orders.fulfilment orders/anycast/orders.billing orders/anycast/orders.acme \
  events/multicast/events.legacy events/multicast/events.audit events/multicast/events.search \
  analytics/anycast/analytics.ingest invoices/anycast/invoices.mailer invoices.held/anycast/invoices.held \
  payments/anycast/payments.settlement shipments/anycast/shipments.dispatch returns/anycast/returns.inbound \
  telemetry/multicast/telemetry.raw DLQ/anycast/DLQ; do
  IFS=/ read -r a t n << EOF
$spec
EOF
  call "$(queue_mbean "$a" "$t" "$n")" 'removeAllMessages()' '[]'
done
call "$(queue_mbean orders anycast orders.billing)" 'resume()' '[]'
call "$(queue_mbean events multicast events.legacy)" 'disable()' '[]'
call "$BROKER" 'destroyDivert(java.lang.String)' '["events-to-analytics"]' tolerate
call "$BROKER" 'destroyDivert(java.lang.String)' '["invoices-hold"]' tolerate
divert events-to-analytics events analytics false "eventType = 'order.created'"

echo "messages"
{
  i=1
  while [ "$i" -le 12 ]; do
    if [ $((i % 2)) = 1 ]; then tenant=acme; else tenant=globex; fi
    msg orders "{\"tenant\":\"$tenant\",\"orderId\":\"A-$((1000 + i))\"}" \
      "{\\\"orderId\\\":\\\"A-$((1000 + i))\\\",\\\"tenant\\\":\\\"$tenant\\\",\\\"total\\\":$((i * 25)).50}"
    i=$((i + 1))
  done
  for i in 1 2; do
    msg events '{"eventType":"order.created"}' "{\\\"event\\\":\\\"order.created\\\",\\\"seq\\\":$i}"
  done
  for i in 1 2 3; do
    msg notifications '{"channel":"email"}' "{\\\"notification\\\":$i}"
  done
  for i in 1 2 3 4 5; do
    msg invoices '{"region":"eu"}' "{\\\"invoiceId\\\":\\\"INV-$((500 + i))\\\"}"
  done
} | send_all

# From here on, everything sent to invoices goes to invoices.held instead of invoices.mailer.
divert invoices-hold invoices invoices.held true

{
  for i in 1 2 3 4 5 6 7 8; do
    msg invoices '{"region":"eu"}' "{\\\"invoiceId\\\":\\\"INV-$((600 + i))\\\"}"
  done
  i=1
  while [ "$i" -le 30 ]; do
    msg shipments "{\"_AMQ_GROUP_ID\":\"customer-$((i % 3 + 1))\",\"shipmentId\":\"S-$((7000 + i))\"}" \
      "{\\\"shipmentId\\\":\\\"S-$((7000 + i))\\\",\\\"customer\\\":$((i % 3 + 1))}"
    i=$((i + 1))
  done
  i=1
  while [ "$i" -le 20 ]; do
    msg returns '{"carrier":"ups"}' "{\\\"returnId\\\":\\\"R-$((300 + i))\\\"}"
    i=$((i + 1))
  done
} | send_all

pad=$(awk 'BEGIN { s = sprintf("%1000s", ""); gsub(/ /, "t", s); print s }')
i=1
while [ "$i" -le 150 ]; do
  msg telemetry '{"sensor":"line-4"}' "{\\\"reading\\\":$i,\\\"pad\\\":\\\"$pad\\\"}"
  i=$((i + 1))
done | send_all

# Failures from three addresses, dead-lettered by the broker so each keeps the address it failed on.
{
  i=1
  while [ "$i" -le 14 ]; do
    msg orders "{\"poison\":\"true\",\"orderId\":\"F-$((100 + i))\"}" "{\\\"orderId\\\":\\\"F-$((100 + i))\\\"}"
    i=$((i + 1))
  done
  for i in 1 2 3 4; do
    msg payments "{\"poison\":\"true\",\"paymentId\":\"P-$((900 + i))\"}" "{\\\"paymentId\\\":\\\"P-$((900 + i))\\\"}"
  done
  msg events '{"poison":"true","eventType":"order.failed"}' '{\"event\":\"order.failed\"}'
} | send_all
for spec in orders/anycast/orders.fulfilment orders/anycast/orders.billing payments/anycast/payments.settlement \
  events/multicast/events.audit events/multicast/events.search; do
  IFS=/ read -r a t n << EOF
$spec
EOF
  call "$(queue_mbean "$a" "$t" "$n")" 'sendMessagesToDeadLetterAddress(java.lang.String)' "[\"poison = 'true'\"]"
done

call "$(queue_mbean orders anycast orders.billing)" 'pause(boolean)' '[true]'

echo "message counts:"
for spec in orders/anycast/orders.fulfilment orders/anycast/orders.billing orders/anycast/orders.acme \
  events/multicast/events.legacy events/multicast/events.audit events/multicast/events.search \
  analytics/anycast/analytics.ingest invoices/anycast/invoices.mailer invoices.held/anycast/invoices.held \
  shipments/anycast/shipments.dispatch returns/anycast/returns.inbound telemetry/multicast/telemetry.raw \
  DLQ/anycast/DLQ; do
  IFS=/ read -r a t n << EOF
$spec
EOF
  count=$(post "{\"type\":\"read\",\"mbean\":\"$(queue_mbean "$a" "$t" "$n")\",\"attribute\":\"MessageCount\"}" |
    sed 's/.*"value":\([0-9-]*\).*/\1/')
  echo "  $n: $count"
done
echo "seed complete"
