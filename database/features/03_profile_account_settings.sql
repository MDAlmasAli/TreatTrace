-- =============================================================================
-- 03_profile_account_settings.sql
--
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query).
--
-- What this migration does:
--   1. Adds a `phone` column to the `profiles` table (idempotent).
--   2. Creates an index on `profiles.phone` for fast lookups.
--   3. Sets up Row-Level Security (RLS) policies on the Supabase Storage
--      `objects` table so users can upload/read their own avatar images.
--
-- Prerequisites:
--   • Run 01_auth_profiles.sql first (profiles table must exist).
--   • Create the `avatars` storage bucket in the Supabase dashboard BEFORE
--     running this script:
--       Storage → New bucket → Name: "avatars" → Public: ON → Save
--   • RLS must be enabled on the storage.objects table (enabled by default
--     in Supabase projects).
--
-- This script is fully idempotent — safe to run multiple times.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Add `phone` column to profiles (no-op if it already exists)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone TEXT;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Index on phone for fast lookups / uniqueness checks
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_phone
  ON public.profiles (phone);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Storage RLS policies for the `avatars` bucket
--
--    Supabase Storage stores files in the `storage.objects` table.
--    We use `storage.foldername(name)[1]` which returns the first path
--    segment of the object name.  When the Flutter app uploads a file to
--    "<uid>/avatar.jpg", foldername(name)[1] = '<uid>'.
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop existing policies first so this script stays idempotent.
DROP POLICY IF EXISTS "Avatar upload — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Avatar read  — own folder only"   ON storage.objects;
DROP POLICY IF EXISTS "Avatar update — own folder only"  ON storage.objects;
DROP POLICY IF EXISTS "Avatar delete — own folder only"  ON storage.objects;

-- INSERT: users can upload to their own UID-named folder.
CREATE POLICY "Avatar upload — own folder only"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND storage.foldername(name)[1] = auth.uid()::text
  );

-- SELECT: users can read objects in their own folder.
CREATE POLICY "Avatar read  — own folder only"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND storage.foldername(name)[1] = auth.uid()::text
  );

-- UPDATE: users can overwrite (upsert) their own avatar.
CREATE POLICY "Avatar update — own folder only"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND storage.foldername(name)[1] = auth.uid()::text
  );

-- DELETE: users can delete their own avatar.
CREATE POLICY "Avatar delete — own folder only"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND storage.foldername(name)[1] = auth.uid()::text
  );
