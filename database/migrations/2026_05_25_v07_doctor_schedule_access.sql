-- =============================================================================
-- MIGRATION : 2026_05_25_v07_doctor_schedule_access.sql
-- PURPOSE   : Make doctor schedule queries work for existing + new appointments
-- DATE      : 2026-05-25
--
-- Run this in Supabase SQL Editor.
-- =============================================================================

-- 1) Ensure appointments table has doctor_user_id
ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS doctor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_appointments_doctor_user_id
  ON public.appointments (doctor_user_id);

-- 2) Backfill doctor_user_id from local saved doctor rows (when doctor_id exists)
UPDATE public.appointments AS a
SET doctor_user_id = d.source_id::uuid
FROM public.doctors AS d
WHERE a.doctor_user_id IS NULL
  AND a.doctor_id = d.id
  AND d.source_id IS NOT NULL
  AND d.source_id ~* '^[0-9a-fA-F-]{36}$';

-- 3) Backfill doctor_user_id from doctor name snapshot (best effort)
UPDATE public.appointments AS a
SET doctor_user_id = p.id
FROM public.profiles AS p
WHERE a.doctor_user_id IS NULL
  AND p.role = 'doctor'
  AND (
    lower(trim(a.doctor_name_snapshot)) = lower(trim(p.full_name))
    OR lower(trim(a.doctor_name_snapshot)) = lower('dr. ' || trim(p.full_name))
    OR lower(trim(a.doctor_name_snapshot)) = lower('dr ' || trim(p.full_name))
  );

-- 4) Allow doctors to read appointments linked to them
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own appointments" ON public.appointments;
CREATE POLICY "Users can view own appointments"
  ON public.appointments FOR SELECT
  USING (
    auth.uid() = user_id
    OR auth.uid() = doctor_user_id
  );

