-- =============================================================================
-- MIGRATION : 2026_05_25_v09_visiting_fee_fix_approve_edit.sql
-- PURPOSE   : Add visiting_fee to doctor_verifications; fix approve_doctor_edit
--             RPC to copy degree, about, visiting_fee when approving edits
-- DATE      : 2026-05-25
--
-- Run this in Supabase SQL Editor (already applied via MCP).
-- =============================================================================

-- 1) Add visiting_fee columns
ALTER TABLE public.doctor_verifications
  ADD COLUMN IF NOT EXISTS visiting_fee         INTEGER,
  ADD COLUMN IF NOT EXISTS pending_visiting_fee INTEGER;

-- 2) Recreate approve_doctor_edit to include all pending fields
CREATE OR REPLACE FUNCTION public.approve_doctor_edit(p_doctor_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.doctor_verifications SET
    bmdc_number          = COALESCE(pending_bmdc,          bmdc_number),
    specialty            = COALESCE(pending_specialty,      specialty),
    hospital             = COALESCE(pending_hospital,       hospital),
    nid_passport         = COALESCE(pending_nid_passport,   nid_passport),
    degree               = COALESCE(pending_degree,         degree),
    about                = COALESCE(pending_about,          about),
    visiting_fee         = COALESCE(pending_visiting_fee,   visiting_fee),
    additional_info      = COALESCE(pending_additional,     additional_info),
    pending_bmdc         = NULL,
    pending_specialty    = NULL,
    pending_hospital     = NULL,
    pending_nid_passport = NULL,
    pending_degree       = NULL,
    pending_about        = NULL,
    pending_visiting_fee = NULL,
    pending_additional   = NULL,
    edit_status          = NULL,
    edit_rejection_reason = NULL,
    reviewed_at          = now(),
    reviewed_by          = auth.uid()
  WHERE id = p_doctor_id AND edit_status = 'pending';
END;
$$;
