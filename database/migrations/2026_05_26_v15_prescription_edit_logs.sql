-- =============================================================================
-- MIGRATION : 2026_05_26_v15_prescription_edit_logs.sql
-- PURPOSE   : Track per-day create/edit history for each prescription.
--             Unique on (prescription_id, action_date) so same-day edits
--             produce only one row (upsert ignoreDuplicates).
-- DATE      : 2026-05-26
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.prescription_edit_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id UUID NOT NULL REFERENCES public.prescriptions(id) ON DELETE CASCADE,
  doctor_id       UUID NOT NULL REFERENCES auth.users(id)            ON DELETE CASCADE,
  action_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  action          TEXT NOT NULL CHECK (action IN ('created', 'edited')),
  UNIQUE (prescription_id, action_date)
);

ALTER TABLE public.prescription_edit_logs ENABLE ROW LEVEL SECURITY;

-- Doctors can insert their own logs
CREATE POLICY "doctor_inserts_own_log" ON public.prescription_edit_logs
  FOR INSERT TO authenticated
  WITH CHECK (doctor_id = auth.uid());

-- Any authenticated user can read logs (prescription RLS already restricts access)
CREATE POLICY "authenticated_reads_logs" ON public.prescription_edit_logs
  FOR SELECT TO authenticated
  USING (true);
