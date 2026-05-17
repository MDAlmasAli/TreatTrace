-- ─────────────────────────────────────────────────────────────────────────────
-- v05_prescriptions.sql
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 0. updated_at helper ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ── 1. prescriptions ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.prescriptions (
  id                UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id           UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  doctor_name       TEXT,
  doctor_specialty  TEXT,
  doctor_hospital   TEXT,
  doctor_phone      TEXT,
  diagnosis         TEXT,
  prescription_date DATE        DEFAULT CURRENT_DATE NOT NULL,
  image_url         TEXT,
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at        TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_own_prescriptions" ON public.prescriptions;
CREATE POLICY "users_own_prescriptions" ON public.prescriptions
  FOR ALL TO authenticated
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_prescriptions_user_id ON public.prescriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_date    ON public.prescriptions(prescription_date DESC);

DROP TRIGGER IF EXISTS set_prescriptions_updated_at ON public.prescriptions;
CREATE TRIGGER set_prescriptions_updated_at
  BEFORE UPDATE ON public.prescriptions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 2. prescription_medicines ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.prescription_medicines (
  id               UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  prescription_id  UUID        REFERENCES public.prescriptions(id) ON DELETE CASCADE NOT NULL,
  medicine_name    TEXT        NOT NULL,
  dose             TEXT,
  morning          BOOLEAN     DEFAULT FALSE NOT NULL,
  afternoon        BOOLEAN     DEFAULT FALSE NOT NULL,
  evening          BOOLEAN     DEFAULT FALSE NOT NULL,
  night            BOOLEAN     DEFAULT FALSE NOT NULL,
  duration_days    INTEGER,
  instructions     TEXT,
  start_date       DATE        DEFAULT CURRENT_DATE,
  created_at       TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.prescription_medicines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_own_prescription_medicines" ON public.prescription_medicines;
CREATE POLICY "users_own_prescription_medicines" ON public.prescription_medicines
  FOR ALL TO authenticated
  USING (
    prescription_id IN (
      SELECT id FROM public.prescriptions WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    prescription_id IN (
      SELECT id FROM public.prescriptions WHERE user_id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS idx_prescription_medicines_pid
  ON public.prescription_medicines(prescription_id);

-- ── 3. Storage bucket for prescription images ─────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
  VALUES ('prescriptions', 'prescriptions', false)
  ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "user_own_prescription_images_all" ON storage.objects;
CREATE POLICY "user_own_prescription_images_all" ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'prescriptions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'prescriptions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
