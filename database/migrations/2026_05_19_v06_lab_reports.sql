-- ═══════════════════════════════════════════════════════════════════════════
--
--  MIGRATION : 2026_05_19_v06_lab_reports.sql
--  PURPOSE   : Add lab_reports table + storage bucket RLS for test report
--              file uploads.
--
--  HOW TO RUN
--  ──────────
--  Supabase Dashboard → SQL Editor → paste this file → Run
--
--  PREREQUISITES
--  ─────────────
--  • prescriptions table must exist (FK reference)
--  • Create the `lab_reports` storage bucket in the dashboard first:
--      Storage → New bucket → Name: "lab_reports" → Public: OFF → Save
--
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- TABLE: lab_reports
-- ─────────────────────────────────────────────────────────────────────────
-- Stores each user's lab / test report metadata and image references.
-- category is stored as free TEXT — users may supply any string.
-- prescription_id is a nullable FK; deleting a prescription sets it NULL.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.lab_reports (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  test_name       TEXT          NOT NULL,
  category        TEXT,
  test_date       DATE,
  doctor_name     TEXT,
  hospital        TEXT,
  image_urls      TEXT[]        NOT NULL DEFAULT '{}',
  notes           TEXT,
  prescription_id UUID          REFERENCES public.prescriptions(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);


-- ── Indexes ───────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_lab_reports_user_id
  ON public.lab_reports (user_id);

CREATE INDEX IF NOT EXISTS idx_lab_reports_test_date
  ON public.lab_reports (test_date DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_lab_reports_category
  ON public.lab_reports (category);


-- ── updated_at trigger ────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS set_lab_reports_updated_at
  ON public.lab_reports;

CREATE TRIGGER set_lab_reports_updated_at
  BEFORE UPDATE ON public.lab_reports
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();


-- ── Row Level Security ────────────────────────────────────────────────────

ALTER TABLE public.lab_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own lab_reports"   ON public.lab_reports;
DROP POLICY IF EXISTS "Users can insert own lab_reports" ON public.lab_reports;
DROP POLICY IF EXISTS "Users can update own lab_reports" ON public.lab_reports;
DROP POLICY IF EXISTS "Users can delete own lab_reports" ON public.lab_reports;

CREATE POLICY "Users can view own lab_reports"
  ON public.lab_reports FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own lab_reports"
  ON public.lab_reports FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own lab_reports"
  ON public.lab_reports FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own lab_reports"
  ON public.lab_reports FOR DELETE
  USING (auth.uid() = user_id);


-- ── Storage RLS for lab_reports bucket ───────────────────────────────────
-- Files are stored at "<uid>/<timestamp>.<ext>".
-- Create the `lab_reports` bucket in the Supabase dashboard before running.

DROP POLICY IF EXISTS "Lab report upload — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Lab report read  — own folder only"   ON storage.objects;
DROP POLICY IF EXISTS "Lab report update — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Lab report delete — own folder only"  ON storage.objects;

CREATE POLICY "Lab report upload — own folder only"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'lab_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Lab report read  — own folder only"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'lab_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Lab report update — own folder only"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'lab_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Lab report delete — own folder only"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'lab_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );


-- ═══════════════════════════════════════════════════════════════════════════
-- END OF MIGRATION
-- [2026-05-19] v0.6 — lab_reports table added
-- ═══════════════════════════════════════════════════════════════════════════
