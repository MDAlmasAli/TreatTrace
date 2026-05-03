-- ═══════════════════════════════════════════════════════════════════════════
--
--  PROJECT  : TreatTrace
--  FILE     : database/treattrace_schema.sql
--  PURPOSE  : Single canonical SQL file for the entire TreatTrace database.
--             Run this file in Supabase SQL Editor to set up a fresh instance,
--             or use it as the authoritative reference for the schema.
--
--  HOW TO RUN
--  ──────────
--  Dashboard → SQL Editor → New query → paste this entire file → Run
--
--  MERGED FROM (do not run those files separately anymore)
--  ────────────────────────────────────────────────────────
--  ✔ supabase_setup.sql         → profiles table + handle_new_user trigger
--  ✔ health_profile_setup.sql   → health_profiles table + RLS
--
--  IDEMPOTENT
--  ──────────
--  This script uses IF NOT EXISTS, CREATE OR REPLACE, and DROP IF EXISTS
--  so it is safe to run more than once on the same database.
--
--  DEPENDENCIES
--  ────────────
--  • Supabase project with Auth enabled
--  • auth.users table managed by Supabase (do not modify it directly)
--
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1 — EXTENSIONS
-- ═══════════════════════════════════════════════════════════════════════════
--
-- pgcrypto  : provides gen_random_uuid() for UUID generation.
--             Supabase enables this by default; included here for clarity
--             when running against a plain PostgreSQL instance.
--
-- uuid-ossp : alternative UUID generator. Enabled for compatibility.
-- ─────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2 — CUSTOM TYPES / ENUMS
-- ═══════════════════════════════════════════════════════════════════════════
--
-- blood_group_type
--   Defines the eight recognised ABO + Rh blood group values.
--   The health_profiles table uses a TEXT + CHECK constraint for backward
--   compatibility with any existing rows. This enum is defined here as the
--   canonical type reference; migrate the column when convenient:
--
--     ALTER TABLE public.health_profiles
--       ALTER COLUMN blood_group TYPE public.blood_group_type
--       USING blood_group::public.blood_group_type;
-- ─────────────────────────────────────────────────────────────────────────

DO $$ BEGIN
  CREATE TYPE public.blood_group_type AS ENUM (
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  );
EXCEPTION
  WHEN duplicate_object THEN
    NULL; -- silently skip if already exists
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3 — FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Functions must be created BEFORE the triggers that call them.
-- All functions live in the `public` schema.
-- ─────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────
-- FUNCTION: set_updated_at()
-- ─────────────────────────────────────────────────────────────────────────
-- Purpose   : Automatically stamps `updated_at` to NOW() on every UPDATE.
-- Used by   : set_profiles_updated_at trigger
--             set_health_profiles_updated_at trigger
--             (all future tables with an `updated_at` column)
-- Returns   : The modified NEW row (required by PostgreSQL trigger protocol).
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
-- FUNCTION: handle_new_user()
-- ─────────────────────────────────────────────────────────────────────────
-- Purpose   : Fires when a new row is inserted into auth.users (i.e. when a
--             user signs up). Automatically creates a matching row in
--             public.profiles so the app always has a profile to read.
-- Security  : SECURITY DEFINER — runs as the function owner (postgres), not
--             the calling role. This is required because the trigger fires in
--             the context of auth.users which is outside the public schema.
-- Source    : full_name is read from raw_user_meta_data, which Flutter
--             populates via AuthService.signUp(data: {'full_name': ...}).
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.email
  );
  RETURN NEW;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4 — CORE TABLES
-- ═══════════════════════════════════════════════════════════════════════════


-- =========================================================
-- TABLE: profiles
-- =========================================================
--
-- Purpose     : Stores supplementary user information that Supabase Auth
--               does not hold by default (display name, avatar URL, etc.).
--               This table is the single source of truth for who the user is
--               within the TreatTrace app.
--
-- Key columns :
--   id          → Matches auth.users(id) exactly (1-to-1 relationship).
--   full_name   → Set at sign-up via raw_user_meta_data in handle_new_user().
--   email       → Denormalised copy of the auth email for convenience.
--   avatar_url  → Will store a Supabase Storage URL when photo upload is added.
--
-- Relationships:
--   auth.users(id) ← profiles.id  (FK, CASCADE DELETE)
--   profiles.id    → health_profiles.id  (1-to-1, optional)
--
-- RLS note    : Each user can only SELECT / UPDATE / INSERT their own row.
--               The auto-insert happens via the handle_new_user() trigger
--               which runs as SECURITY DEFINER, bypassing the INSERT policy.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID        PRIMARY KEY
                          REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT,
  email       TEXT,
  avatar_url  TEXT,
  phone       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =========================================================
-- TABLE: health_profiles
-- =========================================================
--
-- Purpose     : Stores a user's personal health data. Kept separate from
--               `profiles` because this data is sensitive and optional — new
--               users start with no row in this table (null state). The row is
--               created only when the user saves health data for the first time.
--
-- Key columns :
--   id                → Same UUID as auth.users / profiles (1-to-1).
--   blood_group       → One of the eight ABO+Rh types; validated by CHECK.
--   age               → Stored as years; validated 1–120.
--   height_cm         → Stored in centimetres; Flutter UI converts to ft+in.
--   weight_kg         → Stored in kilograms.
--   allergies         → Free text; can contain multiple allergies, newline-separated.
--   ongoing_treatment → Free text description of current medications/treatments.
--   emergency_name    → ICE (In Case of Emergency) contact full name.
--   emergency_phone   → ICE contact phone number.
--
-- Computed:
--   BMI is NEVER stored. It is always calculated on the Flutter client:
--   BMI = weight_kg / (height_cm / 100)²
--
-- Relationships:
--   auth.users(id) ← health_profiles.id  (FK, CASCADE DELETE)
--
-- RLS note    : User can SELECT / INSERT / UPDATE only their own row.
--               No DELETE policy — deleting health data requires a dedicated
--               account-deletion flow (future feature).
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
  -- Note: no created_at here — the profiles table already records when the
  -- user joined; health_profiles.updated_at covers all write timestamps.
);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5 — RELATIONSHIP / JUNCTION TABLES
-- ═══════════════════════════════════════════════════════════════════════════
--
-- No junction tables exist yet.
--
-- PLANNED (add here when implementing):
--
--   user_saved_doctors   — users ↔ doctors (M:N bookmark/follow)
--   appointment_records  — users ↔ doctors with date + status
--   prescription_items   — prescriptions linked to an appointment
--   test_report_files    — file references for uploaded lab reports
--
-- See SECTION 11 (Future Table Template) for the boilerplate to use.
-- ─────────────────────────────────────────────────────────────────────────

-- (empty — reserved for future junction tables)


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6 — INDEXES
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Primary key columns are indexed automatically by PostgreSQL.
-- Add explicit indexes only for:
--   • Foreign key columns used in JOIN / WHERE clauses
--   • Columns frequently searched (e.g. email lookups by admin)
-- ─────────────────────────────────────────────────────────────────────────

-- profiles: fast lookup by email (admin queries, duplicate-check)
CREATE INDEX IF NOT EXISTS idx_profiles_email
  ON public.profiles (email);

-- profiles: fast lookup by full_name (future doctor search by name)
CREATE INDEX IF NOT EXISTS idx_profiles_full_name
  ON public.profiles (full_name);

-- profiles: fast lookup by phone
CREATE INDEX IF NOT EXISTS idx_profiles_phone
  ON public.profiles (phone);

-- health_profiles: index on blood_group for potential future group queries
CREATE INDEX IF NOT EXISTS idx_health_profiles_blood_group
  ON public.health_profiles (blood_group);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 7 — TRIGGERS
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Naming convention: <action>_<table>  or  on_<event>_<table>
-- All functions that triggers call are defined in SECTION 3.
-- ─────────────────────────────────────────────────────────────────────────

-- Trigger: on_auth_user_created
-- Fires   : AFTER INSERT on auth.users (when a new user signs up)
-- Action  : Calls handle_new_user() to create the public.profiles row.

DROP TRIGGER IF EXISTS on_auth_user_created
  ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();


-- Trigger: set_profiles_updated_at
-- Fires   : BEFORE UPDATE on public.profiles
-- Action  : Stamps updated_at to NOW() automatically.

DROP TRIGGER IF EXISTS set_profiles_updated_at
  ON public.profiles;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


-- Trigger: set_health_profiles_updated_at
-- Fires   : BEFORE UPDATE on public.health_profiles
-- Action  : Stamps updated_at to NOW() automatically.

DROP TRIGGER IF EXISTS set_health_profiles_updated_at
  ON public.health_profiles;

CREATE TRIGGER set_health_profiles_updated_at
  BEFORE UPDATE ON public.health_profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 8 — ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════════════════════════════════
--
-- RLS is Supabase's primary defence layer.
-- Rule: EVERY table in public schema must have RLS enabled.
-- Rule: Default-deny — if no policy matches, the row is invisible.
--
-- auth.uid() returns the UUID of the currently authenticated user.
-- Policies compare this against the table's `id` column (which mirrors
-- auth.users.id) to ensure users can only touch their own data.
-- ─────────────────────────────────────────────────────────────────────────

-- ── public.profiles ──────────────────────────────────────────────────────

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT — user reads their own profile row only.
DROP POLICY IF EXISTS "Users can view own profile"
  ON public.profiles;

CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);


-- Policy: UPDATE — user modifies their own profile row only.
DROP POLICY IF EXISTS "Users can update own profile"
  ON public.profiles;

CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id);


-- Policy: INSERT — required so the handle_new_user() trigger can write a
--         row on behalf of the new user.
--         Note: the trigger runs as SECURITY DEFINER (postgres role) which
--         bypasses RLS, but this policy is kept for direct client inserts.
DROP POLICY IF EXISTS "Users can insert own profile"
  ON public.profiles;

CREATE POLICY "Users can insert own profile"
  ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);


-- ── public.health_profiles ────────────────────────────────────────────────

ALTER TABLE public.health_profiles ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT — user reads their own health data only.
DROP POLICY IF EXISTS "Users can view own health profile"
  ON public.health_profiles;

CREATE POLICY "Users can view own health profile"
  ON public.health_profiles
  FOR SELECT
  USING (auth.uid() = id);


-- Policy: INSERT — user creates their health profile row for the first time.
DROP POLICY IF EXISTS "Users can insert own health profile"
  ON public.health_profiles;

CREATE POLICY "Users can insert own health profile"
  ON public.health_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);


-- Policy: UPDATE — user edits their existing health data.
DROP POLICY IF EXISTS "Users can update own health profile"
  ON public.health_profiles;

CREATE POLICY "Users can update own health profile"
  ON public.health_profiles
  FOR UPDATE
  USING (auth.uid() = id);


-- ── DELETE policies ───────────────────────────────────────────────────────
-- Intentionally omitted for both tables.
-- Health data deletion is a sensitive action that should only happen
-- as part of a full account-deletion flow (future feature). Direct row
-- deletion by the client is disabled by default-deny RLS.


-- ── storage.objects (avatars bucket) ─────────────────────────────────────
--
-- Prerequisites: create the `avatars` bucket in the Supabase dashboard first:
--   Storage → New bucket → Name: "avatars" → Public: OFF → Save
--
-- Files are uploaded to "<uid>/avatar.<ext>" so foldername(name)[1] = uid.

DROP POLICY IF EXISTS "Avatar upload — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Avatar read  — own folder only"   ON storage.objects;
DROP POLICY IF EXISTS "Avatar update — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Avatar delete — own folder only"  ON storage.objects;

CREATE POLICY "Avatar upload — own folder only"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Avatar read  — own folder only"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Avatar update — own folder only"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Avatar delete — own folder only"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 9 — SEED / SAMPLE DATA
-- ═══════════════════════════════════════════════════════════════════════════
--
-- No seed data for production.
-- Seed data (test users, sample doctors) belongs in a separate file:
--   database/seed_dev.sql    ← development / testing only
--
-- EXAMPLE (do not uncomment in production):
--
-- INSERT INTO public.profiles (id, full_name, email)
-- VALUES (
--   '00000000-0000-0000-0000-000000000001',
--   'Test User',
--   'test@treattrace.app'
-- );
-- ─────────────────────────────────────────────────────────────────────────

-- (empty — seed data is environment-specific)


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 10 — FUTURE TABLE TEMPLATE
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Copy-paste this block whenever you need to add a new table.
-- Replace all <PLACEHOLDER> values before running.
--
-- CHECKLIST for adding a new table:
--   [ ] Define the table in SECTION 4 (core) or SECTION 5 (junction)
--   [ ] Add indexes in SECTION 6
--   [ ] Add updated_at trigger in SECTION 7
--   [ ] Enable RLS + add policies in SECTION 8
--   [ ] Add table to SECTION 11 changelog
-- ─────────────────────────────────────────────────────────────────────────

/*

-- =========================================================
-- TABLE: <table_name>
-- =========================================================
--
-- Purpose     : <what this table stores>
-- Key columns :
--   id         → <description>
--   user_id    → FK to auth.users / profiles
--   <col>      → <description>
--
-- Relationships:
--   auth.users(id) ← <table_name>.user_id
--   <other_table>  ← <table_name>.<fk_col>
--
-- RLS note    : <who can access this data and why>
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.<table_name> (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- <add columns here>
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Index on FK
CREATE INDEX IF NOT EXISTS idx_<table_name>_user_id
  ON public.<table_name> (user_id);

-- updated_at trigger
DROP TRIGGER IF EXISTS set_<table_name>_updated_at
  ON public.<table_name>;

CREATE TRIGGER set_<table_name>_updated_at
  BEFORE UPDATE ON public.<table_name>
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

-- RLS
ALTER TABLE public.<table_name> ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own <table_name>"
  ON public.<table_name>;
CREATE POLICY "Users can view own <table_name>"
  ON public.<table_name>
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own <table_name>"
  ON public.<table_name>;
CREATE POLICY "Users can insert own <table_name>"
  ON public.<table_name>
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own <table_name>"
  ON public.<table_name>;
CREATE POLICY "Users can update own <table_name>"
  ON public.<table_name>
  FOR UPDATE
  USING (auth.uid() = user_id);

*/


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 11 — CHANGELOG
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Record every schema change here. Newest entry at the top.
-- Format:
--   -- [YYYY-MM-DD] vX.X — Short description
--   --   • Detail
--   --   • Detail
-- ─────────────────────────────────────────────────────────────────────────

-- [2026-05-03] v0.4 — Profile account settings added
--   • profiles: phone TEXT column
--   • Index: idx_profiles_phone
--   • Storage RLS: INSERT / SELECT / UPDATE / DELETE for avatars bucket
--     (requires creating the `avatars` bucket in Supabase dashboard first)

-- [2026-05-03] v0.3 — Consolidated schema file created
--   • Merged supabase_setup.sql → profiles table, handle_new_user(), set_updated_at()
--   • Merged health_profile_setup.sql → health_profiles table + RLS
--   • Added pgcrypto + uuid-ossp extensions block
--   • Added blood_group_type enum (defined; column still uses TEXT + CHECK)
--   • Added DROP POLICY IF EXISTS guards on all policies (idempotent)
--   • Added indexes: idx_profiles_email, idx_profiles_full_name,
--     idx_health_profiles_blood_group
--   • Added future table template (Section 10)
--   • Reorganised into 11 numbered sections

-- [2026-05-03] v0.2 — health_profiles table added (health_profile_setup.sql)
--   • health_profiles: blood_group, age, height_cm, weight_kg,
--     allergies, ongoing_treatment, emergency_name, emergency_phone
--   • RLS: SELECT / INSERT / UPDATE for own row
--   • Trigger: set_health_profiles_updated_at

-- [2026-04-30] v0.1 — Initial schema (supabase_setup.sql)
--   • profiles table: id, full_name, email, avatar_url, timestamps
--   • RLS: SELECT / UPDATE / INSERT for own row
--   • Function: handle_new_user() — auto-creates profile on sign-up
--   • Function: set_updated_at() — auto-stamps updated_at on UPDATE
--   • Trigger: on_auth_user_created (on auth.users)
--   • Trigger: set_profiles_updated_at


-- ═══════════════════════════════════════════════════════════════════════════
-- END OF FILE
-- treattrace_schema.sql — TreatTrace v0.4
-- ═══════════════════════════════════════════════════════════════════════════
