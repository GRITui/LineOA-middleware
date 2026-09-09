# LineOA Booking POC

LINE Official Account + LINE Mini App (LIFF) booking platform proof of concept.

## Stack

- **`apps/liff`** — LINE Mini App frontend (Next.js/React/Tailwind, required by LINE's LIFF webview).
- **`apps/api`** — Backend API (Swift/Vapor + Postgres via Fluent).
- Admin app — native Swift/Xcode app (tracked separately, see issue #28).

## Scope

POC scope excludes payments, loyalty, waitlist, reschedule/cancellation, CRM integration, AI agent,
and chatbot. See the repo's [milestones](../../milestones) and [project board](../../projects) for
the sprint-by-sprint backlog.

## Getting started

### API (`apps/api`)

```bash
cd apps/api
cp ../../.env.example .env   # fill in DB + LINE credentials
swift run
```

### LIFF app (`apps/liff`)

```bash
cd apps/liff
cp .env.example .env.local   # fill in LIFF ID + API base URL
npm install
npm run dev
```

## Contributing

See open issues for the current sprint's backlog. Each issue is tagged with a `role:*` label
(pm, architect, fe, be, power-platform, qa) and an `area:*` label (liff, api, database, admin,
reminders, reporting, messaging, security, infra).
