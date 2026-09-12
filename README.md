# LineOA Booking POC

LINE Official Account + LINE Mini App (LIFF) booking platform proof of concept.

## Stack

- **`apps/liff`** — LINE Mini App frontend (Next.js/React/Tailwind, required by LINE's LIFF webview).
- **`apps/api`** — Backend API (Swift 6/Vapor 4 + Postgres via Fluent).
- **`apps/admin`** — Web admin panel (Next.js, localhost-only). Password-gated via the `ADMIN_PASSWORD` env var (12h httpOnly session cookie, fail-closed when unset) — still localhost-only, do not expose publicly.

## Scope

POC scope excludes payments, loyalty, waitlist, reschedule/cancellation, CRM integration, AI agent,
and chatbot. See the repo's [milestones](../../milestones) and [project board](../../projects) for
the sprint-by-sprint backlog.

## Repo layout

```
apps/
  api/            Swift/Vapor backend (Fluent + Postgres)
    Sources/App/Controllers/   HTTP route handlers (availability, booking, customer, LINE webhook, report, session)
    Sources/App/Services/      LineSignatureVerifier, LineMessagingClient, ReminderService, BookingIntentMatcher
    Sources/App/Models/        Fluent models (Booking, Customer, Session)
    Tests/AppTests/            XCTVapor test suite
  liff/           Next.js LIFF Mini App (Tailwind)
  admin/          Next.js web admin panel (localhost-only, ADMIN_PASSWORD gate)
docs/
  db-security.md  Least-privilege Postgres role for the app (see Deploy below)
  runbook.md      Common failure modes and recovery steps
.github/workflows/ci.yml   CI: swift build/test for apps/api, npm lint/build for apps/liff
```

## Prerequisites

- **apps/api**: Swift 5.9+ toolchain (CI pins `swift-version: "5.9"` on `macos-14`), a local Postgres instance.
- **apps/liff**: Node 20 (CI uses `actions/setup-node@v4` with `node-version: "20"`), npm.
- **apps/admin**: Node 20, npm. Web admin panel run with `npm install && npm run build && npm start` — no separate backend of its own, talks to `apps/api` over HTTP.
- A LINE Developers account with a Messaging API channel and a LIFF channel (tracked in issue #3 — not yet provisioned as of this writing). Local development can run without live LINE credentials: the API falls back to a no-op LINE messaging client (`NoopLineMessagingClient`) when `LINE_CHANNEL_ACCESS_TOKEN` is unset, and the webhook route requires `LINE_CHANNEL_SECRET` to be set to accept any request.

## Local setup

### API (`apps/api`)

```bash
cd apps/api
cp ../../.env.example .env   # fill in DB + LINE credentials
swift run
```

Config is read from environment variables (see `.env.example` at the repo root):

| Variable | Purpose |
|---|---|
| `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_USERNAME` / `DATABASE_PASSWORD` / `DATABASE_NAME` | Postgres connection (defaults: `localhost:5432`, `vapor`/`vapor`, `lineoa_booking` — see `Sources/App/configure.swift`) |
| `LINE_CHANNEL_SECRET` | Required to verify inbound webhook signatures (`POST /webhooks/line`); if unset, that route always returns 500 |
| `LINE_CHANNEL_ACCESS_TOKEN` | Required to actually push/reply LINE messages; if unset, the app uses a no-op client and silently skips sending |
| `LIFF_URL` or `LINE_LIFF_ID` | URL opened by the booking-intent CTA reply button; if neither is set, the CTA reply is skipped (logged as a warning, not an error) |

The server listens on the Vapor default (`http://localhost:8080`) and exposes `GET /health` for a liveness check.

Fluent migrations are *not* auto-applied by `swift run` — see [Migrations and DB role](#migrations-and-db-role) below. On startup, `configure.swift` also schedules the reminder job (`ReminderService`) to run every 60 seconds (30s initial delay) unless `app.environment == .testing`.

### LIFF app (`apps/liff`)

```bash
cd apps/liff
cp .env.example .env.local   # fill in LIFF ID + API base URL
npm install
npm run dev
```

Env vars (`apps/liff/.env.example`):

| Variable | Purpose |
|---|---|
| `NEXT_PUBLIC_LIFF_ID` | LIFF app ID from the LINE Developers console |
| `NEXT_PUBLIC_LINE_LOGIN_CHANNEL_ID` | LINE Login channel ID |
| `NEXT_PUBLIC_API_BASE_URL` | Base URL of `apps/api` (defaults to `http://localhost:8080`) |

### Admin app (`apps/admin`)

```bash
cd apps/admin
npm install
npm run build
npm start
```

Base URL of `apps/api` comes from `NEXT_PUBLIC_API_BASE_URL` (defaults to `http://localhost:8080`). Access is gated by a shared password from the server-only `ADMIN_PASSWORD` env var (sign in at `/login`; 12h httpOnly session cookie; everything redirects to login when unset). Localhost-only — do not expose publicly.

## Running tests / CI locally

CI (`.github/workflows/ci.yml`) runs two independent jobs; reproduce them locally with:

```bash
# API job (macos-14 runner, Swift 5.9 in CI)
cd apps/api
swift build
swift test

# LIFF job (ubuntu-latest runner, Node 20 in CI)
cd apps/liff
npm install
npm run lint
npm run build
```

`apps/liff` has no dedicated test script (CI only lints and builds it). `apps/admin` has no dedicated test script either (lint+build only).

## Migrations and DB role

See `docs/db-security.md` for the full least-privilege Postgres role setup. Summary:

- The app connects at runtime as a dedicated `lineoa_app` role with `SELECT/INSERT/UPDATE/DELETE` only — no DDL, no superuser.
- Migrations (`swift run App migrate`) need `CREATE`/`ALTER` rights that `lineoa_app` deliberately lacks — run migrations with a separate, higher-privilege role (or the database owner) during deploy/setup, then point the running app back at `lineoa_app` for normal traffic.
- For local development against a fresh Postgres instance, the default `vapor`/`vapor` credentials in `.env.example` are fine; apply the least-privilege role only for shared/non-local environments.

## Deploy notes

There is no live cloud deployment. The intended process for the remaining open infra:

1. **LINE channel provisioning** (issue #3, open) — create the Messaging API channel + LIFF channel in the LINE Developers console, capture the channel access token/secret and LIFF ID in a secrets store (not in source — see `.env.example` / `apps/liff/.env.example` for the variables each app needs).
2. **Backend hosting + Postgres** (issue #27, open) — provision a lean hosting target (Docker container on a VPS or Azure Container Apps) running the Swift server, with a Postgres database reachable from it. This supersedes an earlier plan involving an Azure Function App + Dataverse, which was dropped in favor of a single Swift/Vapor backend — this repo has no Dataverse integration.
3. **Staging (issue #25) — resolved, self-hosted**: as of 2026-09-10 the repo owner decided against chasing external cloud hosting (Vercel/Azure/VPS) for this prototype phase. The existing self-hosted stack — Docker Compose Postgres + the Vapor app + a Cloudflare quick tunnel, with the LIFF frontend run alongside it via `npm` — is now formally designated the project's staging environment. See `docs/self-hosting.md` (setup + the "Staging designation" section) and `docs/staging-signoff-checklist.md` (the secrets/monitoring/rollback sign-off) for details.

**Issues #3 and #27 remain open** — LINE channel credentials and a real cloud hosting target are not yet provisioned, so a live production deploy shouldn't be attempted without them. Once hosting exists, apply the `lineoa_app` least-privilege Postgres role from `docs/db-security.md` before pointing production traffic at it, and run migrations with a separate elevated role as described above.

When something does fail in a running deployment, see `docs/runbook.md` for common failure modes (LINE credential expiry, webhook signature mismatches, missed reminder job runs, DB connectivity) and how to recover.

## Contributing

See open issues for the current sprint's backlog. Each issue is tagged with a `role:*` label
(pm, architect, fe, be, power-platform, qa) and an `area:*` label (liff, api, database, admin,
reminders, reporting, messaging, security, infra).
