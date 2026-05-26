-- =============================================================================
-- MIGRATION : 2026_05_26_v11_fix_rls_circular_reference.sql
-- PURPOSE   : Fix HTTP 500 on fetchProfile() caused by circular RLS evaluation:
--               profiles → doctor_reads_appt_patient_profile → appointments
--               appointments → doctor_reads_by_name_snapshot  → profiles
--             Solution: wrap the appointments subquery in a SECURITY DEFINER
--             function so it bypasses appointments RLS, breaking the cycle.
-- DATE      : 2026-05-26
-- =============================================================================

-- Security-definer helper: reads appointments without triggering their RLS policies.
CREATE OR REPLACE FUNCTION public.doctor_has_appointment_with(p_patient_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.appointments
    WHERE doctor_user_id = auth.uid()
      AND user_id = p_patient_id
  );
$$;

-- profiles
DROP POLICY IF EXISTS "doctor_reads_appt_patient_profile" ON public.profiles;
CREATE POLICY "doctor_reads_appt_patient_profile" ON public.profiles FOR SELECT
  USING (public.doctor_has_appointment_with(profiles.id));

-- health_profiles
DROP POLICY IF EXISTS "doctor_reads_appt_patient_health" ON public.health_profiles;
CREATE POLICY "doctor_reads_appt_patient_health" ON public.health_profiles FOR SELECT
  USING (public.doctor_has_appointment_with(health_profiles.id));

-- prescriptions
DROP POLICY IF EXISTS "doctor_reads_appt_patient_rx" ON public.prescriptions;
CREATE POLICY "doctor_reads_appt_patient_rx" ON public.prescriptions FOR SELECT
  USING (public.doctor_has_appointment_with(prescriptions.user_id));

-- lab_reports
DROP POLICY IF EXISTS "doctor_reads_appt_patient_labs" ON public.lab_reports;
CREATE POLICY "doctor_reads_appt_patient_labs" ON public.lab_reports FOR SELECT
  USING (public.doctor_has_appointment_with(lab_reports.user_id));
