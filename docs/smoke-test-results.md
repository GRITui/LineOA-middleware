# Smoke test results — issue #24 (booking → reminders)

**Date:** 2026-09-10 · **Executor:** automated scripted pass (this monorepo session)
**Environment:** self-hosted staging per `docs/self-hosting.md` — Vapor `App serve`
@ `localhost:8080`, Postgres via Docker (`lineoa_postgres`, volume
`lineoa-booking-model_lineoa_pg_data`), Cloudflare quick tunnel up
(`cloudflared` PID 84892 → localhost:8080). API build includes origin `f858dff`
(capacity race fix + past-date rejection).

**LINE configuration used:** `LINE_CHANNEL_SECRET=smoketest_lineoa_secret`
(synthetic — enables webhook route for signature-verified simulation);
`LINE_CHANNEL_ACCESS_TOKEN` deliberately **unset** → `NoopLineMessagingClient`
(pushes are "sent" at the client boundary and marked-sent flags persist, but no
actual delivery — real-device verification pending).

## Scripted results (PASS unless noted)

| # | Check | Result |
|---|---|---|
| S1 | `GET /health` → 200 `ok` | PASS |
| S2 | `GET /availability` returns open sessions (rows ≥ 5) | PASS |
| S3 | Webhook, valid signature (HMAC-SHA256, **base64**) → 200 | PASS |
| S3b | Webhook, invalid signature → 401 `Invalid LINE signature` | PASS |
| S4 | Booking intent message → matched, CTA path taken (LIFF URL unset → designed skip warning logged) | PASS |
| S5 | `POST /bookings` happy path (customer `U_smoke_e2e_0042` × `[SMOKE] booking target`) → 200, booking row created | PASS |
| S6 | Capacity fill: session cap 2 → both slots booked, `booked_count=2`, `status='full'` | PASS |
| S7 | Overbook on full session → 409 `Session is full` | PASS |
| S8 | Unknown session → 404 `Customer/Session not found` | PASS |
| S9 | Past-date booking → 409 `Session has already ended` (post-`f858dff` rejection) | PASS |
| S10 | Reminders fast-path: booking on session starting in ~10 min → **after one 60 s job tick, `reminder24h_sent`/`reminder_2h_sent`/`reminder15m_sent` all true** | PASS (Noop send; real delivery not verified) |
| S11 | **Duplicate booking (same customer + session) → 500 PSQLError** (unique constraint `uq:bookings.customer_id+bookings.session_id` surfaces as raw 500 instead of a clean 409/422) | **FAIL — finding** |

## Findings

1. **Duplicate-booking 500 (issue-worthy):** `POST /bookings` with an already
   existing `(customer_id, session_id)` returns HTTP 500 with a template
   `PSQLError` body rather than mapping the 23505 unique violation to a 409/422.
   Impact: LIFF error UX on double-tap retry paths.
2. **Reminder pushes have no observable "sent" log on the Noop path** — flags
   in DB are the only evidence. Fine for prototype; add an info log in
   `NoopLineMessagingClient` for parity if cheap.

## Infra note (environment-specific)

Two Docker daemons co-exist on this host (Docker Desktop + OrbStack). The live
staging DB runs under **Docker Desktop** (`docker --context desktop-linux`);
the OrbStack twin holds an empty 5432. All DB asserts here ran with
`docker --context desktop-linux exec lineoa_postgres ...`. Compose stack
origin: `.claude/worktrees/lineoa-booking-model/docker-compose.selfhost.yml`.

## Pending — manual on-device (needs real LINE credentials, issue #3)

Can't execute in this environment; requires the real channel access token
pushing to a device and a real LIFF ID (LIFF frontend is not running here —
`apps/liff/.env` absent):

- [ ] Chat → OA bot reply with Book Now / View Available Slots CTA
- [ ] CTA → LIFF Mini App opens in LINE webview → availability list
- [ ] LIFF booking → confirmation UI + confirmation push within seconds
- [ ] 3 reminder pushes (24h/2h/15min) observed on device (fast-path session or live waits)

Issue #24 acceptance ("chat → CTA → Mini App → booking → confirmation → all 3
reminders fire correctly") stays **open** until the manual segment passes; the
scripted sequence above covers the API/webhook/DB surface it depends on.
