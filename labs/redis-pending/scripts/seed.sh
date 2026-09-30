#!/bin/sh
# Builds broka:orders with two consumer groups, a stuck pending list and a group whose lag is unknown.
set -euo pipefail

STREAM=broka:orders
TMP=broka:orders:seed
R() { redis-cli -h "${REDIS_HOST:-redis}" -p "${REDIS_PORT:-6379}" "$@"; }

R DEL "$TMP" >/dev/null

i=1
while [ "$i" -le 40 ]; do
  R XADD "$TMP" '*' order "ord-$i" amount "$((i * 7))" status new >/dev/null
  i=$((i + 1))
done
id_at() { R XRANGE "$TMP" - + COUNT "$1" | grep -E '^[0-9]+-[0-9]+$' | sed -n "${1}p"; }

R XGROUP CREATE "$TMP" fulfilment 0 >/dev/null
R XGROUP CREATE "$TMP" analytics 0 >/dev/null

# fulfilment: two consumers take ten entries and never acknowledge them.
R XREADGROUP GROUP fulfilment picker-1 COUNT 6 STREAMS "$TMP" '>' >/dev/null
R XREADGROUP GROUP fulfilment picker-2 COUNT 4 STREAMS "$TMP" '>' >/dev/null

# Two more are read and acknowledged, so the group has moved past entry 12.
R XREADGROUP GROUP fulfilment picker-2 COUNT 2 STREAMS "$TMP" '>' >/dev/null
R XACK "$TMP" fulfilment "$(id_at 11)" "$(id_at 12)" >/dev/null

# Re-deliver two entries until they count five and six deliveries.
FIRST=$(id_at 1)
SECOND=$(id_at 2)
for n in 1 2 3 4; do R XCLAIM "$TMP" fulfilment picker-2 0 "$FIRST" >/dev/null; done
for n in 1 2 3 4 5; do R XCLAIM "$TMP" fulfilment picker-1 0 "$SECOND" >/dev/null; done

# Backdate every pending entry to six hours idle, keeping owner and delivery count.
R XPENDING "$TMP" fulfilment - + 100 | paste - - - - | while read -r id owner _ _; do
  R XCLAIM "$TMP" fulfilment "$owner" 0 "$id" IDLE 21600000 JUSTID </dev/null >/dev/null
done

# analytics has read nothing; deleting an entry it has not reached leaves Redis unable to count its lag.
R XDEL "$TMP" "$(id_at 11)" >/dev/null

R RENAME "$TMP" "$STREAM" >/dev/null

echo "stream  $STREAM  length $(R XLEN "$STREAM")"
R XINFO GROUPS "$STREAM" | paste - - \
  | awk -F'\t' '$1 == "name" { if (l) print l; l = " " } { l = l " " $1 "=" ($2 == "" ? "(nil)" : $2) } END { print l }'
R XPENDING "$STREAM" fulfilment - + 100 | paste - - - - | awk '{printf "  %s  owner=%s  idle=%sms  deliveries=%s\n", $1, $2, $3, $4}'
