# Lab: producers, keys and partitions

A single-node Kafka 4.3 cluster in KRaft mode and two small producers, each written in Java and in
Python. The status producer writes sixteen status changes of four bikes to `bikes.status`, keyed by
bike. The search producer writes a thousand app searches to `app.searches` with no key at all. Both
topics have 6 partitions, and you create them yourself. The lesson uses the lab to show keys
choosing partitions, the order kept inside a partition, the state the broker keeps about each
producer, and what a producer does with records that have no key.

**Edition:** Community

## Requirements

- Docker with Compose v2
- JDK 21 with Maven 3.9, or Python 3.12 with `pip`
- Host ports 19232 and 19132 free, or change them in `.env`
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

3. Create the two topics. The broker does not create a topic when a producer first writes to it, so
   a producer started before this step has nowhere to write.

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 \
     --create --topic bikes.status --partitions 6 --replication-factor 1
   docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 \
     --create --topic app.searches --partitions 6 --replication-factor 1
   ```

4. Run the producers, in Java:

   ```bash
   cd java
   mvn -q compile exec:java
   mvn -q compile exec:java -Dexec.mainClass=learn.SearchProducer
   cd ..
   ```

   or in Python:

   ```bash
   cd python
   python3 -m venv .venv
   . .venv/bin/activate
   pip install -r requirements.txt
   python status_producer.py
   python search_producer.py
   cd ..
   ```

5. Read what they wrote, from the lab's folder:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:29092 \
     --topic bikes.status --partition 2 --offset earliest --max-messages 8 \
     --formatter-property print.offset=true --formatter-property print.key=true
   docker compose exec kafka /opt/kafka/bin/kafka-transactions.sh --bootstrap-server localhost:29092 \
     describe-producers --topic bikes.status --partition 2
   ```

## Two ports for clients

The broker listens for clients on two ports, and each one gives clients a different address to come
back to:

| Port | For | Address the broker gives back |
|---|---|---|
| 19232 | programs you run on this machine, such as the lab's producers | `localhost:19232` |
| 19132 | clients in other containers, such as BROKA | `host.docker.internal:19132` |

The producers connect to `localhost:19232`. If you change `KAFKA_HOST_PORT`, change that address in
the code too. Keep programs on your machine on 19232: port 19132 gives clients back
`host.docker.internal`, a name made for containers. Where your machine cannot resolve that name, as on
a Mac with Docker Desktop's default settings, a producer on 19132 connects once and then writes
nothing.

## Connect BROKA

Add a Kafka cluster in BROKA, from the cluster selector in the header (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-producers` |
| Bootstrap servers | `host.docker.internal:19132` on Docker Desktop, `<host-ip>:19132` on Linux |
| Authentication method | None |

Press **Test connection** before **Create connection**: it reports *OK* and how long the broker took to
answer. The new connection appears in the cluster list, and the Kafka pages read it from now on.

The broker gives clients on this port the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers
must be able to reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that IP in
the connection.

## What to look at

1. **Partitions.** On `bikes.status` ▸ **Partitions**, only partitions 0, 2 and 4 hold records after the
   status producer has run: four keys, and two of them share partition 2.
2. **Search by key.** On `bikes.status`, set **Search in** to **Key**, enter `bike-1042` and start
   **From the beginning**. Its records all come from partition 2, in the order the producer sent them.
3. **Producers.** On `bikes.status` ▸ **Producers**, each idempotent producer that wrote to the
   topic has one row per partition it wrote to: its producer id, its epoch and the last sequence
   number the partition kept from it. Run the status producer again and a new producer appears, with
   a new id. A producer with idempotence turned off never appears here.
4. **Produce.** **Produce**, in the header of `bikes.status`, sends a record with the key you give and
   reports the partition and the offset it landed at, the same receipt the producers print.

## Clean up

```bash
docker compose down -v
```

## Lesson

[Producing: keys, partitions and ordering](https://broka.dev/learn/kafka/producing-keys-partitions-and-ordering)
