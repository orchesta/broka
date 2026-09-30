# Lab: queue backlogs

A single RabbitMQ node with one virtual host, `shop`, where a queue is growing because its only consumer
cannot keep up. A publisher sends 30 messages a second to `orders.audit`; one consumer with a prefetch of 20
acknowledges 5 a second, so it always holds 20 unacknowledged messages and the ready count climbs by about
25 a second. Two queues get their dead-letter target in different ways: `orders.audit` from a policy, and
`payments.charge` from its own argument while the same policy also matches it. A dead-letter queue holds
seven rejected payments to replay, and an empty spare queue is there to move a backlog into.

**Edition:** requires BROKA Commercial.

## Requirements

- Docker with Compose v2
- Host ports 15710 (management) and 15711 (AMQP) free, or change them in `.env`

## Run

1. Optionally copy the environment file to change the demo password, the ports or the rates:

   ```bash
   cp .env.example .env
   ```

2. Start the lab:

   ```bash
   docker compose up -d
   ```

   `rabbitmq` starts with the shovel plugin enabled, which **Move messages** needs. When it is healthy,
   `seed` imports [`rabbitmq/definitions.json`](rabbitmq/definitions.json), empties the queues, publishes 12
   messages to `payments.charge` and rejects 7 of them without requeueing. `publisher` and `consumer` then
   start and run until they are stopped.

3. Check what the seed did and watch the backlog grow:

   ```bash
   docker compose logs seed
   docker compose exec rabbitmq rabbitmqctl list_queues -p shop name messages_ready messages_unacknowledged consumers policy
   docker compose exec rabbitmq rabbitmqctl list_channels name prefetch_count messages_unacknowledged
   ```

To return the queues to their seeded state, run `docker compose run --rm seed`. To stop the load, run
`docker compose stop publisher consumer`.

## The setup

| Queue | Dead-letter target | Holds |
|---|---|---|
| `orders.audit` | `orders.dlx`, from policy `dead-letter-default` | a growing backlog, 20 of it unacknowledged |
| `orders.audit.overflow` | none | nothing; a destination for **Move messages** |
| `orders.dlq` | none | nothing until something is dead-lettered through `orders.dlx` |
| `payments.charge` | `payments.dlx`, from its own `x-dead-letter-exchange` argument; the policy names `orders.dlx` and loses | 5 messages |
| `payments.dlq` | none | the 7 messages rejected from `payments.charge` |

| Exchange | Type | Routes to |
|---|---|---|
| `orders` | topic | `orders.audit` (`order.#`) |
| `orders.dlx` | topic | `orders.dlq` (`#`) |
| `payments` | topic | `payments.charge` (`payment.charge`) |
| `payments.dlx` | topic | `payments.dlq` (`#`) |

The publisher and the consumer are RabbitMQ PerfTest. The publisher's connection is named
`perf-test-producer-0` and the consumer's `perf-test-consumer-0`; each also keeps an idle
`perf-test-configuration-0` connection open. The message bodies are generated JSON.

## Connect BROKA

Add a RabbitMQ connection with:

| Field | Value |
|---|---|
| Management URL | `http://host.docker.internal:15710` |
| AMQP host | `host.docker.internal` |
| AMQP port | `15711` |
| vhost | `shop` |
| Authentication method | Password |
| Username | `broka` |
| Password | `broka-lab-pass` (or `RABBITMQ_PASSWORD` from `.env`) |

`host.docker.internal` works when BROKA runs from [`install/`](../../install/) on Docker Desktop. On Linux,
use the host's IP address instead.

## What to look at

1. **Two numbers, not one. RabbitMQ ▸ Queues**, vhost `shop`. `orders.audit` has a **Ready** count that
   grows each time you read it and an **Unacked** count that stays at 20, with one consumer. **In / out**
   reads about 30 in and 5 out: a backlog being worked more slowly than it grows. `payments.dlq` has 7
   ready and no consumer.
2. **Rule out the cluster. RabbitMQ ▸ Overview.** There is no resource alarm, so the broker is accepting
   publishes and the backlog is not a blocked publisher.
3. **Then the consumers.** On the Queues list, the **Consumers** cell of `orders.audit` reads close to
   `0% utilised`: with messages ready, the broker can almost never hand one straight to the consumer,
   because its prefetch is full.
   - **RabbitMQ ▸ Channels**: the consumer's channel shows a prefetch of 20 beside 20 unacknowledged. The
     screen states both and flags neither. The publisher's channel has no consumers.
   - **RabbitMQ ▸ Consumers**: the consumer on `orders.audit` has **Ack mode** `manual` and a **Prefetch**
     of 20.
   - **RabbitMQ ▸ Connections**: **Close** `perf-test-consumer-0` with a reason. The 20 unacknowledged
     messages go back to the queue as ready. PerfTest reconnects on its own a few seconds later and takes
     another 20.
4. **Read the direction.** Run `docker compose stop consumer`. `orders.audit` now has no consumers, its
   utilisation is no longer shown, and **In / out** is coloured: messages arrive and none leave. Read the
   Ready count twice with the time in between; that is the trend. Run `docker compose start consumer` to
   bring it back.
5. **Where dead letters go. RabbitMQ ▸ Queues ▸ `orders.audit` ▸ Overview.** **Dead-letter exchange**
   reads `orders.dlx (from policy dead-letter-default)`, and **Policy** links `dead-letter-default`. On
   `payments.charge` the same row reads `payments.dlx (set on the queue, which outranks policy
   dead-letter-default)`: the policy matches this queue too, and the queue's own argument wins. That is
   why the seed's rejected payments are in `payments.dlq` and not in `orders.dlq`. On the Queues list,
   hover the **Dead-letter** cell of either queue for the same sentence.
6. **Dead-letter by reading.** On `orders.audit`, open **Messages**, choose **Dead-letter (reject)** and
   read a few messages. They leave the queue and arrive in `orders.dlq`, through the policy's target.
7. **Divert the backlog.** On `orders.audit`, **Move messages**, **Move into** *A queue*, destination
   `orders.audit.overflow`, with a reason. The ready messages the queue held when the move started go to
   `orders.audit.overflow`; `orders.audit` keeps growing from the publisher. While the move runs, its
   shovel is listed under **RabbitMQ ▸ Shovels & Federation**, and it removes itself when it is done.
8. **Replay a dead-letter queue.** On `payments.dlq`, **Move messages**, **Move into** *An exchange*,
   destination `payments`, routing key left blank. Each message is republished under the routing key it
   was dead-lettered with, `payment.charge`, so `payments.charge` goes back to 12.
9. **Change a policy, not a queue.** **RabbitMQ ▸ Policies ▸ `dead-letter-default` ▸ Edit** changes the
   target for `orders.audit` at once. It does not change `payments.charge`, whose argument was fixed
   when the queue was declared.
10. **Purge last.** **Purge** on `orders.audit` discards its ready messages; the 20 the consumer holds
    stay. The confirmation names how many, and although the queue has a dead-letter target, purged
    messages do not reach it: `orders.dlq` does not change.

## Kafka and Redis

The guide reads the same two numbers on Kafka and Redis Streams. This lab does not start either; use the
[consumer lag](../consumer-lag/) lab for a Kafka group with growing lag and a stopped group to reset, and
the [Redis pending entries](../redis-pending/) lab for a pending list, `unknown` lag, claims and
**Set position**.

## Clean up

```bash
docker compose down -v
```

## Guide

[Queue backlogs: drain, divert, or let it run](https://broka.dev/guides/queue-backlogs)
