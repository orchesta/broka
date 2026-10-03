# Lab: a Kafka cluster you did not build

A three-broker Kafka 4.3 cluster in KRaft mode, each broker also a controller, set up the way an
inherited cluster often is. Broker 3 was started with a shorter log retention than the other two, and
broker 2 carries a dynamic setting the others do not. Partitions and leaders are uneven: broker 1 leads
ten of `clickstream.raw`'s twelve partitions, and `checkout.events` has one replica, all on broker 1.
Topics carry overridden retention, minimum in-sync replicas and compaction. Three consumer groups have
committed offsets and no members, one has a member that never commits, and `analytics-loader` falls
behind with two members. ACLs are enforced, with allow, deny and prefix rules for two application
principals. A Schema Registry runs beside it with a few subjects, and there is no Kafka Connect.

**Edition:** Community

## Requirements

- Docker with Compose v2, with about 3 GB of memory to spare
- BROKA running, for example from [`install/`](../../install/)
- Host ports 19121, 19122, 19123 (Kafka) and 18086 (Schema Registry) free, or change them in `.env`

## Run

1. Optional: copy the settings file and change the defaults. You need to do this on Linux (see
   [Connect BROKA](#connect-broka)).

   ```bash
   cp .env.example .env
   ```

2. Start the cluster, the registry, the seed jobs and the clients:

   ```bash
   docker compose up -d
   ```

   The seed creates the topics with fixed replica placements, writes records, commits the stopped groups'
   offsets and then writes more, sets the dynamic broker settings and adds the ACLs. The producer, the two
   `analytics-loader` members and `fraud-scorer` start when it is done.

3. Check what the seed did:

   ```bash
   docker compose logs seed registry-seed
   docker compose exec kafka-1 /opt/kafka/bin/kafka-acls.sh --bootstrap-server localhost:29092 --list
   ```

## Connect BROKA

Add a Kafka cluster in BROKA (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-inherited` |
| Read-only | on |
| Bootstrap servers | `host.docker.internal:19121,host.docker.internal:19122,host.docker.internal:19123` on Docker Desktop, the host's IP address on Linux |
| Authentication method | None |

The brokers give clients the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers must be able to
reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that IP in
the connection.

Register the Schema Registry for step 7 only: the connection's row menu ▸ **Schema Registry**, **URL**
`http://host.docker.internal:18086`.

## What to look at

0. **Connect read-only.** With the switch on, any write is refused and the attempt is recorded in the
   audit log. The connection's page ends with **Supported features**.
1. **Overview.** Healthy, 3 brokers, **Under-replicated** 0. The groups with the most lag include
   `billing-reconciler`, `nightly-export` and `legacy-indexer`, all `Empty`.
2. **Brokers ▸ Version** reads 4.3. **Features** lists each feature with its finalized level; `kraft.version`
   reads **0 (off)**, because the quorum's voters are fixed in configuration. **Quorum** shows the leader
   and the two other voters with how far each trails.
3. **Brokers.** The list shows `eu-west-1a`, `eu-west-1b` and `eu-west-1c`, and the skew percentages put
   broker 1 well above its share of partitions and leaders. **Config drift** reads **Found**:
   `log.retention.hours` is 72 on broker 3 and 168 on the others, and `log.cleaner.threads` is 2 on broker 2.
   Open broker 2 ▸ **Configuration**: `log.cleaner.threads` has the source `DYNAMIC_BROKER_CONFIG`,
   `message.max.bytes` `DYNAMIC_DEFAULT_BROKER_CONFIG`, and the listeners `STATIC_BROKER_CONFIG`. **View as
   text** gives the whole configuration. **Logs ▸ Directories** shows the volume's size and free space.
4. **Topics.** Add the replication factor and minimum in-sync replicas columns: `checkout.events` has one
   replica, `payments.ledger` two with a minimum of two. Open `orders` ▸ **Config**: only `retention.ms` and
   `min.insync.replicas` are listed, as overrides. `audit.log` is compacted: its message count is higher
   than its 50 distinct keys. **Partitions** on `clickstream.raw`, then **Per broker**: broker 1 leads ten.
5. **Consumer Groups.** `billing-reconciler`, `nightly-export` and `legacy-indexer` carry **Inactive**:
   committed offsets and no members. `fraud-scorer` has a member and a position that does not move while
   150 records wait; after a minute it reads **Stalled**. `analytics-loader` is `Stable` with a lag that
   rises; its **Topology** has a card for each of its two members.
6. **Service Accounts** lists `svc-analytics` and `svc-ledger`. `svc-analytics`'s deny on `payments.ledger`
   sorts to the top, and its `clickstream.` topic rule and `analytics-` group rule carry **Prefix**. On
   **Topics ▸ `clickstream.raw` ▸ ACL**, the prefix rule appears although it does not name the topic.
7. **Schema registry and connectors.** Before the registry is registered, **Schema Registry** and
   **Connect** are greyed out. Register it, and its list opens on 3 subjects and global compatibility
   Backward. **Connect** stays greyed out: this lab runs none.
8. **A broker goes away.** Run `docker compose stop kafka-3`. Within a few seconds broker 3 is fenced: the
   list marks it **FENCED**, **Under-replicated** counts the partitions it held, and on `payments.ledger`
   ▸ **Partitions** broker 3 is listed under replicas and missing from in-sync. With one in-sync replica
   against a minimum of two, `payments.ledger` now refuses writes that wait for all replicas. Run
   `docker compose start kafka-3` to bring it back.

The guide's case of upgraded binaries running an older metadata version is not reproduced: this cluster
is formatted at the version it runs.

## Clean up

```bash
docker compose down -v
```

## Guide

[Reading a Kafka cluster you did not build](https://broka.dev/guides/reading-a-kafka-cluster-you-did-not-build)
