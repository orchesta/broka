#!/bin/sh
# A STOMP consumer on QUEUE that acknowledges nothing, so every message it is given stays in flight.
# Sends a heartbeat every five seconds so the broker keeps the connection open. STOMP 1.2 escapes a colon in
# a header value as \c.
set -eu

HOST="${STOMP_HOST:-artemis}"
PORT="${STOMP_PORT:-61613}"

echo "$CLIENT_ID consuming $QUEUE${SELECTOR:+ with selector $SELECTOR}"
{
  printf 'CONNECT\naccept-version:1.2\nhost:%s\nlogin:%s\npasscode:%s\nclient-id:%s\nheart-beat:10000,0\n\n\000' \
    "$HOST" "$ARTEMIS_USER" "$ARTEMIS_PASSWORD" "$CLIENT_ID"
  printf 'SUBSCRIBE\nid:1\ndestination:%s\ndestination-type:ANYCAST\nack:client-individual\nconsumer-window-size:-1\n' \
    "$(printf '%s' "$QUEUE" | sed 's/:/\\c/g')"
  if [ -n "${SELECTOR:-}" ]; then
    printf 'selector:%s\n' "$SELECTOR"
  fi
  printf '\n\000'
  while :; do
    sleep 5
    printf '\n'
  done
} | nc "$HOST" "$PORT" > /dev/null
