-- ═══════════════════════════════════════════════════════════════════════════
--
--  MIGRATION : 2026_05_30_v17_rename_lab_reports_to_test_reports.sql
--  PURPOSE   : Rename table `lab_reports` → `test_reports`, update all
--              indexes, triggers, RLS policies, and storage bucket policies.
--
--  STORAGE NOTE
--  ────────────
--  Supabase storage bucket names cannot be renamed via SQL.
--  After running this migration, manually in the dashboard:
--    1. Storage → New bucket → Name: "test_reports", Public: OFF → Save
--    2. Copy all files from "lab_reports" bucket to "test_reports"
--    3. Delete the old "lab_reports" bucket when safe
--
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. Rename the table ────────────────────────────────────────────────────

ALTER TABLE public.lab_reports RENAME TO test_reports;


-- ── 2. Rename indexes ──────────────────────────────────────────────────────

ALTER INDEX IF EXISTS idx_lab_reports_user_id   RENAME TO idx_test_reports_user_id;
ALTER INDEX IF EXISTS idx_lab_reports_test_date RENAME TO idx_test_reports_test_date;
ALTER INDEX IF EXISTS idx_lab_reports_category  RENAME TO idx_test_reports_category;


-- ── 3. Rename the updated_at trigger ──────────────────────────────────────

DROP TRIGGER IF EXISTS set_lab_reports_updated_at ON public.test_reports;

CREATE TRIGGER set_test_reports_updated_at
  BEFORE UPDATE ON public.test_reports
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();


-- ── 4. Update table RLS policies ──────────────────────────────────────────

DROP POLICY IF EXISTS "Users can view own lab_reports"   ON public.test_reports;
DROP POLICY IF EXISTS "Users can insert own lab_reports" ON public.test_reports;
DROP POLICY IF EXISTS "Users can update own lab_reports" ON public.test_reports;
DROP POLICY IF EXISTS "Users can delete own lab_reports" ON public.test_reports;

CREATE POLICY "Users can view own test_reports"
  ON public.test_reports FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own test_reports"
  ON public.test_reports FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own test_reports"
  ON public.test_reports FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own test_reports"
  ON public.test_reports FOR DELETE USING (auth.uid() = user_id);


-- ── 5. Update storage RLS policies for the new bucket ─────────────────────
-- (Create the 'test_reports' bucket in the dashboard first.)

DROP POLICY IF EXISTS "Test report upload — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Test report read  — own folder only"   ON storage.objects;
DROP POLICY IF EXISTS "Test report update — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Test report delete — own folder only"  ON storage.objects;

CREATE POLICY "Test report upload — own folder only"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'test_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Test report read  — own folder only"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'test_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Test report update — own folder only"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'test_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Test report delete — own folder only"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'test_reports'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );


-- ═══════════════════════════════════════════════════════════════════════════
-- END OF MIGRATION
-- [2026-05-30] v0.17 — renamed lab_reports → test_reports throughout
-- ═══════════════════════════════════════════════════════════════════════════
