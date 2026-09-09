# Postgres least-privilege role

See GitHub issue #23. The app connects as `DATABASE_USERNAME`/`DATABASE_PASSWORD`
(env vars — never in source, see `.env.example`). For any non-local environment,
that account should be a dedicated, least-privilege role, not a superuser:

```sql
-- Run once per environment as a superuser/owner.
CREATE ROLE lineoa_app LOGIN PASSWORD '<set via secrets manager>';

GRANT CONNECT ON DATABASE lineoa_booking TO lineoa_app;
GRANT USAGE ON SCHEMA public TO lineoa_app;

-- App only ever reads/writes rows in its own tables — no DDL, no other schemas.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO lineoa_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO lineoa_app;

-- Keep future tables covered without re-granting by hand.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lineoa_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE ON SEQUENCES TO lineoa_app;
```

Migrations (`swift run App migrate`) need `CREATE`/`ALTER` rights that the
runtime app role above deliberately excludes — run migrations with a separate,
higher-privilege role (or the owner) during deploy, then point the running
app at `lineoa_app` for normal request traffic.

The admin app (#28) should get its own role, scoped read-mostly to the tables
it needs, rather than reusing `lineoa_app` or an owner account.
