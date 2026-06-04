-- ============================================================================
--  00_extensions.sql — Required PostgreSQL extensions
-- ============================================================================
--  Run first. Everything else depends on gen_random_uuid().
-- ============================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid()
