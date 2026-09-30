# Lab: Redis Streams pending entries

A Redis 8.10 server with one stream, `broka:orders`, and two consumer groups. In `fulfilment`, two
consumers took ten entries and never acknowledged them: the entries have been idle for six hours, and two
of them have been delivered five and six times. A third consumer keeps polling, acknowledges what it gets,
and then goes on asking a quiet stream. The other group, `analytics`, has read nothing, and an entry it had
not reached was deleted from the middle of the stream, so Redis cannot count its lag.

**Edition:** requires BROKA Commercial.

## Requirements

- Docker with Compose v2
- A running BROKA Commercial installation
- Host port 16379 free (change it with `REDIS_PORT` in `.env`)

## Run

1. Optionally copy the port setting:

   ```bash
   cp .env.example .env
   ```

2. Start Redis, seed it and start the polling consumer:

   ```bash
   docker compose up -d
   ```

3. Check what the seed built:

   ```bash
   docker compose logs seed
   docker compose exec redis redis-cli XPENDING broka:orders fulfilment - + 20
   docker compose exec redis redis-cli XINFO GROUPS broka:orders
   ```

4. To start over after claiming or acknowledging entries:

   ```bash
   ./scripts/reset.sh
   ```

The server has no password and no ACL users. It is for a local lab only.

## Connect BROKA

Add a Redis connection with:

| Field | Value |
|---|---|
| Host | `host.docker.internal` (Docker Desktop) or the host's IP address (Linux) |
| Port | `16379` |
| Username / Password | leave empty |
| TLS | off |

## What to look at

1. **Redis > Pending Messages**, stream `broka:orders`, group `fulfilment`: ten pending entries held by
   `picker-1` and `picker-2`, five each, all idle for about six hours. Two rows are marked, at five and
   six deliveries. The rest were delivered once.
2. **Redis > Streams > `broka:orders` > Consumer groups**: `picker-1` and `picker-2` hold the pending
   entries, and their idle and inactive times grow from the moment the seed ran. `picker-3` is idle for a
   few seconds at most while its inactive time grows: it keeps asking and is given nothing.
3. Back on the pending list, tick a few entries and **Claim** them to a new owner such as `recovery-1`,
   with the minimum idle time left at 60 seconds. The entries have been idle for hours, so all of them move
   and their delivery counts go up by one. Try **Sweep to a consumer** and **Return to group** as well;
   this server is Redis 8.10, so both are available.
4. **Acknowledge** an entry. It leaves the group's pending list and stays in the stream, which the
   stream's entries still show. **Ack & delete** removes it from both.
5. **Redis > Consumer Groups**: `analytics` has no consumers, nothing pending and its lag shown as
   `unknown`. `fulfilment` shows a lag of 28 right after seeding and 0 once `picker-3` has caught up.
   **Set position** on a group's row in the stream's Consumer groups tab moves where it reads from and
   leaves the pending list as it is.
6. The stream's **Live** tab follows new entries without joining a group: the pending counts do not
   change while it runs. Add one to watch it arrive:

   ```bash
   docker compose exec redis redis-cli XADD broka:orders '*' order ord-41 amount 287 status new
   ```

7. **Trim** the stream from its detail page: on Redis 8.2 and later the dialog asks what the consumer
   groups keep of the entries it removes.

## Clean up

```bash
docker compose down -v
```

## Guide

[Redis Streams in production: the pending entries list](https://broka.dev/guides/redis-pending-entries)
