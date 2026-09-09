# Runbook: common failure modes

Operational recovery guide for `apps/api` (Swift/Vapor backend). See the root `README.md`
for setup/deploy context and `docs/db-security.md` for the Postgres role model referenced below.

This project does not integrate with Microsoft Dataverse — an earlier plan involving an Azure
Function App + Dataverse was dropped in favor of a single Swift/Vapor backend on Postgres (see
issue #27). The external dependencies that can actually fail in production are the LINE
Messaging API and the Postgres database, covered below.

## 1. LINE channel token/secret expiry or invalidation

**Symptoms**

- Outbound messages (booking-intent CTA replies from `LineWebhookController`, or reminder
  pushes from `ReminderService`) silently stop working — no error surfaces to the LINE OA
  user, only server logs.
- `LiveLineMessagingClient.pushMessage` / `.replyBookingCTA` (`Sources/App/Services/LineMessagingClient.swift`)
  throw `Abort(.badGateway, ...)` with a "LINE push/reply failed with status <code>" reason
  when LINE's API rejects the request — look for `401` (invalid/expired channel access token)
  in that status code.
- All inbound webhooks return `401 Unauthorized` with reason "Invalid LINE signature" — this
  happens if `LINE_CHANNEL_SECRET` is stale/rotated on LINE's side but not updated in the
  server's environment (see failure mode 2 below for the signature-specific case).
- If `LINE_CHANNEL_SECRET` is unset or empty entirely, every webhook POST returns `500` and
  the server logs `"LINE webhook received but LINE_CHANNEL_SECRET is not configured"`
  (`LineWebhookController.receive`).
- If `LINE_CHANNEL_ACCESS_TOKEN` is unset, the app silently uses `NoopLineMessagingClient`
  (`configure.swift`) — no error at all, replies/pushes are just no-ops. This is expected in
  local dev but is a real production incident if it happens after a deploy.

**How to detect**

- Grep server logs for `"LINE push failed"`, `"LINE reply failed"`, `"Booking-intent CTA reply failed"`,
  or `"Invalid LINE signature"`.
- `GET /health` only confirms the process is up — it does not check LINE connectivity. There
  is no dedicated LINE-connectivity health check in this codebase; the fastest live check is
  to trigger a booking-intent message from a test LINE account and watch the logs, or check
  the LINE Developers console's own delivery/error logs for the channel.
- A run of no reminders being delivered around their T-24h/T-2h/T-15min windows despite bookings
  existing is also consistent with this failure — cross-check against failure mode 3.

**How to recover**

1. In the LINE Developers console, regenerate the channel access token (long-lived) for the
   Messaging API channel, and/or re-copy the channel secret if it was rotated.
2. Update `LINE_CHANNEL_ACCESS_TOKEN` and `LINE_CHANNEL_SECRET` wherever the running deployment
   sources its environment (do not commit them — see `.env.example` for the variable names;
   these are never read from source, only `Environment.get(...)` in `configure.swift` /
   `LineWebhookController`).
3. Restart the `apps/api` process so `configure.swift` re-reads the environment and rebuilds
   `app.lineMessaging` as a `LiveLineMessagingClient` (it is only constructed once at startup,
   not re-read per request).
4. Re-send a test message to confirm the CTA reply and a push both succeed (no `badGateway`
   in logs, LINE OA account receives the message).

## 2. Webhook signature verification failures

**Symptoms**

- `POST /webhooks/line` returns `401 Unauthorized`, reason `"Invalid LINE signature"`, thrown
  from `LineWebhookController.receive` when `LineSignatureVerifier.isValid` returns `false`
  (`Sources/App/Services/LineSignatureVerifier.swift`, `Sources/App/Controllers/LineWebhookController.swift`).
- LINE's platform will retry failed webhook deliveries; sustained signature failures show up
  as repeated retries in the LINE Developers console's webhook delivery log, and as a wall of
  `401`s in server access logs.

**Root causes to check, in order**

1. **`LINE_CHANNEL_SECRET` mismatch** — the deployed secret doesn't match the channel's current
   secret in the LINE Developers console (most common: secret rotated in the console but not
   redeployed). Verification is `base64(HMAC-SHA256(channelSecret, rawBody))` against the
   `X-Line-Signature` header — any mismatch, including trailing whitespace/newline differences
   in how the secret was pasted into the environment, fails closed.
2. **Body tampering/reformatting in front of the app** — the signature is computed over the
   *raw* request body bytes. If a reverse proxy, WAF, or load balancer in front of `apps/api`
   re-encodes, re-orders JSON keys, or otherwise mutates the body before it reaches Vapor,
   every signature will fail even with a correct secret. Confirm nothing between LINE and the
   app touches the request body.
3. **Wrong channel entirely** — a webhook URL registered against a different LINE channel
   than the one whose secret is configured (e.g. staging URL pointed at prod channel secret).

**How to recover**

1. Re-verify `LINE_CHANNEL_SECRET` in the deployment environment character-for-character
   against the LINE Developers console (Messaging API channel > Basic settings > Channel secret).
2. Redeploy/restart after correcting it (same caveat as above: the secret is read once at
   request time via `Environment.get`, so no code change is needed, just an env var fix + a
   process restart if using a process manager that caches env at boot).
3. Use the LINE Developers console's "Verify" button on the webhook URL setting to send a
   test delivery and confirm a `200` response.
4. If the console verify succeeds but real traffic still 401s, suspect a proxy/body-mutation
   issue (root cause 2) rather than the secret.

## 3. Missed or failed reminder job runs

**Context**: `ReminderService.run` (`Sources/App/Services/ReminderService.swift`) is scheduled
in `configure.swift` via `scheduleRepeatedAsyncTask(initialDelay: .seconds(30), delay: .seconds(60))`
— it runs once every 60 seconds for the lifetime of the process, and is skipped entirely when
`app.environment == .testing`. It covers three reminder windows per confirmed booking: T-24h,
T-2h, T-15min (`reminder24Sent` / `reminder2Sent` / `reminder15Sent` flags on `Booking`).

**Symptoms / root causes**

- **Process was down across a reminder window.** The scheduler only runs while the process is
  alive — there is no catch-up/backfill logic. If `apps/api` was restarted or crashed and a
  booking's T-24h (etc.) window passed entirely while it was down, `secondsUntilStart <= window`
  will be false by the time the job runs again (the window has passed), so that reminder is
  **permanently skipped** — the flag is never set and never retried automatically, but the
  reminder text is also never sent. Check for gaps in server uptime/logs around the missed booking's
  session time.
- **DB query for confirmed bookings failed.** If `Booking.query(...).all()` throws inside
  `ReminderService.run`, the entire run for that tick logs `"Reminder job: failed to load
  bookings: <error>"` and returns — no reminders are evaluated that tick at all (transient;
  the next tick 60s later will retry from scratch). Look for this exact log line to distinguish
  "the whole run failed" from "one booking's push failed."
- **Push failed for one booking.** `send(...)` catches push errors per-booking and logs
  `"Reminder job: push failed for booking <id> (<window>): <error>"`, then returns *without*
  setting the sent flag — so that booking is retried on the next tick (up to 60s later) rather
  than being marked sent-but-not-delivered. This is expected/self-healing as long as the
  underlying LINE failure (see failure mode 1) is fixed within the reminder window.
- **Save of the sent-flag failed after a successful push.** Logged as `"Reminder job: failed to
  persist sent-flag for booking <id> (<window>): <error>"`. This is the one case that can cause
  a **duplicate** reminder: the message was actually sent, but because the flag didn't persist,
  the next tick will try to send it again (until the flag save eventually succeeds or the window
  closes). Indicates a DB write problem — see failure mode 4.

**How to detect**

- Grep logs for `"Reminder job:"` — all four log lines above share that prefix.
- To check whether a specific booking's reminder is stuck, query its `reminder24Sent` /
  `reminder2Sent` / `reminder15Sent` columns directly in Postgres and compare against whether
  the corresponding window has already passed.
- There is no dedicated `/health`-style endpoint for "is the reminder scheduler alive" — the
  only signal is the process being up (`GET /health`) plus the per-tick log lines.

**How to recover**

- **Missed window (process was down):** there is no built-in re-send/backfill. If a customer
  needs the missed reminder communicated, send it manually (e.g. via the LINE OA console or a
  one-off push) — there is no in-app "resend reminder" action as of this writing.
- **DB load failure / DB write failure:** fix the underlying DB connectivity (failure mode 4)
  — the job self-heals on its next 60-second tick once the DB is reachable again, and per-booking
  push retries also self-heal within the same tick cadence.
- **Suspected duplicate sends from a flag-persist failure:** confirm via logs (`"failed to
  persist sent-flag"` followed by repeated `"push"` log lines for the same booking/window),
  then manually set the appropriate `reminderXSent` flag to `true` in Postgres to stop further
  duplicates once you've confirmed delivery.

## 4. Database connectivity issues

**Symptoms**

- App fails to start, or `swift run` / the deployed process exits/crashes if Postgres is
  unreachable at boot (Fluent's Postgres driver is configured in `configure.swift` with
  `tls: .disable` — note plaintext connections only, no TLS config exists for non-local Postgres
  yet).
- Any HTTP request touching the DB (bookings, sessions, customers, reports) returns a 5xx.
- Reminder job logs `"Reminder job: failed to load bookings: <error>"` every tick (see failure
  mode 3) if the DB becomes unreachable while the process is already running.

**How to detect**

- `GET /health` returns `"ok"` unconditionally — it does **not** check DB connectivity, so it
  is not a reliable signal here. Prefer checking actual request logs/error responses, or query
  Postgres directly (`psql`) with the same `DATABASE_HOST`/`PORT`/`USERNAME`/`PASSWORD`/`NAME`
  the app uses (see `.env.example` and `Sources/App/configure.swift`).

**How to recover**

1. Confirm Postgres is up and reachable from the app's host/container (network/firewall, not
   just "is the DB process running").
2. Confirm the app's runtime role (`lineoa_app` per `docs/db-security.md`) still exists and has
   not had its password rotated without the app's env being updated to match.
3. If migrations are the issue (e.g. a table is missing because migrations were never run),
   run them with an elevated role per `docs/db-security.md` — the runtime `lineoa_app` role
   deliberately lacks `CREATE`/`ALTER` rights and cannot self-migrate.
4. Restart `apps/api` after connectivity/credentials are restored.

## Escalation / gaps

This is a POC-stage service (see root `README.md` — no live deployment yet, issues #3/#25/#27
open). There is currently no external monitoring/alerting wired up, no automated reminder
backfill, and no DB-aware health check — all detection above is log-grep or manual DB
inspection. If/when issue #25 (staging deploy) lands, revisit this runbook to add real
monitoring hooks instead of log-grepping.
