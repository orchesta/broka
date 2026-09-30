API="${RABBITMQ_API:-http://rabbitmq:15672/api}"
AUTH="broka:${RABBITMQ_PASSWORD:?RABBITMQ_PASSWORD is not set}"
VHOST=shop

# publish <exchange> <routing key> <payload> [headers JSON]; prints the broker's answer
publish() {
  headers=${4:-}
  [ -n "$headers" ] || headers='{}'
  curl -sS -f -u "$AUTH" -H 'content-type: application/json' \
    -X POST "$API/exchanges/$VHOST/$1/publish" \
    -d "{\"properties\":{\"content_type\":\"application/json\",\"delivery_mode\":2,\"headers\":$headers},\"routing_key\":\"$2\",\"payload\":\"$3\",\"payload_encoding\":\"string\"}"
}
