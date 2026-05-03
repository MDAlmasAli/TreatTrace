-- ═══════════════════════════════════════════════════════════════════════════
--
--  PROJECT  : TreatTrace
--  FILE     : database/features/02_health_profile.sql
--  PURPOSE  : Self-contained, idempotent setup for the health profile feature.
--             Covers: health_profiles table, indexes, trigger, RLS.
--
--  HOW TO RUN
--  ──────────
--  Dashboard → SQL Editor → New query → paste this file → Run
--  Safe to run multiple times (idempotent).
--
--  PREREQUISITE
--  ────────────
--  Run 01_auth_profiles.sql first (or treattrace_schema.sql for a full setup).
--  This file depends on auth.users existing (managed by Supabase).
--  set_updated_at() is re-declared here with CREATE OR REPLACE so this file
--  can also be run standalone without 01_auth_profiles.sql.
--
--  WHAT THIS FILE OWNS
--  ───────────────────
--  • Extension: pgcrypto, uuid-ossp (safe to re-declare)
--  • Type: blood_group_type enum
--  • Function: set_updated_at() (re-declared — safe)
--  • Table: public.health_profiles
--  • Index on health_profiles
--  • Trigger on health_profiles
--  • RLS policies on health_profiles
--
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- EXTENSIONS (safe to re-declare with IF NOT EXISTS)
-- ─────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ─────────────────────────────────────────────────────────────────────────
-- TYPE: blood_group_type
-- Safe DO block — skips silently if the enum already exists.
-- ─────────────────────────────────────────────────────────────────────────

DO $$ BEGIN
  CREATE TYPE public.blood_group_type AS ENUM (
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  );
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;


-- ─────────────────────────────────────────────────────────────────────────
-- FUNCTION: set_updated_at()
-- Redeclared here so this file is self-contained.
-- CREATE OR REPLACE is idempotent — no harm if already defined.
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────
-- TABLE: public.health_profiles
--
-- One optional row per user (no row = new user with no health data saved).
-- All health columns are nullable — the app shows empty states when null.
-- BMI is NEVER stored; Flutter computes it from height_cm and weight_kg.
--
-- height_cm : stored in cm; Flutter UI displays as ft + in.
--   Conversion: cm = (feet * 12 + inches) * 2.54
-- weight_kg : stored in kg.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.health_profiles (
  id                UUID          PRIMARY KEY
                                  REFERENCES auth.users(id) ON DELETE CASCADE,
  blood_group       TEXT          CHECK (
                                    blood_group IN (
                                      'A+','A-','B+','B-','AB+','AB-','O+','O-'
                                    )
                                  ),
  age               INTEGER       CHECK (age > 0 AND age <= 120),
  height_cm         DECIMAL(5,2)  CHECK (height_cm > 0),
  weight_kg         DECIMAL(5,2)  CHECK (weight_kg > 0),
  allergies         TEXT,
  ongoing_treatment TEXT,
  emergency_name    TEXT,
  emergency_phone   TEXT,
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);


-- ─────────────────────────────────────────────────────────────────────────
-- INDEX
-- ─────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_health_profiles_blood_group
  ON public.health_profiles (blood_group);


-- ─────────────────────────────────────────────────────────────────────────
-- TRIGGER
-- ─────────────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS set_health_profiles_updated_at
  ON public.health_profiles;

CREATE TRIGGER set_health_profiles_updated_at
  BEFORE UPDATE ON public.health_profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


-- ─────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────────────

ALTER TABLE public.health_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own health profile"
  ON public.health_profiles;
CREATE POLICY "Users can view own health profile"
  ON public.health_profiles
  FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own health profile"
  ON public.health_profiles;
CREATE POLICY "Users can insert own health profile"
  ON public.health_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own health profile"
  ON public.health_profiles;
CREATE POLICY "Users can update own health profile"
  ON public.health_profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- No DELETE policy — health data deletion requires a full account-deletion
-- flow (future feature). Default-deny RLS blocks direct client deletes.


-- ═══════════════════════════════════════════════════════════════════════════
-- END OF FILE — database/features/02_health_profile.sql
-- ═══════════════════════════════════════════════════════════════════════════
