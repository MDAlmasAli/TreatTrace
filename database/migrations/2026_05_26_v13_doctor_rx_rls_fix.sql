-- =============================================================================
-- MIGRATION : 2026_05_26_v13_doctor_rx_rls_fix.sql
-- PURPOSE   : Fix RLS so doctors can write/edit prescriptions for appointment
--             patients (not just doctor_patient_links patients)
-- DATE      : 2026-05-26
-- =============================================================================

-- Fix 1: Allow doctors with appointments (not just linked patients) to insert prescriptions
DROP POLICY IF EXISTS "doctor_inserts_patient_rx" ON public.prescriptions;
CREATE POLICY "doctor_inserts_patient_rx" ON public.prescriptions
  FOR INSERT TO authenticated
  WITH CHECK (
    (user_id = auth.uid())
    OR (
      written_by_doctor_id = auth.uid()
      AND (
        EXISTS (
          SELECT 1 FROM public.doctor_patient_links l
          WHERE l.doctor_id = auth.uid()
            AND l.patient_id = prescriptions.user_id
            AND l.status = 'accepted'
        )
        OR doctor_has_appointment_with(user_id)
      )
    )
  );

-- Fix 2: Allow doctors to update prescriptions they wrote
DROP POLICY IF EXISTS "doctor_updates_own_written_rx" ON public.prescriptions;
CREATE POLICY "doctor_updates_own_written_rx" ON public.prescriptions
  FOR UPDATE TO authenticated
  USING  (written_by_doctor_id = auth.uid())
  WITH CHECK (written_by_doctor_id = auth.uid());
