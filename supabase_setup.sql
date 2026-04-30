-- ═══════════════════════════════════════════════════════════════════════════
-- TreatTrace — Supabase Database Setup
--
-- Run this entire file in your Supabase SQL Editor:
--   Dashboard → SQL Editor → New query → paste → Run
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. Profiles table ────────────────────────────────────────────────────────
-- Stores extra user data that Supabase Auth doesn't hold by default.
-- The `id` column is a foreign key to auth.users — one profile per user.

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT,
  email       TEXT,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ── 2. Row Level Security (RLS) ───────────────────────────────────────────────
-- RLS ensures each user can only access their OWN profile row.
-- Without this, any authenticated user could read every profile.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow a user to read their own profile.
CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Allow a user to update their own profile.
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- Allow a user to insert their own profile row (needed during sign-up trigger).
CREATE POLICY "Users can insert own profile"
  ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);


-- ── 3. Auto-create profile on sign-up ────────────────────────────────────────
-- When a new user registers, Supabase fires a trigger that automatically
-- inserts a matching row into public.profiles.
-- The full_name comes from the metadata we pass during signUp() in Flutter.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER           -- runs with the privileges of the function owner
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',   -- from AuthService.signUp(data:...)
    NEW.email
  );
  RETURN NEW;
END;
$$;

-- Drop the trigger first in case this script is run more than once.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();


-- ── 4. Auto-update `updated_at` on profile changes ────────────────────────────

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


-- ── Done ──────────────────────────────────────────────────────────────────────
-- Your profiles table is ready. New registrations will automatically create
-- a profile row. Users can only read/edit their own data.
