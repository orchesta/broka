# Lab: what a tamper-evident audit trail buys you

The install stack from [`install/`](../../install/) with audit forwarding to files switched on, and a
single Kafka broker on the same network to make changes on. You make a few changes in BROKA, send one
request without a reason from a script, then check the trail three ways: with **Verify integrity**, with
the OpenAuditModel reference CLI over an evidence pack, and with the same CLI over the forwarded copy.
Last, a script edits one record directly in the database, and the three checks no longer agree.

**Edition:** Community

## Requirements

- Docker with Compose v2.24.4 or later (for `!override`)
- `bash` and `openssl`
- Host port 3010 free, or set `LAB_HTTP_PORT` in `install/.env`

## Run

1. Fill in the install secrets. This creates `install/.env` from `.env.example` if it does not exist and
   generates the four secrets where they are empty. Values already set are kept.

   ```bash
   bash scripts/gen-secrets.sh
   ```

2. Start the install stack with the lab on top:

   ```bash
   docker compose -f ../../install/compose.yml -f compose.yml up -d
   ```

   `kafka-seed` creates `orders.v2`, with the stopped consumer group `order-service` 400 records behind,
   and `scratch.tmp`.

3. Open http://localhost:3010 and create the first administrator.

The override names the project `broka-lab-audit-trail`, so it starts a separate stack with its own database
and leaves a running `install/` stack alone.

## Connect BROKA

Add a Kafka cluster in BROKA (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-audit` |
| Bootstrap servers | `kafka:29092` |
| Authentication method | None |

The broker runs in the same Compose project as BROKA, so BROKA reaches it by its service name.

## What to look at

1. **Make changes that need a reason.** Delete the topic `scratch.tmp`, then open the group
   `order-service`, **Reset Offset** to **Latest** and **Apply reset**. Both ask for a reason in every
   environment; type a sentence each time.
2. **A refusal from a script.** In **Profile ▸ API tokens**, create a token, then:

   ```bash
   bash scripts/refuse.sh <token>
   ```

   The script asks BROKA to delete `order-service` without a reason and prints the answer: HTTP 400,
   `REASON_REQUIRED`. Nothing is deleted.
3. **Operations ▸ Audit Logs.** `broker.topic.delete` and `broker.offset.reset` are there with your
   reasons, and `broker.consumer-group.delete` is there as **Blocked**, with no reason. Open an entry: the
   sealed event is shown as JSON. An entry newer than the last sealing pass, about 30 seconds, reads
   *Event (not sealed yet)*.
4. **Verify integrity** over today: intact, with the number of links checked and of events too recent to
   be sealed.
5. **Export ▸ Evidence pack (zip)**, from today to tomorrow. Save it into this lab's `evidence/` folder,
   then check it without BROKA:

   ```bash
   bash scripts/verify.sh <pack>.zip
   ```

   The script runs `@openauditmodel/cli` 1.0.0 in a Node.js container: `verify-chain` over the pack's
   events and `verify-checkpoint` against the pack's `checkpoint.json`. Both pass. The first run downloads
   the CLI from npm.
6. **The forwarded copy.** BROKA appends every sealed event to one file a day in a volume of its own:

   ```bash
   bash scripts/verify-forwarded.sh
   ```

   It lists the files and runs `verify-chain` over them. It passes.
7. **Tamper.** Rewrite the reason on the newest event that has one, directly in the database:

   ```bash
   bash scripts/tamper.sh
   ```

   - The audit log now shows the new reason on that event.
   - **Verify integrity** reports the trail altered, at that event.
   - `bash scripts/verify-forwarded.sh` still passes: the forwarded copy holds the event as it was sealed,
     and the database edit did not reach it.
   - Export a second evidence pack the same way and run `bash scripts/verify.sh <second>.zip <first>.zip`:
     `verify-chain` reports the altered event, and the second pack's events no longer arrive at the first
     pack's checkpoint.
8. **Settings ▸ Security.** The audit retention is at most six months. Shortening it asks for a reason and
   is recorded.

The guide's sharpest limit is not reproduced: someone who can write the database can also recompute every
seal after an edit, and then **Verify integrity** passes. Only the forwarded copy and a checkpoint kept
elsewhere would show it. Recording reads, the evidence pack's access report and forwarding to Kafka or
RabbitMQ are Commercial and not part of this lab.

## Clean up

```bash
docker compose -f ../../install/compose.yml -f compose.yml down -v
```

This removes the lab's database, the forwarded copy and the broker. `install/.env` stays; delete it if you
created it only for this lab. Evidence packs you saved stay in `evidence/`.

## Guide

[What a tamper-evident audit trail actually buys you](https://broka.dev/guides/tamper-evident-audit-trail)
