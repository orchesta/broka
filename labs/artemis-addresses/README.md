# Lab: reading Artemis from the address down

A single Apache Artemis 2.57 broker with addresses of both routing types and every place a message can
end up. `orders` is anycast with three queues: two share its messages and one takes only `tenant = 'acme'`.
`events` is multicast, so each of its enabled queues gets a copy; its third queue is disabled and gets
none. A divert copies its `order.created` events to `analytics`. Messages sent to `notifications` match no queue and are counted as
unrouted. A divert that moves takes everything sent to `invoices` after the first five messages, so
`invoices.mailer` stopped receiving. `payments.settlement` holds five scheduled messages, `orders.billing`
is paused and `telemetry` pages to disk. Two STOMP consumers stay attached: one holds all 30 messages of
`shipments.dispatch` in flight across three message groups, the other has a selector that matches none of
the 20 messages on `returns.inbound`. The dead-letter queue holds failures from `orders`, `payments` and
`events`.

**Edition:** requires BROKA Commercial.

## Requirements

- Docker with Compose v2
- BROKA Commercial running, for example from [`install/`](../../install/) with the Commercial images
- Host port 18161 free, or change it in `.env`

## Run

1. Optional: copy the settings file to change the demo password or the port:

   ```bash
   cp .env.example .env
   ```

2. Start the broker, the seed jobs and the two consumers:

   ```bash
   docker compose up -d
   ```

   `seed` creates the addresses, queues and diverts over Jolokia and sends the messages. `schedule` sends
   the five scheduled payments over STOMP. `dispatch-worker` and `returns-worker` then subscribe.

3. Check what the seed did:

   ```bash
   docker compose logs seed schedule
   ```

   The seed ends with the message count of each queue.

To return every queue to its seeded state, run `bash scripts/reset.sh`.

## The setup

| Address | Routing type | Queues | What it shows |
|---|---|---|---|
| `orders` | anycast | `orders.fulfilment`, `orders.billing` (paused), `orders.acme` (filter `tenant = 'acme'`) | 12 orders shared out between the queues whose filter accepts them |
| `events` | multicast | `events.audit`, `events.search`, `events.legacy` (disabled) | 2 events, a copy in each enabled queue, none in the disabled one |
| `analytics` | anycast | `analytics.ingest` | the copies made by the divert `events-to-analytics` |
| `notifications` | multicast | none | 3 unrouted messages |
| `invoices` | anycast | `invoices.mailer` | 5 messages from before the divert `invoices-hold` |
| `invoices.held` | anycast | `invoices.held` | the 8 invoices the divert moved |
| `payments` | anycast | `payments.settlement` | 5 scheduled messages; its own delivery-attempt limit of 3 |
| `shipments` | anycast | `shipments.dispatch` | 30 messages in 3 groups, all in flight with `dispatch-worker` |
| `returns` | anycast | `returns.inbound` | 20 messages, `carrier = 'ups'`; `returns-worker` selects `carrier = 'dhl'` |
| `telemetry` | multicast | `telemetry.raw` | 150 messages of 1 KB over a 64 KB address limit, so it pages |
| `DLQ` | anycast | `DLQ` | 14 failures from `orders`, 4 from `payments`, 2 from `events` |

## Connect BROKA

Add an Apache Artemis broker in BROKA:

| Field | Value |
|---|---|
| Name | `lab-artemis` |
| Jolokia URL | `http://host.docker.internal:18161/console/jolokia` |
| Username | `broka` |
| Password | `broka-lab-pass` (or `ARTEMIS_PASSWORD` from `.env`) |

`host.docker.internal` works when BROKA runs on Docker Desktop. On Linux, use the host's IP address.

## What to look at

1. **Addresses.** `orders` (anycast) and `events` (multicast) side by side: 12 orders held across the
   `orders` queues, 2 events held twice under `events`. `notifications` has no queue and an **Unrouted**
   count of 3, coloured. `telemetry` carries the **paging** badge.
2. **Overview ▸ Resources** shows address memory and disk usage against the limits that would block
   producers.
3. **Queues.** `orders.acme` shows its **Filter**. `payments.settlement` has 5 under **Scheduled**.
   `shipments.dispatch` has all 30 under **Delivering**. `orders.billing` is paused and `events.legacy` is
   disabled; open `events.legacy` for its banner.
4. **Diverts.** `invoices-hold` reads **moves**, `events-to-analytics` **copies**. `invoices.mailer` has
   kept its 5 messages and gets nothing new; send to `invoices` and the message lands in `invoices.held`.
   Artemis counts the 8 moved invoices as unrouted on `invoices`, so its **Unrouted** is not zero either.
5. **`payments.settlement` ▸ Messages** browses as empty. **Scheduled** lists the five payments with the
   day each is due. **Deliver now** on one asks for a reason and moves it to the waiting messages.
6. **`shipments.dispatch` ▸ In flight** lists the 30 messages held by `dispatch-worker`. **Groups** shows
   `customer-1`, `customer-2` and `customer-3` pinned to it; **Unpin** frees one.
7. **Consumers.** `returns-worker` carries the selector `carrier = 'dhl'`, so `returns.inbound` keeps its 20
   messages with one consumer attached. **Close** `dispatch-worker`'s consumer: its 30 messages return to
   `shipments.dispatch`, and the STOMP connection stays open. Run `docker compose restart dispatch-worker`
   to bring it back.
8. **`DLQ` ▸ Messages ▸ Count by original address**: `orders` 14, `payments` 4, `events` 2. Choose **Retry to
   the original address** with a selector such as `poison = 'true'`, or **Move to another queue** with a
   count to try a few first. Retrying by selector needs Artemis 2.50 or later; this broker is 2.57.
9. **Address settings** for `payments` shows the delivery-attempt limit of 3 set for that address; for an
   address with no override it reads what it inherits.
10. **`orders.fulfilment` ▸ Counters** charts the broker's own samples. The seed switched message
    counters on, and the chart fills as the broker samples. The switch does not survive a broker restart;
    run `bash scripts/reset.sh` after one.
11. **Purge** a queue and check `DLQ`: purged messages are not dead-lettered.

The guide's **Orphaned** consumer status is not reproduced here: it needs a session that ended while its
consumer stayed registered, which a lab cannot produce on demand.

## Clean up

```bash
docker compose down -v
```

## Guide

[Where an Artemis message went: reading from the address down](https://broka.dev/guides/artemis-from-the-address-down)
