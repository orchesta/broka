# Lab: one permission model

The broker-native half of a unified access model. A single-node Kafka cluster runs SASL/PLAIN with the
`StandardAuthorizer` and no access for principals without ACLs. BROKA connects as the super-user `admin`,
and two application principals hold ACLs scoped to their own topics and group: `svc-orders-reader`
reads every `orders.` topic through the group `orders-reader`, and `svc-checkout` writes to
`orders.events` only. A RabbitMQ node has a `commerce` virtual host with three application users:
`svc-payments` may configure, write and read everything in it, `svc-orders` is limited to names starting
`orders.` and to `order.eu.` routing keys on the `orders.events` exchange, and `svc-denied` holds empty
patterns, which deny everything. The BROKA side of the model, teams, roles and environments, is set up
in BROKA itself.

**Edition:** the Kafka part works with Community. The RabbitMQ part requires BROKA Commercial.

## Requirements

- Docker with Compose v2
- BROKA running, for example from [`install/`](../../install/)
- Host ports 19100 (Kafka), 15720 (RabbitMQ management) and 15721 (AMQP) free, or change them in `.env`

## Run

1. Optional: copy the settings file to change the demo passwords or ports. You need to do this on Linux
   (see [Connect BROKA](#connect-broka)).

   ```bash
   cp .env.example .env
   ```

2. Start both brokers and their seed jobs:

   ```bash
   docker compose up -d
   ```

   To start only one of them, name its seed job: `docker compose up -d kafka-seed` or
   `docker compose up -d rabbitmq-seed`.

   `kafka-seed` creates `orders.events`, `orders.returns` and `payments.events` and the ACLs. It then
   writes 50 records to `orders.events` as `svc-checkout` and reads them as `svc-orders-reader`, so the
   group `orders-reader` has committed offsets. Finally it tries two writes the ACLs do not allow.
   `rabbitmq-seed` creates the `commerce` virtual host, the `orders.events` and `payments.events`
   exchanges with one bound queue each, the three users and their permissions.

3. Check what the seed jobs did:

   ```bash
   docker compose logs kafka-seed rabbitmq-seed
   docker compose exec rabbitmq rabbitmqctl list_permissions -p commerce
   docker compose exec rabbitmq rabbitmqctl list_topic_permissions -p commerce
   ```

   The Kafka log ends with both refused writes, `svc-orders-reader writing to orders.events: denied` and
   `svc-checkout writing to payments.events: denied`, followed by the cluster's ACLs.

## Set up BROKA

Sign in as an administrator and follow the guide's first two steps:

1. **Settings ▸ Environments ▸ Add environment:** create `Development`, `Staging` and `Production`.
2. Edit `Production` and set **Write policy** to **Guarded — every write asks for a reason**.
3. **Settings ▸ Users:** create a user to try the team's access with.
4. **Settings ▸ Teams ▸ Create team:** create `Payments platform`, and add that user from the row's
   **Members**.
5. From the team's **Roles**, assign **Viewer** with the scope **Global (everywhere)**, then **Operator**
   with the scope **Environment**, once for `Development` and once for `Staging`.

## Connect BROKA

### Kafka (Community)

Add a Kafka cluster in BROKA:

| Field | Value |
|---|---|
| Name | `lab-permission-model` |
| Environment | `Staging` |
| Bootstrap servers | `host.docker.internal:19100` on Docker Desktop, `<host-ip>:19100` on Linux |
| Authentication method | SASL |
| Security protocol | `SASL_PLAINTEXT` |
| SASL mechanism | `PLAIN` |
| Username | `admin` |
| Password | `admin-lab-pass` (or `KAFKA_ADMIN_PASSWORD` from `.env`) |

The broker gives clients the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers must be able to
reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that IP in
the connection.

### RabbitMQ (requires BROKA Commercial)

Add a RabbitMQ connection:

| Field | Value |
|---|---|
| Name | `lab-permission-model` |
| Environment | `Production` |
| Management URL | `http://host.docker.internal:15720` |
| AMQP host | `host.docker.internal` |
| AMQP port | `15721` |
| vhost | `commerce` |
| Authentication method | Password |
| Username | `broka` |
| Password | `broka-lab-pass` (or `RABBITMQ_PASSWORD` from `.env`) |

On Linux, use the host's IP address instead of `host.docker.internal`.

## What to look at

### Kafka (Community)

1. **Kafka ▸ Service Accounts.** The list shows `svc-checkout` and `svc-orders-reader`, the principals
   named in the cluster's ACLs. `admin` is not there: it is a super-user and holds no ACLs.
2. **Open `svc-orders-reader`.** The **Access** tab has two Allow rules: the topic `orders.` with a
   **Prefix** badge, for Read and Describe, and the consumer group `orders-reader`, for Read.
   `svc-checkout` has one rule: the topic `orders.events`, for Write and Describe.
3. **Kafka ▸ Topics ▸ `orders.returns` ▸ ACL.** The prefix rule for `svc-orders-reader` is listed even
   though it does not name the topic.
4. **Change a rule as the team member.** Sign in as the user you created. The connection is in
   `Staging`, where the team is Operator, so **Add rule** and **Apply changes** work, and the change
   reaches the cluster. The console's permission and the broker's ACLs are separate checks: nothing
   done in BROKA's roles is written to Kafka.

### RabbitMQ (requires BROKA Commercial)

1. **RabbitMQ ▸ Users & Permissions**, vhost `commerce`. `broka` carries the administrator tag.
   `svc-payments` has `.*` for configure, write and read, and `svc-orders` has `^orders\.` for all
   three. `svc-denied` shows **denies all** three times: an empty pattern matches nothing. The three
   application users' tags read **none**: they are applications, not people who use a console.
2. **Topic permissions.** The card below the users lists `svc-orders` on the exchange `orders.events`,
   with write and read limited to `^order\.eu\.`. The broker therefore refuses a publish from `svc-orders`
   with the routing key `order.us.created`, even though the exchange name matches its permission.
3. **The guarded environment.** As the administrator, open **Permissions** on `svc-orders` and save:
   the connection is in `Production`, so the write asks for a reason first. As the team member, who is
   only Viewer in `Production`, the users and permissions are readable but cannot be changed.

### Both

**Operations ▸ Access Review** (Commercial) resolves the team member's access and shows what conferred
each permission: Viewer everywhere and Operator in `Development` and `Staging`, both through the team. The
**audit log** has the ACL and permission changes made above, with the environment each one happened in;
the reads are recorded in Commercial.

## Clean up

```bash
docker compose down -v
```

## Guide

[Operating every broker with one permission model](https://broka.dev/guides/one-permission-model)
