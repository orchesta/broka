# Lab: consumer lag and resetting offsets

A single-node Kafka 4.3 cluster in KRaft mode, a producer that writes two bike rides a second, and one
small consumer that bills one ride a second, written in Java and in Python. You create the
`rides.completed` topic with 3 partitions yourself, start the producer, and run copies of the consumer
as members of one group, `ride-billing`; each copy prints every ride it bills. The lesson uses the lab
to show how a group falls behind and catches up, what the tools count as lag, what a member
that crashes leaves behind, and how to move or delete a group's committed offsets safely.

**Edition:** Community

## Requirements

- Docker with Compose v2.20 or later
- A bash-style shell; on Windows, run the commands in WSL
- JDK 21 with Maven 3.9 or later, or Python 3.12 to 3.14 with `pip`
- On Ubuntu 24.04, also under WSL: the `maven` package is 3.8, which fails on this project with "Source
  option 5 is no longer supported", so install Maven 3.9 from maven.apache.org; for Python, install the
  `python3-venv` package first
- If `python3 --version` prints 3.15: the lab's Kafka client, `confluent-kafka` 2.16.1, has no prebuilt
  package for Python 3.15, so `pip` tries to build the package from source and usually fails; install
  Python 3.14 as well, for example with `brew install python@3.14` on a Mac, and in step 4 create the
  virtual environment with `python3.14 -m venv --clear .venv` instead of `python3 -m venv .venv`
  (`--clear` empties a `.venv` an earlier attempt left behind)
- Host ports 19235 and 19135 free, or change them in `.env`
- BROKA, if you want to read the cluster from its pages, for example from [`install/`](../../../install/)

The lab runs next to the earlier labs of the series without conflict: different project name,
different ports, different volume.

## Run

You need four terminals: one for each of three members, and one for the commands.

1. Optional: copy the settings file and change the defaults, such as `RATE`, the rides the producer
   writes each second. You need to do this on Linux (see [Connect BROKA](#connect-broka)). The steps below
   assume the default, two rides a second.

   ```bash
   cp .env.example .env
   ```

2. Start the broker:

   ```bash
   docker compose up -d --wait
   ```

3. Create the topic, with three partitions:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 \
     --create --topic rides.completed --partitions 3 --replication-factor 1
   ```

   Then start the producer. It writes two rides a second, each keyed by a random bike, until you stop
   it. Plain `docker compose up` leaves it out; naming it starts it.

   ```bash
   docker compose up -d producer
   ```

   Read the end of each partition's log twice, a few seconds apart, and watch it grow:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server localhost:29092 \
     --topic rides.completed
   ```

4. Start the first member, `billing-1`, in a second terminal, from the lab's folder. In Java:

   ```bash
   cd java
   mvn -q compile exec:java -Dexec.args=billing-1
   ```

   or in Python:

   ```bash
   cd python
   python3 -m venv .venv
   . .venv/bin/activate
   pip install -r requirements.txt
   python billing_consumer.py billing-1
   ```

   The first Maven run downloads the Kafka client and Maven's plugins, and `-q` keeps it silent while
   it does. The member prints one line for each ride it bills, such as
   `billing-1: bike-1319, partition 0, offset 0`, one a second.

5. In the first terminal, describe the group: for each partition, the offset the group has committed,
   the end of the log, and the lag between them.

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --describe --group ride-billing
   ```

   Run it again a little later: the producer writes two rides a second and the member bills one, so the
   total lag grows by about one ride a second. A member reads a batch from one partition before it moves
   to the next, so the lag is uneven across the partitions.

6. Start a second member, `billing-2`, in a third terminal, from the lab's folder, with `5` as a second
   argument: after five rides, it stops abruptly, as a crash would. In Java:

   ```bash
   cd java
   mvn -q compile exec:java -Dexec.args="billing-2 5"
   ```

   or in Python:

   ```bash
   cd python
   . .venv/bin/activate
   python billing_consumer.py billing-2 5
   ```

   The group gives it one partition. It bills five rides from it, prints `billing-2: crash` and exits
   without leaving the group. Describe the group again, a few times: the partition stays with `billing-2`
   until its session times out, after about 45 seconds, and its lag grows; then `billing-1` holds all three
   partitions again.

7. Stop the producer:

   ```bash
   docker compose stop producer
   ```

   Then start `billing-2` again in the third terminal, this time without a second argument, and a third
   member, `billing-3`, the same way in a fourth terminal. Describe the group every few seconds until the
   lag is 0 on every partition. The member that takes over the crashed member's partition starts at the
   offset last committed there, which can be before the rides `billing-2` billed: if it is, those rides
   are billed twice.

8. Move the group back three rides on each partition. While its members run, the tool refuses:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --reset-offsets --group ride-billing --topic rides.completed --shift-by -3 --dry-run
   ```

   Stop the three members with Ctrl+C, and check that the group is empty: its state is `Empty`, with 0
   members.

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --describe --group ride-billing --state
   ```

   Run the reset command above again: with `--dry-run`, it prints the plan, the new offset of each
   partition, and changes nothing. Then run it with `--execute` in place of `--dry-run`, and describe
   the group: the lag is 3 on each partition. Start `billing-1` again: it bills the last three rides of
   each partition a second time. Stop it with Ctrl+C.

9. Delete the group's offsets on the topic, then describe the group: it has no rows left.

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --delete-offsets --group ride-billing --topic rides.completed
   ```

   Start `billing-1` again: with nothing committed, it starts where `auto.offset.reset` says, at the
   beginning of each partition. Stop it with Ctrl+C. Then delete the group itself:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --delete --group ride-billing
   ```

## Two ports for clients

The broker listens for clients on two ports, and each one gives clients a different address to come
back to:

| Port | For | Address the broker gives back |
|---|---|---|
| 19235 | programs you run on this machine, such as the lab's consumer | `localhost:19235` |
| 19135 | clients in other containers, such as BROKA | `host.docker.internal:19135` |

The consumer connects to `localhost:19235`. If you change `KAFKA_HOST_PORT`, change that address in
the code too. Keep programs on your machine on 19235: port 19135 gives clients back
`host.docker.internal`, a name made for containers. Where your machine cannot resolve that name, as on
a Mac with Docker Desktop's default settings, a consumer on 19135 connects once and then reads nothing.

## Connect BROKA

Add a Kafka cluster in BROKA, from the cluster selector in the header (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-consumer-lag` |
| Bootstrap servers | `host.docker.internal:19135` on Docker Desktop, `<host-ip>:19135` on Linux |
| Authentication method | None |

Press **Test connection** before **Create connection**: it reports *OK* and how long the broker took to
answer. The new connection appears in the cluster list, and the Kafka pages read it from now on.

The broker gives clients on this port the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers
must be able to reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that IP in
the connection.

## What to look at

1. **Lag.** Kafka ▸ **Consumer Groups** lists `ride-billing` with its state, members and lag. Press
   **Refresh** to read the list again: while `billing-1` is alone, the lag grows between two readings.
2. **Lag over time.** Open `ride-billing`: the strip at the top has its offset lag and time lag, and the
   **Metrics** tab charts its lag and consume rate over time, a reading a minute. The lag climbs while
   one member bills, and falls to zero once the producer stops and three members bill.
3. **Reset offsets.** **Reset offsets**, at the top of the group's detail, is offered only when the group
   is stopped; while a member runs, it says *Stop the group's consumers first*. With the members stopped,
   pick a strategy, such as **Shift by**, and read the *Per-partition plan*, each partition's **Current**
   and **New** offset, before **Apply reset**, which asks for a reason. **Timestamp** is read in your
   browser's local time, while the reset command's `--to-datetime` reads a time without a zone as UTC.
4. **Delete offsets.** On the group's **Topics** tab, the ⋯ menu of the `rides.completed` row has
   **Delete offsets**, which asks for a reason; Kafka refuses it while the group is reading the topic.

## Clean up

```bash
docker compose --profile rides down -v
```

The producer is in the `rides` profile, so name the profile: without it, `down` may leave the producer
running.

## Lesson

[Consumer lag and resetting offsets safely](https://broka.dev/learn/kafka/consumer-lag-and-resetting-offsets)
