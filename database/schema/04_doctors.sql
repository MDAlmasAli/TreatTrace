-- ============================================================================
--  04_doctors.sql — A patient's personal doctor book
-- ============================================================================
--  Free-text doctor entries a patient keeps for themselves (NOT registered
--  accounts — those are doctor_verifications). RLS lives in 12_security.sql.
-- ============================================================================

create table if not exists public.doctors (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  specialty       text,
  hospital        text,
  chamber_address text,
  phone           text,
  fee             text,
  notes           text,
  is_favorite     boolean not null default false,
  image_url       text,
  source_id       uuid,                 -- optional: registered doctor this was copied from
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists idx_doctors_favorite  on public.doctors (user_id, is_favorite);
create index if not exists idx_doctors_specialty on public.doctors (specialty);
create index if not exists idx_doctors_user_id   on public.doctors (user_id);

drop trigger if exists set_doctors_updated_at on public.doctors;
create trigger set_doctors_updated_at before update on public.doctors
  for each row execute function public.set_updated_at();
