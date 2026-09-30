<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/broka-dark.png">
    <img src="assets/broka-light.png" alt="BROKA" width="320">
  </picture>
</p>

<p align="center">
  A self-hosted operations console for Kafka, Redis, RabbitMQ and Apache Artemis.
</p>

<p align="center">
  <a href="https://broka.dev">Website</a> ·
  <a href="https://broka.dev/docs">Documentation</a> ·
  <a href="https://broka.dev/guides">Guides</a> ·
  <a href="https://broka.dev/download">Download</a>
</p>

---

This repository holds the installation recipe for the Community edition and the runnable environments
behind the BROKA guides.

## Install

```bash
cd install
cp .env.example .env    # fill in the four secrets
docker compose up -d
```

Open http://localhost:3000 and complete the first-run setup. See [`install/`](install/) for details.

## Labs

Each lab starts the brokers a guide uses, seeds them, and reproduces the situation the guide walks through.

| Lab | Guide | Edition |
|---|---|---|
| [`consumer-lag`](labs/consumer-lag/) | [Investigating consumer lag without guesswork](https://broka.dev/guides/consumer-lag-without-guesswork) | Community |
| [`redis-pending`](labs/redis-pending/) | [Redis Streams in production: the pending entries list](https://broka.dev/guides/redis-pending-entries) | Commercial |
| [`rabbitmq-routing`](labs/rabbitmq-routing/) | [Reading a routing problem from the bindings out](https://broka.dev/guides/routing-from-the-bindings-out) | Commercial |
| [`queue-backlogs`](labs/queue-backlogs/) | [Queue backlogs: drain, divert, or let it run](https://broka.dev/guides/queue-backlogs) | Commercial |
| [`permission-model`](labs/permission-model/) | [Operating every broker with one permission model](https://broka.dev/guides/one-permission-model) | Community |
| [`hardening`](labs/hardening/) | [Hardening a self-hosted operations console](https://broka.dev/guides/hardening-a-self-hosted-console) | Community |

Requirements: Docker with Compose v2.

## License

The files in this repository are licensed under the [Apache License 2.0](LICENSE).
BROKA itself is distributed under its own terms; see [broka.dev](https://broka.dev).
