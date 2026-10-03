# Lab: Schema Registry without guesswork

A single-node Kafka cluster with a Confluent Schema Registry whose global compatibility level is
**Backward**. `orders-value` has two Avro versions, the second adding two optional fields, and `orders`
holds records written with each, plus three written without the registry. `payments-value` has three
versions, each compatible with the one before it and the third not with the first. `customers-value` is a
JSON Schema subject with its own level, **Full**. `invoices-value` references a type registered under
another subject. The shipments producer names its subject with the record name strategy, so there is no
`shipments-value`. `orders-legacy-value` is soft-deleted.

**Edition:** Community

## Requirements

- Docker with Compose v2
- BROKA running, for example from [`install/`](../../install/)
- Host ports 19110 (Kafka) and 18085 (Schema Registry) free, or change them in `.env`

## Run

1. Optional: copy the settings file and change the defaults. You need to do this on Linux (see
   [Connect BROKA](#connect-broka)).

   ```bash
   cp .env.example .env
   ```

2. Start the broker, the registry and the seed jobs:

   ```bash
   docker compose up -d
   ```

   `kafka-seed` creates the topics and writes the three plain records. `registry-seed` registers the
   subjects and sets the levels. `produce` then writes 20 orders and 5 shipments through the registry.

3. Check what the seed did:

   ```bash
   docker compose logs registry-seed produce
   curl -s http://localhost:18085/subjects
   curl -s http://localhost:18085/subjects?deleted=true
   ```

## The subjects

| Subject | Format | Versions | Level |
|---|---|---|---|
| `orders-key` | Avro (`"string"`) | 1 | Backward, inherited |
| `orders-value` | Avro | 2: version 2 adds `channel` and `promotionCode`, both nullable with a default | Backward, inherited |
| `payments-value` | Avro | 3: version 2 drops `amount`, version 3 adds it back as a string with a default | Backward, inherited |
| `customers-value` | JSON Schema | 1: `id` required, other properties allowed | Full, set on the subject |
| `com.example.common.Money` | Avro | 1 | Backward, inherited |
| `invoices-value` | Avro | 1, referencing `com.example.common.Money` version 1 | Backward, inherited |
| `com.example.shipping.Shipment` | Avro | 1, the subject the shipments producer uses | Backward, inherited |
| `orders-legacy-value` | Avro | 1, soft-deleted | |

The files under [`schemas/`](schemas/) are what the seed registered. The files under [`try/`](try/) are
changes to paste into **Update Schema**.

## Connect BROKA

Add a Kafka cluster in BROKA (**New Kafka cluster**):

| Field | Value |
|---|---|
| Name | `lab-schema-registry` |
| Bootstrap servers | `host.docker.internal:19110` on Docker Desktop, `<host-ip>:19110` on Linux |
| Authentication method | None |

Then open the cluster's row menu in the connections list, choose **Schema Registry** and set **URL** to
`http://host.docker.internal:18085` (`http://<host-ip>:18085` on Linux), with no authentication.

The broker gives clients the address in `KAFKA_ADVERTISED_HOST`, and BROKA's containers must be able to
reach it. The default, `host.docker.internal`, works on Docker Desktop. On Linux, set
`KAFKA_ADVERTISED_HOST` in `.env` to the host's IP address before you start the lab, and use that IP in
the connection.

## What to look at

1. **Kafka ▸ Schema Registry.** The summary line reads 7 subjects, 1 soft-deleted, global compatibility
   Backward. **Soft-deleted subjects ▸ Show** adds `orders-legacy-value`, whose row menu offers only
   **Delete permanently**.
2. **New Subject**, topic `shipments`, strategy **Topic Name**: the **Computed name** is `shipments-value`,
   which does not exist. The producer used **Record Name**, and its subject is
   `com.example.shipping.Shipment`. Cancel without creating.
3. **`orders-value` ▸ Schema.** Compare version 1 with version 2: the two added fields, each side with its
   schema id. **Structure** lists the fields with their types and defaults. The header reads Backward
   (inherited).
4. **A change the level refuses.** On `orders-value`, **Update Schema**, paste
   [`try/orders-value-amount-as-string.avsc`](try/orders-value-amount-as-string.avsc) and press **Check
   compatibility**: the registry lists the incompatibility. Nothing is registered.
5. **Tightening is refused too.** On `customers-value` (Full, set on the subject), check
   [`try/customers-value-tightened.json`](try/customers-value-tightened.json), which makes `email` required and
   closes the schema to other properties.
6. **Transitive.** `payments-value` version 3 passed Backward against version 2. Set the subject's level to
   **Backward transitive**, open **Update Schema** on version 3 and **Check compatibility**: it now fails
   against version 1, whose `amount` is a double. **Revert to inherited** afterwards.
7. **References.** `invoices-value` names `com.example.common.Money`. **Update Schema** on it sends that
   reference with the check and the registration.
8. **Records.** **Topics ▸ `orders` ▸ Messages**: three records show as raw text, ten decode with
   version 1 and ten with version 2. Open one and its **Details** tab names the
   schema id with the subject and version. On `shipments`, Details names `com.example.shipping.Shipment`.
9. **Produce** to `orders` with **Schema Registry** chosen: a field the schema does not declare is refused.
10. **Delete** `customers-value`: the confirmation says its schema id remains for lookup, and the subject
    moves to the soft-deleted list.

## Clean up

```bash
docker compose down -v
```

## Guide

[Schema Registry without guesswork](https://broka.dev/guides/schema-registry-without-guesswork)
