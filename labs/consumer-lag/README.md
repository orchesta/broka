# Lab: consumer lag

A single-node Kafka cluster with two consumer groups in different states. `analytics-loader` is
`Stable` with two members, each in its own container. They consume `clickstream.raw` (12 partitions)
more slowly than a producer writes to it, so the group's lag keeps growing. `order-service` has
stopped: it is `Empty`, has committed offsets on `orders.v2` (6 partitions) and is 4,000 records
behind, so you can try an offset reset on it.

**Edition:** Community

## Requirements

- Docker with Compose v2
- BROKA running, for example from [`install/`](../../install/)

## Run

1. Optional: copy the settings file and change the defaults. You need to do this on Linux (see
   [Connect BROKA](#connect-broka)).

   ```bash
   cp .env.example .env
   ```

2. Start the broker, the seed job, the producer and the two consumers:

   ```bash
   docker compose up -d
   ```

   The seed job creates both topics and leaves `order-service` stopped with its backlog. The producer
   writes 40 page views per second (`RATE` in `.env`), and the two `analytics-loader` members join
   and fall behind straight away.

3. Check both groups from the command line if you want to:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh \
     --bootstrap-server localhost:29092 --describe --all-groups
   ```

## Connect BROKA

Add a Kafka cluster in BROKA (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-consumer-lag` |
| Bootstrap servers | `host.docker.internal:19092` on Docker Desktop, `<host-ip>:19092` on Linux |
| Authentication method | None |

The broker gives clients the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers must be able
to reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that
IP in the connection.

## What to look at

1. **Kafka ▸ Consumer Groups.** `analytics-loader` is `Stable` with 2 members and its offset lag
   rises each time you press **Refresh**. `order-service` is `Empty` with 4.0K of lag and the
   **Inactive** signal. The consume rate is blank until the list has read the positions twice.
2. **Time lag.** Add the **Time lag** column from **Columns**. On `analytics-loader` it keeps growing,
   because records wait longer and longer before they are consumed. On `order-service` it stays small
   even though nothing consumes the group: nothing has been written to `orders.v2` since the group
   stopped, so there is little history between its position and the end of the log.
3. **Open `analytics-loader`.** **Members** lists `analytics-loader-1` and `analytics-loader-2` on two
   different hosts. **Topology** shows each member with its six partitions and the lag on each one.
   **Lag by** set to **Member host** splits the total between the two containers.
4. **Reset `order-service`.** Open the group and choose **Reset Offset** from its ⋯ menu. Pick **Latest** and press
   **Preview**: the per-partition plan shows the **Current** and **New** offset for each partition of
   `orders.v2`, and nothing has been written yet. **Apply reset** asks for a reason, and the group's
   lag drops to 0. To keep a restore point first, **Duplicate** the group.
5. **A running group cannot be reset.** On `analytics-loader`, **Reset Offset** is disabled with
   *(must be stopped)*, because the group has live members.

## Stop the load and reset the growing group

```bash
bash scripts/reset.sh
```

This stops the producer and both consumers, waits for `analytics-loader` to become `Empty`, and moves
its offsets on `clickstream.raw` to the latest position. The group then shows 0 lag. To start the load
again:

```bash
docker compose start producer loader-1 loader-2
```

## Clean up

```bash
docker compose down -v
```

## Guide

[Investigating consumer lag without guesswork](https://broka.dev/guides/consumer-lag-without-guesswork)
