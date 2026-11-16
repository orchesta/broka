# Lab: consumers, offsets and where to start

A single-node Kafka 4.3 cluster in KRaft mode, three files of bike rides and one small consumer,
written in Java and in Python. You create the `rides.completed` topic with 3 partitions yourself and
write the rides with the console producer. The consumer reads them as the group `ride-receipts`,
prints the partition and offset of each ride, and commits its position automatically. The lesson
uses the lab to show reading with and without a group, where a group's position is kept, where a
new group starts, and what automatic commits do when a consumer stops cleanly and when it crashes.

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
- Host ports 19233 and 19133 free, or change them in `.env`
- BROKA, if you want to read the cluster from its pages, for example from [`install/`](../../../install/)

The lab runs next to the earlier labs of the series without conflict: different project name,
different ports, different volume.

## Run

1. Optional: copy the settings file and change the defaults. You need to do this on Linux (see
   [Connect BROKA](#connect-broka)).

   ```bash
   cp .env.example .env
   ```

2. Start the broker:

   ```bash
   docker compose up -d --wait
   ```

3. Create the topic and write the first twelve rides. Each line of `rides-1.txt` is a key, a `|` and
   a value, and the console producer splits it there.

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 \
     --create --topic rides.completed --partitions 3 --replication-factor 1
   docker compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:29092 \
     --topic rides.completed --reader-property parse.key=true --reader-property key.separator='|' < rides-1.txt
   ```

4. Run the consumer, in Java:

   ```bash
   cd java
   mvn -q compile exec:java
   ```

   or in Python:

   ```bash
   cd python
   python3 -m venv .venv
   . .venv/bin/activate
   pip install -r requirements.txt
   python ride_consumer.py
   ```

   The first Maven run downloads the Kafka client and Maven's plugins, and `-q` keeps it silent while
   it does. The consumer prints the twelve rides and waits for more. In a second terminal, from the
   lab's folder, write three more and watch them arrive:

   ```bash
   docker compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:29092 \
     --topic rides.completed --reader-property parse.key=true --reader-property key.separator='|' < rides-2.txt
   ```

   Stop the consumer with Ctrl+C: it commits its position as it closes. Then go back to the lab's
   folder with `cd ..`.

5. See the position the group committed:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --describe --group ride-receipts
   ```

6. Write the last two rides. Both go to partition 0:

   ```bash
   docker compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:29092 \
     --topic rides.completed --reader-property parse.key=true --reader-property key.separator='|' < rides-3.txt
   ```

7. Imitate a crash. Given a number, the consumer stops after reading that many rides, the way a crash
   would: without closing and without committing. In Java:

   ```bash
   cd java
   mvn -q compile exec:java -Dexec.args=1
   ```

   or in Python:

   ```bash
   cd python
   . .venv/bin/activate
   python ride_consumer.py 1
   ```

   It prints `bike-1234: partition 0, offset 5` and `crash`. Start it again without the number, with
   `mvn -q compile exec:java` or `python ride_consumer.py`. Until about 45 seconds after the crash, the
   broker still counts the crashed consumer as a member, and nothing comes; then the new one gets the
   partitions and prints offsets 5 and 6 of partition 0. Offset 5 comes a second time: the crashed
   consumer read it but did not commit past it. Stop the consumer with Ctrl+C, and go back to the lab's
   folder with `cd ..`.

## Two ports for clients

The broker listens for clients on two ports, and each one gives clients a different address to come
back to:

| Port | For | Address the broker gives back |
|---|---|---|
| 19233 | programs you run on this machine, such as the lab's consumer | `localhost:19233` |
| 19133 | clients in other containers, such as BROKA | `host.docker.internal:19133` |

The consumer connects to `localhost:19233`. If you change `KAFKA_HOST_PORT`, change that address in
the code too. Keep programs on your machine on 19233: port 19133 gives clients back
`host.docker.internal`, a name made for containers. Where your machine cannot resolve that name, as on
a Mac with Docker Desktop's default settings, a consumer on 19133 connects once and then reads nothing.

## Connect BROKA

Add a Kafka cluster in BROKA, from the cluster selector in the header (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-consumers` |
| Bootstrap servers | `host.docker.internal:19133` on Docker Desktop, `<host-ip>:19133` on Linux |
| Authentication method | None |

Press **Test connection** before **Create connection**: it reports *OK* and how long the broker took to
answer. The new connection appears in the cluster list, and the Kafka pages read it from now on.

The broker gives clients on this port the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers
must be able to reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that IP in
the connection.

## What to look at

1. **Consumer Groups.** Kafka ▸ **Consumer Groups** lists `ride-receipts` with its state, members and
   lag. While the consumer runs, the group has one member. After Ctrl+C it has none, and the state
   column shows **Inactive**: the group has committed offsets, and nothing is consuming now.
2. **Members.** Open the group: **Members** shows the running consumer with its client id and
   host. After the crash in step 7, the consumer that crashed stays listed for about 45 seconds,
   until the broker gives up on it.
3. **Where the group would resume.** On `rides.completed` ▸ **Messages**, start **From a consumer
   group** with `ride-receipts`. The read starts at the group's committed offsets, so it shows what the
   group would read next: nothing after a clean stop, and offsets 5 and 6 of partition 0 after the
   crash.
4. **Starting by time.** **Last 15 minutes** starts every partition at its first record no older
   than 15 minutes, as `auto.offset.reset=by_duration:PT15M` does.
5. **No group left behind.** Reading in **Messages** never joins a group and never commits, so it adds
   nothing to the Consumer Groups list, unlike the console consumer, which joins a group with a
   generated name when you give it no `--group`.

## Clean up

```bash
docker compose down -v
```

## Lesson

[Consuming: offsets, groups and where to start](https://broka.dev/learn/kafka/consuming-offsets-and-where-to-start)
