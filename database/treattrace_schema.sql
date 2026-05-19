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
-- PLANNED (add here when implementing):
--
--   user_saved_doctors   — users ↔ doctors (M:N bookmark/follow)
--   appointment_records  — users ↔ doctors with date + status
--   prescription_items   — prescriptions linked to an appointment
--
-- ─────────────────────────────────────────────────────────────────────────

-- =========================================================
-- TABLE: lab_reports
-- =========================================================
--
-- Purpose     : Stores each user's lab/test report metadata and uploaded
--               image references. category is free TEXT so users can supply
--               their own names in addition to the app's preset list.
--               prescription_id is an optional FK — deleting the linked
--               prescription sets it to NULL (ON DELETE SET NULL).
--
-- Key columns :
--   test_name       → Name of the test (required)
--   category        → E.g. "Blood Test", "X-Ray", or any custom string
--   test_date       → DATE when the test was taken (optional)
--   doctor_name     → Referring/ordering doctor (optional)
--   hospital        → Lab or hospital name (optional)
--   image_urls      → Array of Supabase Storage signed URLs
--   notes           → Free text result notes (optional)
--   prescription_id → FK → prescriptions.id (nullable)
--
-- Storage bucket : lab_reports (private)
--   Files stored at: <uid>/<timestamp>.<ext>
--   Create the bucket in Supabase Dashboard before running this file.
--
-- RLS note    : User can SELECT / INSERT / UPDATE / DELETE only their own rows.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.lab_reports (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  test_name       TEXT          NOT NULL,
  category        TEXT,
  test_date       DATE,
  doctor_name     TEXT,
  hospital        TEXT,
  image_urls      TEXT[]        NOT NULL DEFAULT '{}',
  notes           TEXT,
  prescription_id UUID          REFERENCES public.prescriptions(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);


-- =========================================================
-- TABLE: doctors
-- =========================================================
--
-- Purpose     : Personal doctor address book per user. Stores contact and
--               chamber details for each doctor the user has visited.
--               is_favorite allows users to pin their most-used doctors.
--
-- Key columns :
--   name            → Doctor's name (required, stored without "Dr." prefix)
--   specialty       → e.g. "Cardiologist", free text
--   hospital        → Primary hospital / clinic name
--   chamber_address → Physical address of the chamber
--   phone           → Contact number
--   fee             → Consultation fee (stored as free text, e.g. "৳ 800")
--   notes           → Additional free-text info
--   is_favorite     → User-defined bookmark flag
--
-- RLS note    : User can SELECT / INSERT / UPDATE / DELETE only their own rows.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.doctors (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT          NOT NULL,
  specialty       TEXT,
  hospital        TEXT,
  chamber_address TEXT,
  phone           TEXT,
  fee             TEXT,
  notes           TEXT,
  is_favorite     BOOLEAN       NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);


-- =========================================================
-- TABLE: appointments
-- =========================================================
--
-- Purpose     : Log of all patient appointments. doctor_id is nullable so
--               an appointment row survives if the user deletes the doctor
--               record. doctor_name_snapshot preserves the name at booking
--               time as a fallback display value.
--
-- Key columns :
--   doctor_id           → FK → doctors.id (SET NULL on doctor deletion)
--   doctor_name_snapshot→ Doctor's name frozen at booking time
--   appointment_date    → DATE of the appointment (required)
--   appointment_time    → Free-text time string, e.g. "10:30 AM" (optional)
--   visit_reason        → Why the patient visited (optional)
--   status              → 'scheduled' | 'completed' | 'cancelled'
--   notes               → Post-visit notes (optional)
--   prescription_id     → FK → prescriptions.id (SET NULL on deletion)
--
-- RLS note    : User can SELECT / INSERT / UPDATE / DELETE only their own rows.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.appointments (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doctor_id             UUID          REFERENCES public.doctors(id) ON DELETE SET NULL,
  doctor_name_snapshot  TEXT          NOT NULL,
  appointment_date      DATE          NOT NULL,
  appointment_time      TEXT,
  visit_reason          TEXT,
  status                TEXT          NOT NULL DEFAULT 'scheduled'
                                      CHECK (status IN ('scheduled','completed','cancelled')),
  notes                 TEXT,
  prescription_id       UUID          REFERENCES public.prescriptions(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6 — INDEXES
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Primary key columns are indexed automatically by PostgreSQL.
-- Add explicit indexes only for:
--   • Foreign key columns used in JOIN / WHERE clauses
--   • Columns frequently searched (e.g. email lookups by admin)
-- ─────────────────────────────────────────────────────────────────────────

-- doctors: lookup by user + favorite flag
CREATE INDEX IF NOT EXISTS idx_doctors_user_id
  ON public.doctors (user_id);

CREATE INDEX IF NOT EXISTS idx_doctors_is_favorite
  ON public.doctors (user_id, is_favorite DESC);

-- appointments: lookup by user, doctor, date, status
CREATE INDEX IF NOT EXISTS idx_appointments_user_id
  ON public.appointments (user_id);

CREATE INDEX IF NOT EXISTS idx_appointments_doctor_id
  ON public.appointments (doctor_id);

CREATE INDEX IF NOT EXISTS idx_appointments_date
  ON public.appointments (appointment_date DESC);

CREATE INDEX IF NOT EXISTS idx_appointments_status
  ON public.appointments (user_id, status);

-- lab_reports: fast lookup by user + date
CREATE INDEX IF NOT EXISTS idx_lab_reports_user_id
  ON public.lab_reports (user_id);

CREATE INDEX IF NOT EXISTS idx_lab_reports_test_date
  ON public.lab_reports (test_date DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_lab_reports_category
  ON public.lab_reports (category);

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


-- Trigger: set_lab_reports_updated_at
-- Fires   : BEFORE UPDATE on public.lab_reports
-- Action  : Stamps updated_at to NOW() automatically.

DROP TRIGGER IF EXISTS set_lab_reports_updated_at
  ON public.lab_reports;

CREATE TRIGGER set_lab_reports_updated_at
  BEFORE UPDATE ON public.lab_reports
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


-- Trigger: set_doctors_updated_at

DROP TRIGGER IF EXISTS set_doctors_updated_at ON public.doctors;

CREATE TRIGGER set_doctors_updated_at
  BEFORE UPDATE ON public.doctors
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


-- Trigger: set_appointments_updated_at

DROP TRIGGER IF EXISTS set_appointments_updated_at ON public.appointments;

CREATE TRIGGER set_appointments_updated_at
  BEFORE UPDATE ON public.appointments
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


-- ── public.lab_reports ───────────────────────────────────────────────────

ALTER TABLE public.lab_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own lab_reports"   ON public.lab_reports;
DROP POLICY IF EXISTS "Users can insert own lab_reports" ON public.lab_reports;
DROP POLICY IF EXISTS "Users can update own lab_reports" ON public.lab_reports;
DROP POLICY IF EXISTS "Users can delete own lab_reports" ON public.lab_reports;

CREATE POLICY "Users can view own lab_reports"
  ON public.lab_reports FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own lab_reports"
  ON public.lab_reports FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own lab_reports"
  ON public.lab_reports FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own lab_reports"
  ON public.lab_reports FOR DELETE USING (auth.uid() = user_id);


-- ── public.doctors ───────────────────────────────────────────────────────

ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own doctors"   ON public.doctors;
DROP POLICY IF EXISTS "Users can insert own doctors" ON public.doctors;
DROP POLICY IF EXISTS "Users can update own doctors" ON public.doctors;
DROP POLICY IF EXISTS "Users can delete own doctors" ON public.doctors;

CREATE POLICY "Users can view own doctors"
  ON public.doctors FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own doctors"
  ON public.doctors FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own doctors"
  ON public.doctors FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own doctors"
  ON public.doctors FOR DELETE USING (auth.uid() = user_id);


-- ── public.appointments ───────────────────────────────────────────────────

ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own appointments"   ON public.appointments;
DROP POLICY IF EXISTS "Users can insert own appointments" ON public.appointments;
DROP POLICY IF EXISTS "Users can update own appointments" ON public.appointments;
DROP POLICY IF EXISTS "Users can delete own appointments" ON public.appointments;

CREATE POLICY "Users can view own appointments"
  ON public.appointments FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own appointments"
  ON public.appointments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own appointments"
  ON public.appointments FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own appointments"
  ON public.appointments FOR DELETE USING (auth.uid() = user_id);


-- ── storage.objects (lab_reports bucket) ─────────────────────────────────
--
-- Prerequisites: create the `lab_reports` bucket in the Supabase dashboard:
--   Storage → New bucket → Name: "lab_reports" → Public: OFF → Save

DROP POLICY IF EXISTS "Lab report upload — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Lab report read  — own folder only"   ON storage.objects;
DROP POLICY IF EXISTS "Lab report update — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Lab report delete — own folder only"  ON storage.objects;

CREATE POLICY "Lab report upload — own folder only"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'lab_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Lab report read  — own folder only"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'lab_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Lab report update — own folder only"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'lab_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Lab report delete — own folder only"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'lab_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );


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

-- [2026-05-19] v0.7 — doctors + appointments tables added
--   • doctors: id, user_id, name, specialty, hospital, chamber_address,
--     phone, fee, notes, is_favorite, timestamps
--   • appointments: id, user_id, doctor_id (SET NULL), doctor_name_snapshot,
--     appointment_date, appointment_time, visit_reason, status CHECK, notes,
--     prescription_id (SET NULL), timestamps
--   • Indexes: doctors (user_id, is_favorite), appointments (user_id, doctor_id, date, status)
--   • Triggers: set_doctors_updated_at, set_appointments_updated_at
--   • RLS: SELECT / INSERT / UPDATE / DELETE for own rows on both tables
--   • Home screen: My Doctors + Appointments cards replace placeholder ActionCards

-- [2026-05-19] v0.6 — lab_reports table added
--   • lab_reports: id, user_id, test_name, category, test_date, doctor_name,
--     hospital, image_urls[], notes, prescription_id (nullable FK), timestamps
--   • Indexes: idx_lab_reports_user_id, _test_date, _category
--   • Trigger: set_lab_reports_updated_at
--   • RLS: SELECT / INSERT / UPDATE / DELETE for own rows
--   • Storage RLS: lab_reports bucket (own folder only)

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
-- treattrace_schema.sql — TreatTrace v0.7
-- ═══════════════════════════════════════════════════════════════════════════
