# Lab: topics, partitions and the log

A single-node Kafka 4.3 cluster in KRaft mode, kept quiet on purpose: one container that is both the
broker and the controller, a seed job that creates two topics and writes their starting data, and no
producer or consumer, so that every number you read stays still. `rides.completed` (6 partitions)
holds 3,000 finished rides keyed by bike. `bikes.telemetry` (2 partitions, 1 MB segments) holds 40,000
bike positions, enough to split the log of each partition into several segment files. The lesson
uses the lab to create, change and delete topics from the command line, to see how keys choose
partitions, and to read the data directory file by file.

**Edition:** Community

## Requirements

- Docker with Compose v2
- Host port 19131 free, or change it in `.env`
- BROKA, if you want to read the cluster from its pages, for example from [`install/`](../../../install/)

The lab runs next to the first lab of the series without conflict: different project name, different
port, different volume.

## Run

1. Optional: copy the settings file and change the defaults. You need to do this on Linux (see
   [Connect BROKA](#connect-broka)).

   ```bash
   cp .env.example .env
   ```

2. Start the broker and the seed job:

   ```bash
   docker compose up -d --wait
   docker compose wait seed
   ```

   The broker formats its storage on the first start and comes up alone, as the only voter of its
   controller quorum. `--wait` returns as soon as the broker is healthy; the seed job then creates both
   topics and writes 3,000 rides and 40,000 positions, which takes a few seconds, and the second
   command returns when it has finished.

3. Look at the cluster from the command line if you want to:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-topics.sh \
     --bootstrap-server localhost:29092 --describe
   docker compose exec kafka /opt/kafka/bin/kafka-get-offsets.sh \
     --bootstrap-server localhost:29092 --topic bikes.telemetry
   ```

## Connect BROKA

Add a Kafka cluster in BROKA, from the cluster selector in the header (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-topics-and-partitions` |
| Bootstrap servers | `host.docker.internal:19131` on Docker Desktop, `<host-ip>:19131` on Linux |
| Authentication method | None |

Press **Test connection** before **Create connection**: it reports *OK* and how long the broker took to
answer. The new connection appears in the cluster list, and the Kafka pages read it from now on.

The broker gives clients the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers must be able
to reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that
IP in the connection.

## What to look at

1. **Topics.** Two topics, both with one replica on broker 1. Open `bikes.telemetry`: the header gives
   its partition count, its replication factor, its topic id, the message count and its size on disk.
   The topic id is the one `kafka-topics.sh --describe` prints and the one written in each partition
   directory's `partition.metadata`.
2. **Partitions.** On `bikes.telemetry` ▸ **Partitions**, the two rows carry 21,480 and 18,520
   records: the key is the bike, and a thousand bikes do not hash evenly across two partitions. Each
   row shows one replica, on broker 1, and it is in sync. There is no *Eligible leaders* column, because
   with a single replica no partition has any.
3. **Config.** On `bikes.telemetry` ▸ **Config**, the tab opens with **Overrides only**: `segment.bytes`
   is listed as an override. The pencil opens the edit panel, with **Reset to default** to remove the
   override; read-only settings show a lock instead. The lesson reads the same value with
   `kafka-configs.sh`.
4. **Create a topic.** **Create topic**, name `bikes.alerts`, 3 partitions. **Replication factor** is
   fixed at 1, and its **What is this?** note says why: it can never exceed the broker count.
5. **Add partitions.** The lesson creates `bikes.maintenance` with 3 partitions, writes six keyed
   records, raises the count to 6 and writes the same six keys again: two of them land on a new
   partition. BROKA's **Add partitions** dialog asks you to confirm exactly that: keyed records
   route differently from then on. The count cannot go below the current one, since Kafka can only
   add partitions.
6. **Search by key.** On `rides.completed`, set **Search in** to **Key**, enter `bike-1042` and start
   **From the beginning**. Three rides come back, all on the same partition, because the key decides
   where a record lands.
7. **Delete a topic.** ⋯ ▸ **Delete** on `bikes.alerts`, type its name: it is gone from the list and
   from `kafka-topics.sh --list`. On disk the broker renames its partition directories with a
   `-delete` suffix and removes them a minute later.

## Clean up

```bash
docker compose down -v
```

## Lesson

[Topics, partitions and the log underneath](https://broka.dev/learn/kafka/topics-partitions-and-the-log)
