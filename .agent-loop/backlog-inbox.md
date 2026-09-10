# LineOA-middleware sprint backlog (5 sprint program, 2026-09-10)

Coordinator: scripts/sprint-loop.sh · Engineer: openrouter/cohere/north-mini-code:free · Reviewer: groq/compound

<task_item>
  <id>TSK-101</id>
  <source>OWNER_POPUP</source>
  <status>READY_FOR_PM</status>
  <priority>HIGH</priority>
  <title>API: duplicate booking 500 → clean 409</title>
  <description>POST /bookings with an existing (customer_id, session_id) currently surfaces as raw PSQLError 500. Map the 23505 unique-constraint violation to Abort(.conflict, "Booking already exists for this customer and session") inside BookingController.create.</description>
  <acceptance>swift build passes; duplicate POST returns HTTP 409 with the friendly reason; no other flows changed</acceptance>
</task_item>

<task_item>
  <id>TSK-102</id>
  <source>OWNER_POPUP</source>
  <status>READY_FOR_PM</status>
  <priority>HIGH</priority>
  <title>API: DELETE /sessions/:id + GET /customers + reminder-flag fields</title>
  <description>1) SessionController: add delete route — DELETE /sessions/:sessionID returns 204, but 409 with reason if bookedCount &gt; 0. 2) CustomerController: GET /customers returns [Customer] each with bookingCount (query bookings count per customer). 3) SessionController.bookings response struct: add fields reminder24Sent, reminder2Sent, reminder15Sent (from Booking's reminder_24h_sat/2h/15min columns).</description>
  <acceptance>swift build passes; routes visible via App routes command; existing flows untouched</acceptance>
</task_item>

<task_item>
  <id>TSK-201</id>
  <source>OWNER_POPUP</source>
  <status>READY_FOR_PM</status>
  <priority>HIGH</priority>
  <title>Admin: scaffold apps/admin (Next.js, localhost-only) + sessions CRUD page</title>
  <description>Create apps/admin as a Next.js 15 (App Router) + Tailwind app mirroring apps/liff conventions (package.json scripts dev/build/start/lint, .env.example with NEXT_PUBLIC_API_BASE_URL=http://localhost:8080). lib/api.ts fetch helpers. Page /: sessions list (via GET /sessions) with title/date/capacity/status + create form (POST /sessions) + edit (PUT /sessions/:id) + delete button wired to DELETE /sessions/:id with a confirmation, showing 409 reason when bookings exist. Use fetch with cache: 'no-store'.</description>
  <acceptance>cd apps/admin && npm run build && npm run lint pass; build must not hit the network (no fetch at build/prerender time unless route is client-side); dev page shows sessions from a live API</acceptance>
</task_item>

<task_item>
  <id>TSK-202</id>
  <source>OWNER_POPUP</source>
  <status>READY_FOR_PM</status>
  <priority>MEDIUM</priority>
  <title>Admin: session detail (bookings + reminder chips) &amp; customers page</title>
  <description>In apps/admin add /sessions/[sessionID] page: bookings table from GET /sessions/:id/bookings (customer name, lineUserID, status, createdDate, reminder24/2h/15min chips as Survived gridColumn "✓ ✗"). Add /customers page listing customers via GET /customers with bookingCount. Nav links in the root layout.</description>
  <acceptance>npm run build/lint pass in apps/admin; pages render against live API at NEXT_PUBLIC_API_BASE_URL</acceptance>
</task_item>

<task_item>
  <id>TSK-203</id>
  <source>OWNER_POPUP</source>
  <status>READY_FOR_PM</status>
  <priority>MEDIUM</priority>
  <title>Admin: reports dashboard page</title>
  <description>In apps/admin add /reports page calling GET /reports/bookings-by-day and GET /reports/capacity-utilization (query param support as implemented). Render as two clean tables + a simple inline SVG bar chart (no chart library). Handle empty data gracefully.</description>
  <acceptance>npm run build/lint pass; page renders both endpoints' JSON</acceptance>
</task_item>

<task_item>
  <id>TSK-301</id>
  <source>OWNER_POPUP</source>
  <status>READY_FOR_PM</status>
  <priority>MEDIUM</priority>
  <title>Retire apps/admin-macos + docs/README swap</title>
  <description>git rm -r apps/admin-macos (do the deletion physically in the repo). Update README: stack table and repo layout tree — replace admin-macos entry with apps/admin (web admin, localhost-only, no auth yet — documented caveat). Update docs/self-hosting.md with an "Admin panel" section: cd apps/admin && npm install && npm run build && npm start (port 3000 by default or PORT env), no tunnel, local E2E only.</description>
  <acceptance>apps/admin-macos absent; README/self-hosting text consistent; no dangling references (grep -ri admin-macos README.md docs/ → only historical notes)</acceptance>
</task_item>

<task_item>
  <id>TSK-302</id>
  <source>OWNER_POPUP</source>
  <status>READY_FOR_PM</status>
  <priority>LOW</priority>
  <title>CI: add apps/admin lint+build job</title>
  <description>Extend .github/workflows/ci.yml with an admin job (ubuntu-latest, node 20, working-directory apps/admin: npm install, npm run lint, npm run build) mirroring the existing liff job.</description>
  <acceptance>workflow YAML valid (yamllint or eyeball), mirrors liff job structure</acceptance>
</task_item>
