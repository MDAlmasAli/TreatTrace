-- =============================================================================
-- MIGRATION : 2026_05_26_v16_doctor_can_update_appointment_status.sql
-- PURPOSE   : Doctors had no UPDATE policy on appointments so updateStatus()
--             was silently blocked by RLS — appointment never moved to
--             'completed' after prescription save.
-- DATE      : 2026-05-26
-- =============================================================================

-- Allow the assigned doctor to update any field on their appointments
CREATE POLICY "doctor_updates_own_appointment" ON public.appointments
  FOR UPDATE TO authenticated
  USING  (auth.uid() = doctor_user_id)
  WITH CHECK (auth.uid() = doctor_user_id);

-- Allow the patient to update their own appointments (e.g. cancel)
CREATE POLICY "patient_updates_own_appointment" ON public.appointments
  FOR UPDATE TO authenticated
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
