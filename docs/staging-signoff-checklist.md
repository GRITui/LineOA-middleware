# Staging sign-off checklist (self-hosted, issue #25)

Issue #25 originally asked for a real cloud deploy (Vercel/Azure/VPS) with a
secrets/monitoring/rollback sign-off checklist. On 2026-09-10 the repo owner
decided not to chase external cloud hosting for this prototype phase, and to
formally designate the existing self-hosted stack — Docker Compose Postgres
+ the Vapor app + a Cloudflare quick tunnel, per `docs/self-hosting.md` — as
the project's staging environment instead. This checklist adapts what #25
asked for to that reality. It is factual, not aspirational: it does not
claim monitoring or tooling that isn't actually wired up.

## Secrets

- **Where they live**: `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN`,
  and the Postgres credentials (`DATABASE_USERNAME`/`DATABASE_PASSWORD` for
  both the `lineoa_owner` and `lineoa_app` roles, see `docs/db-security.md`)
  are read from process environment variables at runtime
  (`Environment.get(...)` in `Sources/App/configure.swift` /
  `LineWebhookController`) — never committed to source. The repo's
  convention is a local `.env.selfhost` (or equivalent shell export) that is
  gitignored, matching the variable names documented in `.env.example` /
  `apps/liff/.env.example`.
- **Protection**: keep `.env.selfhost` out of git (confirm it's covered by
  `.gitignore`) and `chmod 600` it so only the owning user can read it.
  Never paste secrets into `docker-compose.selfhost.yml` itself — the
  Postgres owner password there is already parameterized via the
  `POSTGRES_OWNER_PASSWORD` env var with a dev-only default, per
  `docs/self-hosting.md`.
- **Rotation, if compromised**:
  1. LINE secret/token: regenerate in the LINE Developers console (channel
     access token and/or channel secret), then update `.env.selfhost` and
     restart the `apps/api` process — it only reads the environment once at
     startup (see `docs/runbook.md` §1–2).
  2. DB owner password: change `POSTGRES_OWNER_PASSWORD`, which requires
     recreating the `lineoa_pg_data` Docker volume for it to take effect
     (Postgres only applies `POSTGRES_PASSWORD` on first volume init) —
     `docker compose -f docker-compose.selfhost.yml down -v` then `up -d`,
     then re-run migrations.
  3. DB app-role password: edit `db/init/01-app-role.sql` and recreate the
     volume the same way, then update the app's `DATABASE_PASSWORD` env var
     to match before restarting `apps/api`.

## Monitoring / logging

**What exists today**:
- Vapor's built-in request logging writes to the process's stdout/log file
  wherever it's run (redirect to a file if running detached, e.g.
  `swift run App serve ... >> app.log 2>&1 &`).
- Application-level log lines documented in `docs/runbook.md` (`"LINE push
  failed"`, `"Invalid LINE signature"`, `"Reminder job: ..."`, etc.) are the
  primary way failures surface — detection is log-grep, not alerting.
- `docker compose -f docker-compose.selfhost.yml logs` (add `-f` to follow)
  gives Postgres container logs, and `docker compose -f
  docker-compose.selfhost.yml ps` shows container health status (the
  compose file defines a `pg_isready` healthcheck).
- `GET /health` confirms the Vapor process is up, but — per
  `docs/runbook.md` — does **not** check DB or LINE connectivity.

**What does NOT exist (accepted gap for the prototype phase)**:
- No external uptime monitoring or alerting (no Pingdom/UptimeRobot/
  equivalent watching the Cloudflare quick-tunnel URL or the health
  endpoint).
- No log aggregation/shipping (logs are local files/stdout only).
- No DB-connectivity-aware health check.
- No automated notification (email/Slack/etc.) on failure — all detection
  is manual log inspection or noticing the LINE OA bot stops responding.

This gap is being explicitly accepted for this prototype phase rather than
silently omitted. Revisit if/when this service handles real user traffic
rather than smoke-testing.

## Rollback plan

There is no CI/CD deploy pipeline for this self-hosted stack — nothing
auto-deploys on merge. "Rollback" here means stopping the running
processes and returning to a known-good commit, not reverting a release
artifact.

1. **Stop the stack**:
   - Postgres: `docker compose -f docker-compose.selfhost.yml down`
     (add `-v` only if you intend to also wipe the data volume — do not do
     this by default, it destroys booking data).
   - Vapor app: kill the `swift run App serve` process (`Ctrl-C` in its
     terminal, or `kill <pid>` if run detached).
   - LIFF frontend (if running): stop the `npm start` process the same way.
2. **Roll back code**: `git checkout <known-good-commit-or-tag>` in the
   working tree (or check out a previous release branch), then rebuild:
   - `cd apps/api && swift build` before re-running `swift run App serve`.
   - `cd apps/liff && npm install && npm run build` before `npm start`,
     if the LIFF frontend changed.
3. **Restart**: bring Postgres back up
   (`docker compose -f docker-compose.selfhost.yml up -d`), re-run
   migrations only if the rolled-back commit's schema requires it, then
   start the Vapor app and (if applicable) the LIFF frontend again, and
   re-establish the Cloudflare tunnel (`cloudflared tunnel --url
   http://localhost:8080`) — note its URL is ephemeral and must be
   re-registered as the LINE webhook URL each time it restarts, per
   `docs/self-hosting.md`.
4. **Verify**: `curl http://localhost:8080/health` → `ok`, then send a
   test LINE message to confirm the webhook and reply path both work.

## Sign-off

This checklist substitutes for the cloud-deploy sign-off originally
requested in issue #25. Secrets handling, the logging/monitoring gap, and
the rollback procedure above are the accepted state for the self-hosted
staging environment as of 2026-09-10.
