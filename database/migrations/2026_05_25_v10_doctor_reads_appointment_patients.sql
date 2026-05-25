-- =============================================================================
-- MIGRATION : 2026_05_25_v10_doctor_reads_appointment_patients.sql
-- PURPOSE   : Allow doctors to read data of patients they have appointments
--             with (in addition to linked patients which were already covered).
-- DATE      : 2026-05-25
-- =============================================================================

-- 1. profiles — doctor can read profile of any patient with an appointment
CREATE POLICY "doctor_reads_appt_patient_profile"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.doctor_user_id = auth.uid()
        AND a.user_id = profiles.id
    )
  );

-- 2. health_profiles — doctor can read health profile of appointment patients
CREATE POLICY "doctor_reads_appt_patient_health"
  ON public.health_profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.doctor_user_id = auth.uid()
        AND a.user_id = health_profiles.id
    )
  );

-- 3. prescriptions — doctor can read prescriptions of appointment patients
CREATE POLICY "doctor_reads_appt_patient_rx"
  ON public.prescriptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.doctor_user_id = auth.uid()
        AND a.user_id = prescriptions.user_id
    )
  );

-- 4. lab_reports — doctor can read lab reports of appointment patients
CREATE POLICY "doctor_reads_appt_patient_labs"
  ON public.lab_reports FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.doctor_user_id = auth.uid()
        AND a.user_id = lab_reports.user_id
    )
  );
