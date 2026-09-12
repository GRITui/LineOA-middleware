# Client pilot runbook

Step-by-step guide for the client to run a pilot of the LINE OA booking flow on the
self-hosted staging stack. This document assumes no prior familiarity with the codebase.

Related docs:

- `docs/self-hosting.md` — the staging stack in detail (what each process is, known limitations)
- `docs/db-security.md` — the Postgres role model (owner vs. least-privilege app role)
- `docs/runbook.md` — what to do when something fails

## 1. Prerequisites

- A Mac or Linux machine that can stay on for the pilot period, with:
  - Docker (for Postgres)
  - Node 20 + npm (for the LIFF and admin frontends)
  - Swift 5.9+ toolchain (for the API)
  - `cloudflared` (free Cloudflare quick tunnels — LINE requires public HTTPS URLs)
- A LINE Developers account with, for the client's Official Account:
  - a **Messaging API channel** (gives you a channel access token + channel secret)
  - a **LIFF app** (gives you a LIFF ID and an endpoint URL to configure)
- At least one **test LINE account** (a staff phone) that has added the Official Account as a friend — this is the account used to test booking.

## 2. Bring up the staging stack

Run everything from the repo root. Four processes plus two tunnels:

### 2.1 Postgres (Docker)

```
docker compose -f docker-compose.selfhost.yml up -d
```

Creates the `lineoa_owner` superuser (override its password with the
`POSTGRES_OWNER_PASSWORD` env var; dev default `owner_dev_password`) and the
least-privilege `lineoa_app` runtime role via `db/init/01-app-role.sql`.

### 2.2 Migrations (one-time per fresh database, owner role)

```
cd apps/api
DATABASE_HOST=localhost DATABASE_PORT=5432 \
DATABASE_USERNAME=lineoa_owner DATABASE_PASSWORD=owner_dev_password \
DATABASE_NAME=lineoa_booking \
swift run App migrate --yes
```

Migrations need `CREATE`/`ALTER`, which the runtime `lineoa_app` role
deliberately lacks — that is why they run as the owner. Re-run this command
after any deploy that adds new migrations.

### 2.3 API server

```
cd apps/api
DATABASE_HOST=localhost DATABASE_PORT=5432 \
DATABASE_USERNAME=lineoa_app DATABASE_PASSWORD=lineoa_app_dev_password \
DATABASE_NAME=lineoa_booking \
LINE_CHANNEL_SECRET=<channel secret from LINE Developers console> \
LINE_CHANNEL_ACCESS_TOKEN=<channel access token> \
LIFF_URL=https://liff.line.me/<LIFF ID> \
swift run App serve --hostname 0.0.0.0 --port 8080
```

Confirm: `curl http://localhost:8080/health` → `ok`.

Env vars (see `.env.example` at the repo root):

| Variable | Purpose |
|---|---|
| `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_USERNAME` / `DATABASE_PASSWORD` / `DATABASE_NAME` | Postgres connection |
| `LINE_CHANNEL_SECRET` | Verifies inbound webhook signatures — without it every webhook returns 500 |
| `LINE_CHANNEL_ACCESS_TOKEN` | Sends pushes/replies — without it the app silently no-ops all LINE messages |
| `LIFF_URL` (or `LINE_LIFF_ID`) | The URL the booking-intent CTA button opens |

### 2.4 Public tunnel for the API (LINE webhook)

```
cloudflared tunnel --url http://localhost:8080
```

Copy the printed `https://<random>.trycloudflare.com` URL. In the LINE
Developers console, set the Messaging API **webhook URL** to
`https://<that-url>/webhooks/line` and enable the webhook. The URL changes
every time this command restarts — update the console when it does.

### 2.5 LIFF frontend (what customers see in LINE)

```
cd apps/liff
cp .env.example .env   # fill in:
#   NEXT_PUBLIC_LIFF_ID=<LIFF ID>
#   NEXT_PUBLIC_LINE_LOGIN_CHANNEL_ID=<LINE Login channel ID>
#   NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
npm install
npm run build
npm start              # port 3000
```

The LIFF webview loads `https://liff.line.me/<LIFF ID>`, which redirects to
the LIFF **endpoint URL** configured in the LINE Developers console — that
must be a second public tunnel to this server:

```
cloudflared tunnel --url http://localhost:3000
```

Set the printed URL as the LIFF endpoint in the console.

### 2.6 Admin panel (staff only, localhost-only)

```
cd apps/admin
ADMIN_PASSWORD=<choose a strong password> \
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080 \
PORT=3001 \
npm install && npm run build && npm start
```

Open `http://localhost:3001/login` and sign in with `ADMIN_PASSWORD`
(12-hour session cookie). **Do not expose the admin panel via a tunnel** —
it is localhost-only by design.

## 3. Inviting staff

There is no per-user accounts system in the pilot: the admin panel is gated
by one shared `ADMIN_PASSWORD`. "Inviting" a staff member means:

1. They work on (or SSH into) the machine running the stack, and
2. They know the `ADMIN_PASSWORD`.

To rotate access, restart the admin process with a new `ADMIN_PASSWORD`.

## 4. Configuring the first class

In the admin panel, open **Sessions** and create a session: title, date,
start time, end time, capacity. It immediately appears in the LIFF for
customers to book.

For a whole series of slots (e.g. every 60 minutes from 09:00 to 17:00), use
the slot generator API (no UI in the pilot — one `curl` does it):

```
curl -X POST http://localhost:8080/admin/sessions/generate \
  -H 'Content-Type: application/json' \
  -d '{"date":"2026-09-20","startTime":"09:00","endTime":"17:00","durationMin":60,"intervalMin":60}'
```

It returns the created session IDs. It refuses (409) if the range overlaps
any existing session on that date.

## 5. Testing the LINE flow (end to end)

Using the test LINE account that follows the Official Account:

1. **Intent → CTA.** Send a booking-intent message (e.g. "I want to book a
   class"). The OA replies with a CTA button opening the LIFF.
2. **LIFF opens.** The customer record is created automatically from the
   LINE profile; available sessions are listed.
3. **Book.** Pick a date and session, confirm. The LIFF shows a success
   screen and the OA pushes a confirmation message.
4. **Reminders.** The API sends reminders at T-24h, T-2h and T-15m before
   the session starts (watch the API logs for `Reminder job:` lines to see
   the scheduler ticking).
5. **Walk-in booking (staff).** In the admin panel, open a session and use
   the quick-add on the session page to book a customer who is physically
   present (guest customer, no LINE account needed).
6. **Cancellation.** A customer can cancel their own upcoming booking from
   the LIFF (the slot is freed and a cancellation push is sent); staff can
   cancel any booking from the admin session page.

## 6. Reading the dashboard

The admin panel (signed in) has four views:

- **Overview** (`/`) — at-a-glance counts: sessions, bookings, customers.
- **Sessions** — every session with its bookings and capacity; this is where
  you create sessions and handle walk-ins/cancellations.
- **Customers** — every customer (LINE users and walk-in guests) with their
  booking counts.
- **Reports** — the reporting tables the API exposes for the pilot period.

Numbers are live from Postgres — no caching to wait out.

## 7. Day-to-day operations

- Keep the host machine on; the stack is four processes (Postgres container,
  API, LIFF, admin) plus two `cloudflared` tunnels. If the machine sleeps or
  a terminal closes, restart the affected process.
- After restarting a tunnel, update the LINE console (webhook URL and/or LIFF
  endpoint) with the new URL.
- After a code deploy: re-run migrations (2.2), restart the API, rebuild and
  restart the frontends.
- When something fails, start with `docs/runbook.md` (LINE credential expiry,
  webhook signature mismatches, missed reminders, DB connectivity) and check
  `GET /health` on the API.

## 8. Pilot sign-off checklist

- [ ] `curl http://localhost:8080/health` → `ok`
- [ ] LINE console webhook test returns 200
- [ ] Test account receives the CTA reply to a booking-intent message
- [ ] A booking is created end to end (LIFF → confirmation push)
- [ ] A walk-in booking is created from the admin panel
- [ ] A cancellation frees the slot (customer-side and staff-side)
- [ ] Reminders fire at T-24h / T-2h / T-15m (or verify scheduler logs)
- [ ] Dashboard numbers match what was actually booked


