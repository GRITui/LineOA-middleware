# Architecture

## Overview

LINE OA middleware for booking management. A customer messages the LINE
Official Account, gets routed to a booking flow via a LIFF mini-app, backed
by a Vapor/Swift API and Postgres, with a native macOS admin app for staff.

## Components

- **apps/api** (Vapor/Swift backend) — Controllers: `LineWebhookController`
  (inbound LINE events, signature verification, CTA replies),
  `BookingController` (create/manage bookings, capacity checks),
  `AvailabilityController`, `SessionController`, `CustomerController`
  (LINE-login customer resolution), `ReportController`. Services:
  `LineSignatureVerifier`, `LineMessagingClient` (outbound push/reply),
  `BookingIntentMatcher`, `ReminderService` (scheduled reminder pushes at
  T-24h/T-2h/T-15m). Models: `Booking`, `Session`, `Customer`, persisted in
  Postgres.
- **apps/liff** (Next.js) — customer-facing LIFF mini-app for date/time
  picking and booking confirmation, opened via a CTA the webhook sends back
  to the LINE chat.
- **apps/admin-macos** — native Swift desktop app for staff to view/manage
  sessions and bookings, talks to apps/api over REST.
- **Infra (current phase)**: self-hosted — Docker Compose Postgres + the
  Vapor app run natively + a Cloudflare quick-tunnel exposing the webhook
  publicly. This is the project's staging environment as of issue #25
  (resolved 2026-09-10, see [docs/self-hosting.md](self-hosting.md) and
  [docs/staging-signoff-checklist.md](staging-signoff-checklist.md)). No
  cloud hosting account is provisioned; that's an accepted gap for this
  prototype phase.
- **External dependency**: LINE Messaging API + LINE Mini App/LIFF platform
  (real dev channel provisioned, issue #3 resolved).

## Data flow

1. Customer sends a message to the LINE OA → LINE platform POSTs to
   `/webhooks/line` → `LineWebhookController` verifies the signature
   (`LineSignatureVerifier`) → `BookingIntentMatcher` determines intent →
   replies with a LIFF CTA via `LineMessagingClient`.
2. Customer opens the LIFF mini-app (apps/liff) → calls apps/api REST
   endpoints (`AvailabilityController`, `BookingController`) → booking is
   created and persisted (`Booking`, `Session`, `Customer` models in
   Postgres).
3. `ReminderService` runs on a schedule, checks upcoming `Session`/`Booking`
   records, and pushes reminder messages back through `LineMessagingClient`.
4. Staff use apps/admin-macos → REST calls to apps/api → view/manage
   bookings and sessions directly.

## MVP scope

MVP acceptance bar is the end-to-end path — a real customer messages the
LINE OA, receives a booking CTA, completes a booking in the LIFF app,
receives a reminder before the session, and staff can see the booking in
apps/admin-macos.

Included in MVP: webhook intake + signature verification, booking creation
+ availability checks, customer identification via LINE login,
booking-intent CTA → LIFF flow, reminders, and admin-macos visibility for
staff.

Explicitly deferred past MVP: `ReportController`/analytics, external
monitoring/alerting (already accepted as a gap in
[docs/staging-signoff-checklist.md](staging-signoff-checklist.md)),
multi-channel/multi-session-type complexity beyond the current single
model, and payments (not present anywhere in the codebase — confirmed out
of scope for MVP, not an oversight).

## Sign-off

Reviewed and approved by the repo owner acting as PM on 2026-09-10,
satisfying the acceptance criteria of issue #5. This document is the
recorded decision.
