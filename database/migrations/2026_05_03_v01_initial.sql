-- ═══════════════════════════════════════════════════════════════════════════
--
--  PROJECT   : TreatTrace
--  FILE      : database/migrations/2026_05_03_v01_initial.sql
--  VERSION   : v0.1
--  DATE      : 2026-05-03
--  AUTHOR    : MD Almas Ali
--
--  PURPOSE   : Historical snapshot of the initial TreatTrace database schema.
--              This is a RECORD of what was applied on 2026-04-30.
--              Do NOT re-run this on a database that has already been set up —
--              use treattrace_schema.sql for a fresh setup instead.
--
--  WHAT WAS ADDED IN v0.1
--  ───────────────────────
--  • Extensions: pgcrypto, uuid-ossp
--  • Function: set_updated_at()
--  • Function: handle_new_user() — auto-creates profile on sign-up
--  • Table: public.profiles (id, full_name, email, avatar_url, timestamps)
--  • Trigger: on_auth_user_created (auth.users → handle_new_user)
--  • Trigger: set_profiles_updated_at
--  • RLS: SELECT / UPDATE / INSERT policies on public.profiles
--
-- ═══════════════════════════════════════════════════════════════════════════


CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


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


CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID        PRIMARY KEY
                          REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT,
  email       TEXT,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


DROP TRIGGER IF EXISTS on_auth_user_created
  ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();


DROP TRIGGER IF EXISTS set_profiles_updated_at
  ON public.profiles;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


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
-- END OF FILE — database/migrations/2026_05_03_v01_initial.sql
-- ═══════════════════════════════════════════════════════════════════════════
