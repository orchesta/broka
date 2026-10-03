#!/bin/sh
# Every second: RATE page fragments of ~2.4 KB written to and read from cache-a, a few short-lived sessions
# nobody reads, and reads of cache-b's profiles.
set -eu
. /scripts/common.sh

A="${CACHE_A:-cache-a}"
B="${CACHE_B:-cache-b}"
RATE="${RATE:-40}"

echo "writing $RATE page fragments a second to $A"
i=0
while :; do
  i=$((i + 1))
  awk -v s="$i" -v n="$RATE" 'BEGIN {
    srand(s)
    v = sprintf("%2400s", ""); gsub(/ /, "x", v)
    for (k = 0; k < n; k++) printf "set page:%05d 0 0 %d noreply\r\n%s\r\n", int(rand() * 5000), length(v), v
    for (k = 0; k < n; k++) printf "get page:%05d\r\n", int(rand() * 5000)
    for (k = 0; k < n; k++) printf "get session:%08d\r\n", 3 * (1 + int(rand() * 30000))
    t = "theme=dark;locale=en-GB;cart=000"
    for (k = 0; k < 10; k++) printf "set session:t%07d 0 10 %d noreply\r\n%s\r\n", s * 10 + k, length(t), t
    printf "quit\r\n"
  }' | nc "$A" "$PORT" > /dev/null || true

  awk -v s="$i" 'BEGIN {
    srand(s)
    for (k = 0; k < 20; k++) printf "get profile:%05d\r\n", int(rand() * 20000)
    printf "quit\r\n"
  }' | nc "$B" "$PORT" > /dev/null || true

  sleep 1
done
