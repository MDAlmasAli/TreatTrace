-- ═══════════════════════════════════════════════════════════════════════════
--
--  PROJECT  : TreatTrace
--  FILE     : database/features/01_auth_profiles.sql
--  PURPOSE  : Self-contained, idempotent setup for the auth/profiles feature.
--             Covers: profiles table, handle_new_user() trigger, RLS.
--
--  HOW TO RUN
--  ──────────
--  Dashboard → SQL Editor → New query → paste this file → Run
--  Safe to run multiple times (idempotent).
--
--  WHAT THIS FILE OWNS
--  ───────────────────
--  • Extensions (pgcrypto, uuid-ossp)
--  • Function: set_updated_at()
--  • Function: handle_new_user()
--  • Table: public.profiles
--  • Indexes on profiles
--  • Triggers on profiles + auth.users
--  • RLS policies on profiles
--
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ─────────────────────────────────────────────────────────────────────────
-- FUNCTION: set_updated_at()
-- Shared utility — stamps updated_at = NOW() on every UPDATE.
-- Defined with CREATE OR REPLACE so it is safe to re-run.
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
-- Fires on INSERT to auth.users. Creates the matching public.profiles row.
-- SECURITY DEFINER: runs as postgres role to bypass RLS on auth.users.
-- full_name is read from raw_user_meta_data set by Flutter at sign-up.
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


-- ─────────────────────────────────────────────────────────────────────────
-- TABLE: public.profiles
-- One row per user, mirroring auth.users.id (1-to-1).
-- Auto-created by handle_new_user() trigger on sign-up.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID        PRIMARY KEY
                          REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT,
  email       TEXT,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ─────────────────────────────────────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_profiles_email
  ON public.profiles (email);

CREATE INDEX IF NOT EXISTS idx_profiles_full_name
  ON public.profiles (full_name);


-- ─────────────────────────────────────────────────────────────────────────
-- TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────

-- on_auth_user_created: auto-creates profiles row when a user signs up.
DROP TRIGGER IF EXISTS on_auth_user_created
  ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();


-- set_profiles_updated_at: stamps updated_at on every profile UPDATE.
DROP TRIGGER IF EXISTS set_profiles_updated_at
  ON public.profiles;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


-- ─────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────────────

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile"
  ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile"
  ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile"
  ON public.profiles;
CREATE POLICY "Users can insert own profile"
  ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);


-- ═══════════════════════════════════════════════════════════════════════════
-- END OF FILE — database/features/01_auth_profiles.sql
-- ═══════════════════════════════════════════════════════════════════════════
