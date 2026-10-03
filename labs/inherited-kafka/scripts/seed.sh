#!/usr/bin/env bash
# Leaves the cluster the way an inherited one often is: uneven partitions and leaders, a topic with one
# replica, overridden topic settings, dynamic broker settings, groups nobody runs any more, and ACLs.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka-1:29092,kafka-2:29092,kafka-3:29092}"
BIN=/opt/kafka/bin

until [ "$("$BIN/kafka-broker-api-versions.sh" --bootstrap-server "$BOOT" 2> /dev/null | grep -c '(id: ')" -ge 3 ]; do
  sleep 2
done

topics() { "$BIN/kafka-topics.sh" --bootstrap-server "$BOOT" "$@"; }
groups() { "$BIN/kafka-consumer-groups.sh" --bootstrap-server "$BOOT" "$@"; }

if groups --list | grep -qx billing-reconciler; then
  echo "already seeded; nothing to do"
  exit 0
fi

# create <topic> <replica assignment> [--config k=v ...]
create() {
  local topic=$1 assignment=$2
  shift 2
  topics --create --if-not-exists --topic "$topic" --replica-assignment "$assignment" "$@"
}
create orders 1:2:3,2:3:1,3:1:2,1:2:3,2:3:1,3:1:2 --config min.insync.replicas=2 --config retention.ms=1209600000
# Ten of twelve leaders on broker 1.
create clickstream.raw 1:2,1:3,1:2,1:3,1:2,1:3,1:2,1:3,2:3,3:2,1:2,1:3 --config retention.ms=86400000
create checkout.events 1,1,1,1,1,1
create payments.ledger 3:1,3:2,1:3 --config min.insync.replicas=2
create audit.log 1:2:3,2:3:1,3:1:2 --config cleanup.policy=compact
create inventory.snapshots 1:2:3,2:3:1,3:1:2 --config retention.bytes=104857600

# write <topic> <from> <to> <key modulo, 0 for unique keys>
write() {
  seq "$2" "$3" | awk -v t="$1" -v m="$4" '{ k = (m > 0 ? $1 % m : $1); printf "%s-%d|{\"seq\":%d,\"source\":\"%s\"}\n", t, k, $1, t }' |
    "$BIN/kafka-console-producer.sh" --bootstrap-server "$BOOT" --topic "$1" \
      --property parse.key=true --property key.separator='|' > /dev/null
}
# consumed <group> <topic>: commits the group at the end of the topic, as if it had read everything
consumed() {
  groups --group "$1" --topic "$2" --reset-offsets --to-latest --execute > /dev/null
}

write orders 1 600 0
write checkout.events 1 300 0
write payments.ledger 1 200 0
write audit.log 1 500 50
write inventory.snapshots 1 100 0
write clickstream.raw 1 2000 0

consumed billing-reconciler orders
consumed nightly-export checkout.events
consumed legacy-indexer audit.log
consumed fraud-scorer payments.ledger

# What arrived after each of them stopped reading.
write orders 601 850 0
write checkout.events 301 420 0
write audit.log 501 550 50
write payments.ledger 201 350 0

echo "dynamic broker settings"
"$BIN/kafka-configs.sh" --bootstrap-server "$BOOT" --entity-type brokers --entity-name 2 \
  --alter --add-config log.cleaner.threads=2
"$BIN/kafka-configs.sh" --bootstrap-server "$BOOT" --entity-type brokers --entity-default \
  --alter --add-config message.max.bytes=2097152

echo "ACLs"
acl() { "$BIN/kafka-acls.sh" --bootstrap-server "$BOOT" --add --force "$@" > /dev/null; }
acl --allow-principal User:svc-ledger --operation Write --operation Describe --topic payments.ledger
acl --allow-principal User:svc-ledger --operation Read --group ledger-audit
acl --allow-principal User:svc-ledger --operation IdempotentWrite --cluster
acl --allow-principal User:svc-ledger --operation Write --operation Describe \
  --transactional-id ledger-writer- --resource-pattern-type prefixed
acl --allow-principal User:svc-analytics --operation Read --operation Describe \
  --topic clickstream. --resource-pattern-type prefixed
acl --allow-principal User:svc-analytics --operation Read --group analytics- --resource-pattern-type prefixed
acl --deny-principal User:svc-analytics --operation Read --topic payments.ledger

topics --describe --topic clickstream.raw
groups --describe --all-groups 2> /dev/null || true
echo "seed complete"
