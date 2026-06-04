-- ============================================================================
--  06_prescriptions.sql — Prescriptions, their medicines, and edit logs
-- ============================================================================
--  A prescription belongs to a patient (user_id). When a registered doctor
--  writes it, written_by_doctor_id is set and the patient is notified.
--  RLS lives in 12_security.sql.
-- ============================================================================

-- ── prescriptions ────────────────────────────────────────────────────────────
create table if not exists public.prescriptions (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  doctor_name          text,
  doctor_specialty     text,
  doctor_hospital      text,
  doctor_phone         text,
  diagnosis            text,
  prescription_date    date not null default current_date,
  notes                text,
  image_urls           text[] default array[]::text[],
  written_by_doctor_id uuid references public.profiles(id),   -- set when a registered doctor wrote it
  linked_doctor_id     uuid references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index if not exists idx_prescriptions_date    on public.prescriptions (prescription_date desc);
create index if not exists idx_prescriptions_user_id on public.prescriptions (user_id);

-- ── prescription_medicines ───────────────────────────────────────────────────
create table if not exists public.prescription_medicines (
  id              uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  medicine_name   text not null,
  dose            text,
  morning         boolean not null default false,
  afternoon       boolean not null default false,
  evening         boolean not null default false,
  night           boolean not null default false,
  before_meal     boolean not null default false,
  after_meal      boolean not null default false,
  duration_days   int,
  instructions    text,
  start_date      date default current_date,
  created_at      timestamptz not null default now()
);
create index if not exists idx_prescription_medicines_pid on public.prescription_medicines (prescription_id);

-- ── prescription_edit_logs ───────────────────────────────────────────────────
-- One created/edited entry per prescription per day (used to rate-limit edits).
create table if not exists public.prescription_edit_logs (
  id              uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  doctor_id       uuid not null references auth.users(id) on delete cascade,
  action_date     date not null default current_date,
  action          text not null check (action = any (array['created','edited'])),
  unique (prescription_id, action_date)
);

-- ── Functions ────────────────────────────────────────────────────────────────
-- New prescription written by a doctor → notify the patient.
create or replace function public.notify_new_prescription()
 returns trigger language plpgsql security definer set search_path to 'public','auth' as $function$
declare
  doc_name text;
begin
  if new.written_by_doctor_id is null then return new; end if;
  if auth.uid() is distinct from new.written_by_doctor_id then return new; end if;

  doc_name := coalesce(nullif(trim(new.doctor_name), ''), 'Your doctor');

  insert into public.notifications (user_id, type, title, body, data)
  values (
    new.user_id, 'prescription_added', 'New prescription',
    'Dr. ' || doc_name || ' added a new prescription'
      || coalesce(' for ' || nullif(trim(new.diagnosis), ''), '') || '.',
    jsonb_build_object('prescription_id', new.id)
  );
  return new;
end;
$function$;

-- ── Triggers ─────────────────────────────────────────────────────────────────
drop trigger if exists set_prescriptions_updated_at on public.prescriptions;
create trigger set_prescriptions_updated_at before update on public.prescriptions
  for each row execute function public.set_updated_at();

drop trigger if exists trg_notify_new_prescription on public.prescriptions;
create trigger trg_notify_new_prescription after insert on public.prescriptions
  for each row execute function public.notify_new_prescription();
