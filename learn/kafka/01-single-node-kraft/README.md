# Lab: your first Kafka cluster

A single-node Kafka 4.3 cluster in KRaft mode: one container that is both the broker and the
controller, with the data a small bike-share service might write. `rides.completed` (6 partitions)
receives a steady stream of finished rides keyed by bike, and `stations.status` (3 partitions,
compacted) holds each station's latest counts. One consumer group, `ride-billing`, keeps up with the
rides. Nothing is broken here. The lab exists to be read screen by screen, and to be changed from
BROKA: a topic you create, a message you write, a consumer you stop and start.

**Edition:** Community

## Requirements

- Docker with Compose v2
- BROKA running, for example from [`install/`](../../../install/)
- Host port 19130 free, or change it in `.env`

## Run

1. Optional: copy the settings file and change the defaults. You need to do this on Linux (see
   [Connect BROKA](#connect-broka)).

   ```bash
   cp .env.example .env
   ```

2. Start the broker, the seed job, the producer and the consumer:

   ```bash
   docker compose up -d
   ```

   The broker formats its storage on the first start and comes up alone, as the only voter of its
   controller quorum. The seed job creates both topics, writes 240 station updates and 3,000 past
   rides, and leaves `ride-billing` positioned at the end of `rides.completed`. The producer then
   writes 10 rides per second (`RATE` in `.env`), and the `ride-billing` member joins and keeps up.

3. Look at the cluster from the command line if you want to:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-topics.sh \
     --bootstrap-server localhost:29092 --describe
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh \
     --bootstrap-server localhost:29092 --describe --group ride-billing
   ```

## Connect BROKA

Add a Kafka cluster in BROKA, from the cluster selector in the header (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-first-cluster` |
| Bootstrap servers | `host.docker.internal:19130` on Docker Desktop, `<host-ip>:19130` on Linux |
| Authentication method | None |

Press **Test connection** before **Create connection**: it reports *OK* and how long the broker took to
answer. The new connection appears in the cluster list, and the Kafka pages read it from now on.

The broker gives clients the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers must be able
to reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that
IP in the connection.

## What to look at

1. **Overview.** The cluster is **Healthy** with 1 broker, and **Under-replicated** reads 0 with
   *all in sync*: every partition has its single replica. The tiles count the two topics, their nine
   partitions and the one consumer group, and the lag total stays small.
2. **Brokers.** **Version** reads 4.3 and the one broker carries the **Controller** badge. **Offline
   partitions** and **Under min ISR** read **Needs JMX**: the lab does not expose it. There is no skew
   column and no **Config drift**; both need a second broker. Open broker 1 ▸ **Configuration**: it
   opens with **Only changed** switched on, and the list is the `KAFKA_*` lines of `compose.yml` under
   their property names, each with the source **Static broker config**. One more line,
   `min.insync.replicas=1`, has the source **Dynamic default broker config**: from Kafka 4.1 a new
   cluster enables eligible leader replicas, which records this value once at cluster level, and every
   topic shows it as an override. **View as text** gives the whole configuration. **Log directories ▸ Directories** shows the volume the broker
   writes to.
3. **Quorum and Features.** **Quorum** lists one node, the leader and the only voter: a quorum of one.
   **Features** lists each feature with its finalized level. `kraft.version` reads **0 (off)**,
   because the voter is fixed in configuration; `metadata.version` reads the 4.3 level.
4. **Topics.** Add the **Cleanup policy** column from **Columns**: `rides.completed` is `delete`,
   `stations.status` is `compact`. Open `stations.status` ▸ **Config** and tick **Overrides only**:
   `cleanup.policy` is listed as overridden, next to the `min.insync.replicas` the broker wrote. The
   pencil opens the setting with Kafka's default and a **Reset to default** button. Its message count
   is higher than its 12 keys, because compaction never touches the active segment. On `rides.completed` ▸
   **Partitions**, each of the six rows shows one replica, on broker 1, and it is in sync.
5. **Create a topic.** **Create topic**, name `bikes.maintenance`, 3 partitions. **Replication
   factor** is fixed at 1, and its **What is this?** note says why: it can never exceed the broker
   count.
6. **Write and read a message.** Open `bikes.maintenance` and press **Produce**: on the **Value** tab
   enter `{"bike":"bike-1042","action":"brake-check"}`, on the **Key** tab enter `bike-1042`. Back on
   **Messages**, start **From the beginning**: the record is there. Open it: the header gives its
   partition and offset, **Payload** shows the key and the value, and **Re-publish** opens the same
   form again. Then ⋯ ▸ **Delete** on the topic, type its name and, if you like, a reason for the
   audit trail: it is gone from the list and from `kafka-topics.sh --list`.
7. **Search by key.** On `rides.completed`, set **Search in** to **Key**, enter `bike-1042` and start
   **From the beginning**. The seed wrote three rides for every bike and the producer keeps adding
   more, so at least three records come back (the search stops at 200 matches). Add the **Partition**
   column from **Columns**: every row shows the same partition, because the key decides where a
   record lands.
8. **Consumer Groups.** `ride-billing` is `Stable` with 1 member, a consume rate of about 10 msg/s
   and a small lag. Open it: **Members** lists one member,
   `ride-billing-1`, with the address of the `billing` container, and **Topology** shows a single
   card holding all six partitions. Now stop the consumer:

   ```bash
   docker compose stop billing
   ```

   The group turns `Empty` and carries the **Inactive** signal: committed offsets, no members. Its
   lag grows by 10 records a second. Start it again with `docker compose start billing`: the member
   rejoins, continues from the committed position and the lag drops back to zero. The position
   belongs to the group on the broker, not to the container.
9. **Audit.** Back on the overview, **Recent Kafka activity** lists the connection you created, the
   messages you produced and the topic you created and deleted, with who did it and when. **Audit
   log** opens the whole trail, with action, target, actor, environment and result.

## Clean up

```bash
docker compose down -v
```

## Lesson

[A single-node Kafka cluster with KRaft](https://broka.dev/learn/kafka/single-node-kraft-cluster)
