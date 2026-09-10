-- Least-privilege runtime role for self-hosted dev/staging, per docs/db-security.md.
-- Runs once on first container init (postgres image convention).
CREATE ROLE lineoa_app LOGIN PASSWORD 'lineoa_app_dev_password';

GRANT CONNECT ON DATABASE lineoa_booking TO lineoa_app;
GRANT USAGE ON SCHEMA public TO lineoa_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO lineoa_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO lineoa_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lineoa_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE ON SEQUENCES TO lineoa_app;
