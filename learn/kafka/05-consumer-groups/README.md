# Lab: consumer groups and partition assignment

A single-node Kafka 4.3 cluster in KRaft mode, one file of bike rides and one small consumer, written
in Java and in Python. You create the `rides.completed` topic with 6 partitions yourself and write the
rides with the console producer: six rides, one on each partition. You run up to three copies of the
consumer as members of one group, `ride-billing`; each copy prints the partitions the group gives it,
every change to them, and the rides it reads. The lesson uses the lab to show how a group shares a
topic's partitions, what happens when a member joins or leaves, what the broker's two assignors
(`uniform` and `range`) do, and how the newer group protocol differs from the older one.

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
- Host ports 19234 and 19134 free, or change them in `.env`
- BROKA, if you want to read the cluster from its pages, for example from [`install/`](../../../install/)

The lab runs next to the earlier labs of the series without conflict: different project name,
different ports, different volume.

## Run

You need four terminals: one for each of the three members, and one for the commands.

1. Optional: copy the settings file and change the defaults. You need to do this on Linux (see
   [Connect BROKA](#connect-broka)).

   ```bash
   cp .env.example .env
   ```

2. Start the broker:

   ```bash
   docker compose up -d --wait
   ```

3. Create the topic, with six partitions:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 \
     --create --topic rides.completed --partitions 6 --replication-factor 1
   ```

   Then write the six rides. Each line of `rides.txt` is a key, a `|` and a value, and the console
   producer splits it there; the six keys land on six different partitions.

   ```bash
   docker compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:29092 \
     --topic rides.completed --reader-property parse.key=true --reader-property key.separator='|' < rides.txt
   ```

   Read them back with the console consumer, in a group of its own, `ride-audit`, to see which ride is on
   which partition:

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:29092 \
     --topic rides.completed --group ride-audit --from-beginning --max-messages 6 \
     --formatter-property print.partition=true --formatter-property print.key=true
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
   python group_consumer.py billing-1
   ```

   The first Maven run downloads the Kafka client and Maven's plugins, and `-q` keeps it silent while
   it does. The member prints `billing-1: assigned [0, 1, 2, 3, 4, 5]`, reads the six rides and waits
   for more.

5. Start a second member, `billing-2`, in a third terminal, from the lab's folder. In Java:

   ```bash
   cd java
   mvn -q compile exec:java -Dexec.args=billing-2
   ```

   or in Python:

   ```bash
   cd python
   . .venv/bin/activate
   python group_consumer.py billing-2
   ```

   `billing-1` prints `revoked` with three partitions, and `billing-2` prints `assigned` with the same
   three. Write the rides again from the first terminal, with the producer command of step 3: each member
   prints the rides of its own partitions.

   Then start a third member, `billing-3`, the same way in a fourth terminal, and wait until it prints
   `assigned` with two partition numbers, on one line or on two; in Java, its first `assigned []` does
   not count. Then write the rides once more: each of the three now has two partitions, and prints two
   rides.

6. In the first terminal, see the group as the broker sees it: each member with its partitions and
   epoch, then the group's assignor, state and epoch.

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --describe --group ride-billing --members --verbose
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --describe --group ride-billing --state --verbose
   ```

7. Stop `billing-2` with Ctrl+C. It gives its two partitions back as it closes, and the other two members
   take one each.

8. Stop the other two members with Ctrl+C too. Then start all three again, one after the other, each in
   the terminal it ran in, with `range` as a second argument, which asks the broker for its other
   assignor. In Java:

   ```bash
   mvn -q compile exec:java -Dexec.args="billing-1 range"
   ```

   or in Python:

   ```bash
   python group_consumer.py billing-1 range
   ```

   Start `billing-2` and `billing-3` the same way, and wait until each new member prints `assigned` with
   partition numbers before you start the next; in Java, its first `assigned []` does not count. No
   rides come this time: the group resumes at its committed offsets, and nothing new has been written.
   With `range`, each member ends up with two neighbouring partitions: 0 and 1, 2 and 3, or 4 and 5.

9. In the first terminal, list the groups with their type. `ride-billing` is on the newer consumer
   protocol. `ride-audit`, the console consumer's group, is on the older classic protocol; the notice the
   console consumer printed in step 3 is about that.

   ```bash
   docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:29092 \
     --list --type
   ```

   Stop the members with Ctrl+C.

## Two ports for clients

The broker listens for clients on two ports, and each one gives clients a different address to come
back to:

| Port | For | Address the broker gives back |
|---|---|---|
| 19234 | programs you run on this machine, such as the lab's consumer | `localhost:19234` |
| 19134 | clients in other containers, such as BROKA | `host.docker.internal:19134` |

The consumer connects to `localhost:19234`. If you change `KAFKA_HOST_PORT`, change that address in
the code too. Keep programs on your machine on 19234: port 19134 gives clients back
`host.docker.internal`, a name made for containers. Where your machine cannot resolve that name, as on
a Mac with Docker Desktop's default settings, a consumer on 19134 connects once and then reads nothing.

## Connect BROKA

Add a Kafka cluster in BROKA, from the cluster selector in the header (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-consumer-groups` |
| Bootstrap servers | `host.docker.internal:19134` on Docker Desktop, `<host-ip>:19134` on Linux |
| Authentication method | None |

Press **Test connection** before **Create connection**: it reports *OK* and how long the broker took to
answer. The new connection appears in the cluster list, and the Kafka pages read it from now on.

The broker gives clients on this port the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers
must be able to reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that IP in
the connection.

## What to look at

1. **Consumer Groups.** Kafka ▸ **Consumer Groups** lists `ride-billing` and `ride-audit` with their
   state, members and lag. Press **Refresh** after a member joins or leaves to read the list again.
2. **Which protocol.** Open a group: its subtitle names the protocol, *Consumer group · Consumer
   protocol* for `ride-billing` and *Consumer group · Classic protocol* for `ride-audit`.
3. **Epochs.** On `ride-billing`'s **Members** tab, the group epoch and the target epoch are above the
   table, and each member's row adds its own epoch, its number of target partitions, and whether it is
   still reconciling: the epochs and target assignment of step 6. A classic group has no target
   assignment, so `ride-audit` has none of these.
4. **Who holds what.** The **Topology** tab has one card per member, headed by its host and client id,
   holding the partitions it owns as chips: two on each card with three members, three after `billing-2`
   leaves.

## Clean up

```bash
docker compose down -v
```

## Lesson

[Consumer groups and partition assignment](https://broka.dev/learn/kafka/consumer-groups-and-partition-assignment)
