# Self-hosted local/staging (issue #27, self-hosted path)

No cloud account required. Runs Postgres in Docker and the Vapor app
natively, exposed via a free Cloudflare quick tunnel so LINE (which
requires HTTPS) can reach the webhook.

## 1. Start Postgres

```
docker compose -f docker-compose.selfhost.yml up -d
```

This creates the `lineoa_owner` superuser (from `POSTGRES_USER`/`POSTGRES_PASSWORD`,
override via `POSTGRES_OWNER_PASSWORD` env var — defaults to `owner_dev_password`,
dev-only) and, via `db/init/01-app-role.sql`, the least-privilege `lineoa_app`
runtime role documented in `docs/db-security.md` (password `lineoa_app_dev_password`,
dev-only — the init script only runs once on first volume creation, so change it
there and recreate the volume if you need a different one).

## 2. Run migrations (owner role — needs CREATE/ALTER)

```
cd apps/api
DATABASE_HOST=localhost DATABASE_PORT=5432 \
DATABASE_USERNAME=lineoa_owner DATABASE_PASSWORD=owner_dev_password \
DATABASE_NAME=lineoa_booking \
swift run App migrate --yes
```

## 3. Run the app (least-privilege role — normal traffic)

```
cd apps/api
DATABASE_HOST=localhost DATABASE_PORT=5432 \
DATABASE_USERNAME=lineoa_app DATABASE_PASSWORD=lineoa_app_dev_password \
DATABASE_NAME=lineoa_booking \
LINE_CHANNEL_SECRET=<from issue #3> LINE_CHANNEL_ACCESS_TOKEN=<from issue #3> \
swift run App serve --hostname 0.0.0.0 --port 8080
```

Confirm locally: `curl http://localhost:8080/health` → `ok`.

## 4. Expose it publicly for LINE's webhook

LINE requires a public HTTPS URL — a free Cloudflare quick tunnel works
without any account or DNS setup:

```
cloudflared tunnel --url http://localhost:8080
```

It prints a `https://<random>.trycloudflare.com` URL. Set that (plus
`/webhooks/line`) as the webhook URL in the LINE Developers Console once
issue #3's channel exists. The URL changes every time the tunnel restarts —
fine for dev/smoke-testing; for anything longer-lived, run `cloudflared`
as a named tunnel against your own domain instead (needs a Cloudflare
account + DNS access — out of scope for the no-account path here).

## Known limitations vs. a real cloud deploy

- Tunnel URL is ephemeral (quick-tunnel mode) — update the LINE webhook URL
  if you restart `cloudflared`.
- Uptime depends on the host machine staying on and both processes running;
  there's no process supervisor wired up here (use `launchd`/`pm2`/a `screen`
  session if you need it to survive terminal closure).
- Dev-only passwords are used above — rotate them (edit `db/init/01-app-role.sql`
  and `POSTGRES_OWNER_PASSWORD`, recreate the `docker compose` volume) before
  treating this as anything beyond a throwaway smoke-test environment.
