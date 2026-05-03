-- ═══════════════════════════════════════════════════════════════════════════
--
--  PROJECT   : TreatTrace
--  FILE      : database/migrations/2026_05_03_v02_health_profile.sql
--  VERSION   : v0.2
--  DATE      : 2026-05-03
--  AUTHOR    : MD Almas Ali
--
--  PURPOSE   : Historical snapshot of the health_profiles migration.
--              This is a RECORD of what was applied on 2026-05-03.
--              Do NOT re-run this on a database that has already been set up —
--              use treattrace_schema.sql for a fresh setup instead.
--
--  PREREQUISITE
--  ────────────
--  Assumes v01_initial migration has already been applied (profiles table
--  and set_updated_at() function must exist).
--
--  WHAT WAS ADDED IN v0.2
--  ───────────────────────
--  • Type: blood_group_type enum
--  • Table: public.health_profiles
--      columns: id, blood_group, age, height_cm, weight_kg,
--               allergies, ongoing_treatment, emergency_name,
--               emergency_phone, updated_at
--  • Index: idx_health_profiles_blood_group
--  • Trigger: set_health_profiles_updated_at
--  • RLS: SELECT / INSERT / UPDATE policies on public.health_profiles
--
-- ═══════════════════════════════════════════════════════════════════════════


DO $$ BEGIN
  CREATE TYPE public.blood_group_type AS ENUM (
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  );
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;


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


CREATE INDEX IF NOT EXISTS idx_health_profiles_blood_group
  ON public.health_profiles (blood_group);


DROP TRIGGER IF EXISTS set_health_profiles_updated_at
  ON public.health_profiles;

CREATE TRIGGER set_health_profiles_updated_at
  BEFORE UPDATE ON public.health_profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


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


-- ═══════════════════════════════════════════════════════════════════════════
-- END OF FILE — database/migrations/2026_05_03_v02_health_profile.sql
-- ═══════════════════════════════════════════════════════════════════════════
