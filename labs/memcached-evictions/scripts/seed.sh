#!/bin/sh
# Commits all of cache-a's pages to one small item size, lets two thirds of those items expire, and gives
# cache-b a working set it reads back.
set -eu
. /scripts/common.sh

A="${CACHE_A:-cache-a}"
B="${CACHE_B:-cache-b}"
TTL="${SMALL_TTL:-45}"

if [ "$(stat_of "$A" stats curr_items)" != "0" ]; then
  echo "cache-a already holds items; run scripts/reset.sh to start over"
  exit 0
fi

# sessions <from> <to>: ~100-byte items; every third one never expires, the rest expire after TTL seconds
sessions() {
  awk -v from="$1" -v to="$2" -v ttl="$TTL" 'BEGIN {
    v = "theme=dark;locale=en-GB;cart=000"
    for (i = from; i <= to; i++)
      printf "set session:%08d 0 %d %d noreply\r\n%s\r\n", i, (i % 3 == 0 ? 0 : ttl), length(v), v
    printf "quit\r\n"
  }' | nc "$A" "$PORT" > /dev/null
}

# Pages are 1 MB and the limit is a whole number of them, so while total_malloced is below the limit one more
# page can still be taken, and a batch smaller than a page never evicts.
limit=$(stat_of "$A" stats limit_maxbytes)
n=0
while [ "$(stat_of "$A" "stats slabs" total_malloced)" -lt "$limit" ]; do
  sessions $((n + 1)) $((n + 5000))
  n=$((n + 5000))
done
echo "cache-a: $n session items written, every page committed"

echo "waiting ${TTL}s for two thirds of them to expire"
sleep $((TTL + 5))
mc "$A" "lru_crawler crawl all" > /dev/null
sleep 10

awk 'BEGIN {
  v = sprintf("%500s", ""); gsub(/ /, "p", v)
  for (i = 0; i < 20000; i++) printf "set profile:%05d 0 0 %d noreply\r\n%s\r\n", i, length(v), v
  for (i = 0; i < 20000; i += 40) printf "get profile:%05d\r\n", i
  printf "quit\r\n"
}' | nc "$B" "$PORT" > /dev/null

for node in "$A" "$B"; do
  mc "$node" stats | awk -v n="$node" '
    $1 == "STAT" { s[$2] = $3 }
    END { printf "%s: limit %d MB, items %d, bytes %d (%.0f%% of the limit), evictions %d, expired unread %d\n",
          n, s["limit_maxbytes"] / 1048576, s["curr_items"], s["bytes"], 100 * s["bytes"] / s["limit_maxbytes"],
          s["evictions"], s["expired_unfetched"] }'
done
echo "seed complete"
