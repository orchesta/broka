# Lab: hardening a self-hosted console

The install stack from [`install/`](../../install/) with a TLS-terminating reverse proxy (Caddy) in front
of the console. The proxy publishes HTTPS on one port, the console's own plain-HTTP port is no longer
published, and the console believes `X-Forwarded-For` and `X-Forwarded-Proto` only from the proxy's
network. The rest of the guide is settings inside BROKA; they are listed as a checklist below.

**Edition:** Community

## Requirements

- Docker with Compose v2.24 or later (for `!reset`)
- `bash` and `openssl`

## Run

1. Fill in the install secrets. This creates `install/.env` from `.env.example` if it does not exist and
   generates `POSTGRES_PASSWORD`, `BROKA_JWT_SECRET`, `BROKA_KEK` and `BROKA_SERVICE_TOKEN` where they are
   empty. Values already set are kept.

   ```bash
   bash scripts/gen-secrets.sh
   ```

2. Start the install stack with the proxy on top:

   ```bash
   docker compose -f ../../install/compose.yml -f compose.yml up -d
   ```

3. Open https://localhost:18444 and create the first administrator. The browser warns about the
   certificate: it is issued by Caddy's local CA for `localhost`.

The override names the project `broka-lab-hardening`, so it starts a separate stack with its own database
and leaves a running `install/` stack alone. To harden that stack instead, delete the `name:` line.

## Settings

Compose reads `.env` from `install/`, so set these there.

| Variable | Default | |
|---|---|---|
| `HTTPS_PORT` | `18444` | Host port of the proxy |
| `EDGE_SUBNET` | `10.203.44.0/28` | Network shared by the proxy and the console; also its `BROKA_TRUSTED_PROXIES` |
| `BROKA_DOMAIN` | `localhost` | Name the certificate is issued for |
| `BROKA_TLS` | `internal` | `internal` for a local CA, or an e-mail address for ACME |
| `BROKA_PUBLIC_URL` | empty | Set to the HTTPS address so alert notifications link to it |

### A real domain

Point the name's DNS at the host, open port 443 to the internet and set:

```bash
BROKA_DOMAIN=console.example.com
BROKA_TLS=ops@example.com
HTTPS_PORT=443
BROKA_PUBLIC_URL=https://console.example.com
```

Caddy then obtains and renews a publicly trusted certificate over ACME. Apply with the same `up -d`.

## What to look at

1. **Only the proxy is published.**

   ```bash
   docker compose -f ../../install/compose.yml -f compose.yml ps
   curl -sS http://localhost:3000/       # connection refused
   curl -skI https://localhost:18444/    # 200, Via: 1.1 Caddy
   ```

2. **Forwarded headers are believed from the proxy only.** Sign in, then open **Operations ▸ Audit Logs**
   and the sign-in entry: the request context records `https` and the address the proxy saw, not the
   proxy's own. On a single Docker host that address is usually the edge network's gateway,
   `10.203.44.1`. A request that reaches the console by any other path is recorded with its real peer
   address, whatever `X-Forwarded-*` it sends.

## Checklist: the rest of the guide

- [ ] **Environments** — Settings ▸ Environments: production's write policy Read-only (or Guarded), Allow insecure TLS off.
- [ ] **Roles** — Settings ▸ Users and Roles: Viewer to read, Operator to change, Auditor for Operations ▸ Access Review (Commercial).
- [ ] **Audit** — Settings ▸ Security: the retention period, at most six months, and read auditing (Commercial; Community records writes and refusals only).
- [ ] **KEK rotation** — new key in `BROKA_KEK`/`BROKA_KEK_ID`, old one in `BROKA_KEK_PREVIOUS`/`BROKA_KEK_PREVIOUS_ID`, `up -d`, then Settings ▸ Security ▸ Rotate key-encryption key.
- [ ] **API tokens** — scripts sign in with a token from Profile ▸ API tokens; it carries its owner's current permissions.

## Clean up

```bash
docker compose -f ../../install/compose.yml -f compose.yml down -v
```

This removes the lab's database and Caddy's local CA. `install/.env` stays; delete it if you created it
only for this lab.

## Guide

[Hardening a self-hosted operations console](https://broka.dev/guides/hardening-a-self-hosted-console)
