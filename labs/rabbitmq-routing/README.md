# Lab: RabbitMQ routing

A single RabbitMQ node with one virtual host, `shop`, whose exchange graph has every path a published
message can take: a topic exchange with bindings to queues, an exchange-to-exchange hop into an archive
queue, an alternate exchange catching unroutable messages, an alternate exchange that names an exchange
that does not exist, a dead-letter exchange and queue, and a headers exchange with a queue that refuses
publishes once full. A background publisher keeps sending messages that route and messages that route
nowhere, so the unroutable path shows up as a rate.

**Edition:** requires BROKA Commercial.

## Requirements

- Docker with Compose v2
- Host ports 15701 (management) and 15702 (AMQP) free, or change them in `.env`

## Run

1. Optionally copy the environment file to change the demo password or ports:

   ```bash
   cp .env.example .env
   ```

2. Start the lab:

   ```bash
   docker compose up -d
   ```

   `rabbitmq` starts first. When it is healthy, `seed` imports [`rabbitmq/definitions.json`](rabbitmq/definitions.json),
   empties the queues and publishes a fixed set of messages. `load` then publishes four messages a second
   until it is stopped.

3. Check what the seed did:

   ```bash
   docker compose logs seed
   docker compose exec rabbitmq rabbitmqctl list_bindings -p shop
   docker compose exec rabbitmq rabbitmqctl list_queues -p shop name messages
   ```

To return the queues to their seeded state, run `docker compose run --rm seed`. To stop the background
publisher, run `docker compose stop load`.

## The graph

| Exchange | Type | Routes to |
|---|---|---|
| `orders` | topic, alternate exchange `orders.unrouted` | `orders.processing` (`order.created`), `orders.audit` (`order.#`), `orders.audit.fanout` (`order.#`) |
| `orders.audit.fanout` | fanout, internal | `orders.audit.archive` |
| `orders.unrouted` | fanout | `orders.unrouted` |
| `orders.dlx` | topic | `orders.dlq` (`#`) |
| `invoices` | direct, alternate exchange `invoices.unrouted` (not declared) | nothing |
| `shipments` | headers | `shipments.express` (`x-match: all`, `region = eu`, `priority = 3` as a number) |

`orders.processing` holds at most 20 messages and dead-letters the oldest to `orders.dlx` when a new one
arrives. `shipments.express` holds at most 5 and rejects publishes beyond that.

The background publisher sends, every second:

| Exchange | Routing key | Outcome |
|---|---|---|
| `orders` | `order.created` | three queues, one of them through the fanout hop |
| `orders` | `order.shipped` | `orders.audit` and, through the hop, `orders.audit.archive` |
| `orders` | `orders.created` | matches no binding; caught by `orders.unrouted` |
| `invoices` | `invoice.paid` | matches no binding; the alternate exchange does not exist, so it is discarded |

## Connect BROKA

Add a RabbitMQ connection with:

| Field | Value |
|---|---|
| Management URL | `http://host.docker.internal:15701` |
| AMQP host | `host.docker.internal` |
| AMQP port | `15702` |
| vhost | `shop` |
| Authentication method | Password |
| Username | `broka` |
| Password | `broka-lab-pass` (or `RABBITMQ_PASSWORD` from `.env`) |

`host.docker.internal` works when BROKA runs from [`install/`](../../install/) on Docker Desktop. On Linux,
use the host's IP address instead.

## What to look at

1. **RabbitMQ ▸ Overview.** The **Unroutable** rate is above zero: the `invoices` messages the broker
   returns because nothing took them.
2. **RabbitMQ ▸ Exchanges**, vhost `shop`. `orders` receives messages and routes them onward. `invoices`
   receives messages and routes none, and its **In / out** pair is marked. Its **Alternate** column names
   `invoices.unrouted`, which does not exist. `orders.audit.fanout` carries the internal flag.
3. **RabbitMQ ▸ Routing**, vhost `shop`, **Publish through** `orders`. Three queues are reachable;
   `orders.audit.archive` sits a column further right because the message passes through
   `orders.audit.fanout`, whose arrow carries no label. The `shipments` arrow reads `headers`.
4. **Check the key against the type.** `orders.created` is one word off the `order.#` pattern, which is
   why those messages are in `orders.unrouted` and not in `orders.audit`. To fix a missing route, open
   **Bindings** in the exchange's row menu and add a **New binding**.
5. **Unroutable is not dead-lettered.** `orders.dlq` fills because `orders.processing` is full and drops
   its oldest message, not because of a routing failure. `orders.unrouted` fills with the messages no
   binding matched.
6. **Publish, and read the answer.** From the row menu of an exchange, **Publish**:
   - to `orders` with key `order.created`: **Confirmed**;
   - to `invoices` with any key: **Returned**, with the broker's reply code and text;
   - to `shipments` with headers `region` = `eu` (string) and `priority` = `3` (a number): **Refused**,
     because `shipments.express` is full. Give `priority` as the string `"3"` and it is **Returned** instead;
     the binding matches the number only;
   - to `orders.audit.fanout`: the dialog says the exchange is internal and does not send.
7. **RabbitMQ ▸ Queues ▸ `orders.audit.archive` ▸ Bindings.** It lists the source exchange
   `orders.audit.fanout` with no routing key; `shipments.express` lists `shipments` as matched on headers.

## Clean up

```bash
docker compose down -v
```

## Guide

[Reading a routing problem from the bindings out](https://broka.dev/guides/routing-from-the-bindings-out)
