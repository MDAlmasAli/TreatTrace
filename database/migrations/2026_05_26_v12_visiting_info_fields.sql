-- =============================================================================
-- MIGRATION : 2026_05_26_v12_visiting_info_fields.sql
-- PURPOSE   : Add visiting_hours and chamber to doctor_verifications.
--             visiting_fee stays but is now managed via updateVisitingInfo()
--             (not part of the admin-review credentials flow).
-- DATE      : 2026-05-26
-- =============================================================================

ALTER TABLE public.doctor_verifications
  ADD COLUMN IF NOT EXISTS visiting_hours TEXT,
  ADD COLUMN IF NOT EXISTS chamber TEXT;
