# Install BROKA Community

PostgreSQL, the console's three services and one published port.

## Steps

1. Create the environment file and fill in the four secrets:

   ```bash
   cp .env.example .env
   ```

   | Variable | Generate with |
   |---|---|
   | `POSTGRES_PASSWORD` | `openssl rand -base64 24` |
   | `BROKA_JWT_SECRET` | `openssl rand -base64 48` |
   | `BROKA_KEK` | `openssl rand -base64 32` |
   | `BROKA_SERVICE_TOKEN` | `openssl rand -hex 32` |

   Keep `.env` with your database backups. `BROKA_KEK` encrypts stored broker credentials; without it
   they cannot be read back.

2. Start it:

   ```bash
   docker compose up -d
   ```

3. Open http://localhost:3000, create the first administrator and add a connection to your broker.

## Notes

- The console listens on plain HTTP. Put a reverse proxy with TLS in front of it for anything other than
  a local trial, and set `BROKA_TRUSTED_PROXIES` to the proxy's network.
- Keep `BROKA_VERSION` pinned. Upgrades run database migrations that a downgrade does not undo.
- Brokers are not part of this stack; BROKA connects to the ones you already run.
