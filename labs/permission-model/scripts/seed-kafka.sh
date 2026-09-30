#!/usr/bin/env bash
# Creates the topics, the application principals' ACLs, and one run of each application.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka:29092}"
BIN=/opt/kafka/bin

client_config() {
  printf 'security.protocol=SASL_PLAINTEXT\nsasl.mechanism=PLAIN\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="%s" password="%s";\n' \
    "$1" "$2" > "/tmp/$1.properties"
}
client_config admin "$ADMIN_PASSWORD"
client_config svc-checkout "$CHECKOUT_PASSWORD"
client_config svc-orders-reader "$READER_PASSWORD"

admin() { "$BIN/$1" --bootstrap-server "$BOOT" --command-config /tmp/admin.properties "${@:2}"; }

until admin kafka-topics.sh --list > /dev/null 2>&1; do sleep 2; done

for spec in orders.events:6 orders.returns:3 payments.events:3; do
  admin kafka-topics.sh --create --if-not-exists --topic "${spec%%:*}" --partitions "${spec##*:}" --replication-factor 1
done

acl() { admin kafka-acls.sh --add "$@" > /dev/null; }
acl --allow-principal User:svc-checkout --operation Write --operation Describe --topic orders.events
acl --allow-principal User:svc-orders-reader --operation Read --operation Describe \
  --topic orders. --resource-pattern-type prefixed
acl --allow-principal User:svc-orders-reader --operation Read --group orders-reader

if ! admin kafka-consumer-groups.sh --list | grep -qx orders-reader; then
  seq 1 50 | awk '{ printf "order-%d|{\"orderId\":\"order-%d\",\"status\":\"created\"}\n", $1, $1 }' |
    "$BIN/kafka-console-producer.sh" --bootstrap-server "$BOOT" --producer.config /tmp/svc-checkout.properties \
      --topic orders.events --property parse.key=true --property key.separator='|'
  "$BIN/kafka-console-consumer.sh" --bootstrap-server "$BOOT" --consumer.config /tmp/svc-orders-reader.properties \
    --topic orders.events --group orders-reader --from-beginning --max-messages 50 --timeout-ms 30000 > /dev/null
fi

# attempt <principal> <topic>: tries to write one record and reports the broker's answer
attempt() {
  out=$(echo probe | "$BIN/kafka-console-producer.sh" --bootstrap-server "$BOOT" --producer.config "/tmp/$1.properties" \
    --topic "$2" --request-required-acks all --producer-property max.block.ms=10000 2>&1 || true)
  case "$out" in
    *AuthorizationException* | *"Not authorized"*) echo "  $1 writing to $2: denied" ;;
    *) echo "  $1 writing to $2: allowed" ;;
  esac
}
echo "enforcement:"
attempt svc-orders-reader orders.events
attempt svc-checkout payments.events

echo "ACLs:"
admin kafka-acls.sh --list
