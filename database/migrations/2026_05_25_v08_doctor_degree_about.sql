-- =============================================================================
-- MIGRATION : 2026_05_25_v08_doctor_degree_about.sql
-- PURPOSE   : Add degree and about fields to doctor_verifications
-- DATE      : 2026-05-25
--
-- Run this in Supabase SQL Editor (already applied via MCP).
-- =============================================================================

ALTER TABLE public.doctor_verifications
  ADD COLUMN IF NOT EXISTS degree         TEXT,
  ADD COLUMN IF NOT EXISTS about          TEXT,
  ADD COLUMN IF NOT EXISTS pending_degree TEXT,
  ADD COLUMN IF NOT EXISTS pending_about  TEXT;
