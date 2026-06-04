-- ============================================================================
--  03_health_profiles.sql — Patient health profile (vitals, allergies, ICE)
-- ============================================================================
--  1:1 with the user (id = auth user id). RLS lives in 12_security.sql.
-- ============================================================================

create table if not exists public.health_profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  blood_group       text check (blood_group = any (array['A+','A-','B+','B-','AB+','AB-','O+','O-'])),
  age               int  check (age > 0 and age <= 120),
  height_cm         numeric check (height_cm > 0),
  weight_kg         numeric check (weight_kg > 0),
  allergies         text,
  ongoing_treatment text,
  emergency_name    text,
  emergency_phone   text,
  updated_at        timestamptz not null default now()
);
create index if not exists idx_health_profiles_blood_group on public.health_profiles (blood_group);

drop trigger if exists set_health_profiles_updated_at on public.health_profiles;
create trigger set_health_profiles_updated_at before update on public.health_profiles
  for each row execute function public.set_updated_at();
