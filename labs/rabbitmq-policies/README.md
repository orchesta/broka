# Lab: only one RabbitMQ policy applies

A single RabbitMQ node with one virtual host, `shop`, whose queues are matched by more than one policy
each. `orders.audit` matches two queue policies and is governed by the higher-priority one alone, which
sets no TTL. `orders.processing`, a quorum queue, is governed by the lower one and has an operator policy
on top with a stricter TTL. The stream `orders.events` matches a policy that sets nothing a stream
accepts, so nothing governs it. One policy's pattern is unanchored and catches a queue it was not written
for, two policies tie on priority over `payments.charge`, and `inventory.sync` matches nothing.

**Edition:** requires BROKA Commercial.

## Requirements

- Docker with Compose v2
- BROKA Commercial running, for example from [`install/`](../../install/) with the Commercial images
- Host ports 15730 (management) and 15731 (AMQP) free, or change them in `.env`

## Run

1. Optional: copy the settings file to change the demo password or the ports:

   ```bash
   cp .env.example .env
   ```

2. Start the lab:

   ```bash
   docker compose up -d
   ```

   When `rabbitmq` is healthy, `seed` imports [`rabbitmq/definitions.json`](rabbitmq/definitions.json) and
   adds the operator policy.

3. Check which policy the broker applied to each queue:

   ```bash
   docker compose logs seed
   docker compose exec rabbitmq rabbitmqctl list_queues -p shop name type policy operator_policy
   ```

## The policies

| Policy | Kind | Pattern | Applies to | Priority | Definition |
|---|---|---|---|---|---|
| `orders-alternate` | user | `^orders$` | exchanges | 20 | `alternate-exchange: orders.unrouted` |
| `audit-retention` | user | `^orders\.audit$` | classic queues | 10 | `dead-letter-exchange: orders.dlx` |
| `payments-ttl` | user | `^payments\.` | queues | 4 | `message-ttl: 600000` |
| `payments-limit` | user | `\.charge$` | queues | 4 | `max-length: 2000` |
| `retry-cap` | user | `retry` | queues | 3 | `max-length: 5000` |
| `audit-fallback` | user | `^orders\.` | queues | 1 | `message-ttl: 3600000` |
| `ttl-ceiling` | operator | `^orders\.processing$` | queues | 0 | `message-ttl: 600000` |

| Queue | Type | Matches | In force |
|---|---|---|---|
| `orders.audit` | classic | `audit-retention`, `audit-fallback` | `audit-retention`; no TTL, because the fallback's hour is not merged in |
| `orders.processing` | quorum | `audit-fallback`, operator `ttl-ceiling` | `audit-fallback`, with the operator policy's 10 minutes holding over its hour |
| `orders.events` | stream | `audit-fallback` by pattern and scope | nothing: a stream does not take `message-ttl` |
| `retry.orders.dlq` | classic | `retry-cap` | `retry-cap` |
| `carts.retry` | classic | `retry-cap`, because `retry` is not anchored | `retry-cap` |
| `payments.charge` | classic | `payments-ttl`, `payments-limit`, both at priority 4 | one of the two; which one is not defined |
| `inventory.sync` | classic | nothing | nothing |

## Connect BROKA

Add a RabbitMQ cluster in BROKA:

| Field | Value |
|---|---|
| Name | `lab-rabbitmq-policies` |
| Management URL | `http://host.docker.internal:15730` |
| AMQP host | `host.docker.internal` |
| AMQP port | `15731` |
| vhost | `shop` |
| Authentication method | Password |
| Username | `broka` |
| Password | `broka-lab-pass` (or `RABBITMQ_PASSWORD` from `.env`) |

`host.docker.internal` works when BROKA runs on Docker Desktop. On Linux, use the host's IP address.

## What to look at

1. **RabbitMQ ▸ Policies**, vhost `shop`. The user policies are listed by priority, highest first.
   `retry-cap` and `payments-limit` carry the **unanchored** badge. The operator policy `ttl-ceiling` is in
   its own card.
2. **Queues ▸ `orders.audit` ▸ Overview.** **Policy** reads `audit-retention` and **Operator policy** a dash.
   Open the policy name: **Which policy applies?** names `audit-retention` in force and lists
   `audit-fallback` under **Also matched, and does not apply**, at a lower priority.
3. **`orders.processing`.** **Policy** reads `audit-fallback` and **Operator policy** `ttl-ceiling`; the panel
   shows the operator policy apart, and the stricter of the two TTLs holds.
4. **`orders.events`.** The broker reports no policy on the stream, although `audit-fallback`'s pattern and
   scope match it.
5. **`carts.retry`** is governed by `retry-cap`, a policy meant for `retry.` queues. In **New policy**, type
   a pattern without `^` and the hint changes to say it matches any name that contains it.
6. **`payments.charge`.** The two priority-4 policies tie; the panel says which one the broker reports and
   that the choice between them is not defined.
7. **Which policy applies?** from the Policies page, for `inventory.sync` as a classic queue: nothing
   governs it. Ask about a name that does not exist, such as `orders.new`: the broker has no answer, and
   the panel lists the matching policies by priority without claiming one is in force.
8. **Delete `audit-retention`** with a reason. The confirmation says every object it governed falls back
   to the next match. `orders.audit` is then governed by `audit-fallback`: it gains the one-hour TTL and
   loses its dead-letter exchange. Run `docker compose run --rm seed` to restore it.
9. **New policy** with `ha-mode` in its definition is refused: classic queue mirroring was removed in
   RabbitMQ 4.0.

## Clean up

```bash
docker compose down -v
```

## Guide

[Policies in RabbitMQ: only one applies](https://broka.dev/guides/rabbitmq-policies-only-one-applies)
