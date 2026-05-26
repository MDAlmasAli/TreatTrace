-- =============================================================================
-- MIGRATION : 2026_05_26_v14_auto_link_appointment_patient.sql
-- PURPOSE   : SECURITY DEFINER function so a doctor can auto-create an
--             accepted doctor_patient_links row after writing a prescription
--             for an appointment patient (bypasses normal request/accept flow).
-- DATE      : 2026-05-26
-- =============================================================================

CREATE OR REPLACE FUNCTION public.auto_link_appointment_patient(p_patient_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doctor_id uuid := auth.uid();
BEGIN
  IF NOT doctor_has_appointment_with(p_patient_id) THEN
    RAISE EXCEPTION 'auto_link_appointment_patient: no appointment found';
  END IF;

  INSERT INTO public.doctor_patient_links
    (doctor_id, patient_id, status, requested_at, accepted_at)
  VALUES
    (v_doctor_id, p_patient_id, 'accepted', now(), now())
  ON CONFLICT (doctor_id, patient_id)
  DO UPDATE SET
    status      = 'accepted',
    accepted_at = now()
  WHERE doctor_patient_links.status <> 'accepted';
END;
$$;
