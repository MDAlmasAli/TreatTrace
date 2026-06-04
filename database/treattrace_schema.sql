-- ============================================================================
--  TreatTrace — Combined Database Schema (single-file build)
-- ----------------------------------------------------------------------------
--  AUTO-ASSEMBLED from the organized files in database/schema/ (in numeric
--  order). This is the convenience "run everything at once" file — paste it
--  into the Supabase SQL editor on a fresh project.
--
--  To understand WHAT lives WHERE, read database/schema/ instead — each file
--  there owns one feature (table + its functions + triggers); RLS is grouped
--  in 12_security.sql. Do not edit this combined file by hand; edit the
--  schema/ files and re-assemble.
-- ============================================================================


-- ============================================================================
--  00_extensions.sql — Required PostgreSQL extensions
-- ============================================================================
--  Run first. Everything else depends on gen_random_uuid().
-- ============================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid()


-- ============================================================================
--  01_functions_shared.sql — Cross-cutting helper functions
-- ============================================================================
--  Defined early because many tables' BEFORE UPDATE triggers reference it.
--  (Table-specific functions live in each feature file; security helpers that
--   need every table to exist first live in 12_security.sql.)
-- ============================================================================

-- Stamp updated_at on every row update.
create or replace function public.set_updated_at()
 returns trigger language plpgsql as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;


-- ============================================================================
--  02_profiles.sql — User profiles (one row per auth user)
-- ============================================================================
--  Holds display info, role, and the unique @username. A row is created
--  automatically when someone signs up (handle_new_user trigger below).
--  RLS policies for this table live in 12_security.sql.
-- ============================================================================

-- ── Table ────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  email       text,
  avatar_url  text,
  phone       text,
  role        text check (role = any (array['patient','doctor','admin'])),
  username    text unique
              constraint username_format
              check (username is null or username ~ '^[a-z0-9_]{3,20}$'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_profiles_email     on public.profiles (email);
create index if not exists idx_profiles_full_name on public.profiles (full_name);
create index if not exists idx_profiles_phone     on public.profiles (phone);
create index if not exists idx_profiles_username  on public.profiles (username);

-- ── Functions ────────────────────────────────────────────────────────────────

-- Create a profile row when a new auth user signs up.
create or replace function public.handle_new_user()
 returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  insert into public.profiles (id, full_name, email, phone, username)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'username'
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;

-- Username availability (case-insensitive, ignores the caller's own row).
create or replace function public.check_username_available(uname text)
 returns boolean language plpgsql security definer set search_path to 'public' as $function$
begin
  return not exists (
    select 1 from public.profiles
    where username = lower(trim(uname)) and id != auth.uid()
  );
end;
$function$;

-- Patient lookup for the doctor portal (by phone, id, or username).
create or replace function public.search_patient_by_query(query_text text)
 returns table(id uuid, full_name text, phone text, avatar_url text, username text)
 language plpgsql security definer set search_path to 'public' as $function$
begin
  return query
  select p.id, p.full_name::text, p.phone::text, p.avatar_url::text, p.username::text
  from   public.profiles p
  where  p.role = 'patient'
    and  (p.phone = query_text or p.id::text = query_text or p.username = lower(trim(query_text)))
  limit  5;
end;
$function$;

-- ── Triggers ─────────────────────────────────────────────────────────────────
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();


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


-- ============================================================================
--  05_doctor_verifications.sql — Registered-doctor profile & verification
-- ============================================================================
--  PK = the doctor's auth user id. Holds verification status, the public
--  profile, the structured visiting schedule/capacity that drives appointment
--  ticketing, and the aggregate review rating (maintained by the trigger in
--  10_doctor_reviews.sql). "pending_*" columns stage edits awaiting admin
--  approval (applied by approve_doctor_edit). RLS lives in 12_security.sql.
-- ============================================================================

create table if not exists public.doctor_verifications (
  id                    uuid primary key references auth.users(id) on delete cascade,
  bmdc_number           text not null,
  specialty             text not null,
  hospital              text not null,
  nid_passport          text not null,
  additional_info       text,
  status                text not null default 'pending'
                        check (status = any (array['pending','approved','rejected'])),
  rejection_reason      text,
  submitted_at          timestamptz not null default now(),
  reviewed_at           timestamptz,
  reviewed_by           uuid references auth.users(id),
  -- staged edits (await admin approval)
  pending_bmdc          text,
  pending_specialty     text,
  pending_hospital      text,
  pending_nid_passport  text,
  pending_additional    text,
  pending_degree        text,
  pending_about         text,
  pending_visiting_fee  int,
  edit_status           text check (edit_status = any (array['pending','approved','rejected'])),
  edit_rejection_reason text,
  edit_submitted_at     timestamptz,
  -- public profile
  degree                text,
  about                 text,
  visiting_fee          int,
  visiting_hours        text,         -- auto-derived human-readable string
  chamber               text,
  -- structured visiting schedule + capacity (drives ticketing in 08_appointments)
  visiting_days         smallint[],   -- ISO dow: 1=Mon … 7=Sun
  visiting_start_time   time,
  visiting_end_time     time,
  daily_patient_limit   int,
  minutes_per_patient   int,
  -- aggregate review rating (maintained by recalc_doctor_rating trigger)
  rating_avg            numeric not null default 0,
  rating_count          int     not null default 0,
  constraint fk_doctor_verifications_profile
    foreign key (id) references public.profiles(id) on delete cascade
);

-- Admin: apply a doctor's staged ("pending_*") profile edit.
create or replace function public.approve_doctor_edit(p_doctor_id uuid)
 returns void language plpgsql security definer as $function$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized';
  end if;

  update public.doctor_verifications set
    bmdc_number          = coalesce(pending_bmdc,          bmdc_number),
    specialty            = coalesce(pending_specialty,      specialty),
    hospital             = coalesce(pending_hospital,       hospital),
    nid_passport         = coalesce(pending_nid_passport,   nid_passport),
    degree               = coalesce(pending_degree,         degree),
    about                = coalesce(pending_about,          about),
    visiting_fee         = coalesce(pending_visiting_fee,   visiting_fee),
    additional_info      = coalesce(pending_additional,     additional_info),
    pending_bmdc         = null,
    pending_specialty    = null,
    pending_hospital     = null,
    pending_nid_passport = null,
    pending_degree       = null,
    pending_about        = null,
    pending_visiting_fee = null,
    pending_additional   = null,
    edit_status          = null,
    edit_rejection_reason = null,
    reviewed_at          = now(),
    reviewed_by          = auth.uid()
  where id = p_doctor_id and edit_status = 'pending';
end;
$function$;


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


-- ============================================================================
--  07_test_reports.sql — Lab / diagnostic test reports
-- ============================================================================
--  Belongs to a patient (user_id); can be ordered by a doctor
--  (ordered_by_doctor_id → patient is notified) and linked to prescriptions.
--  (Formerly "lab_reports"; in the live DB the constraint names still carry the
--   legacy "lab_reports_*" prefix — harmless.) RLS lives in 12_security.sql.
-- ============================================================================

create table if not exists public.test_reports (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  test_name            text not null,
  category             text,
  test_date            date,
  doctor_name          text,
  hospital             text,
  image_urls           text[] not null default '{}'::text[],
  notes                text,
  prescription_id      uuid references public.prescriptions(id) on delete set null,
  prescription_ids     text[] default '{}'::text[],   -- multi-link to prescriptions
  ordered_by_doctor_id uuid references auth.users(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index if not exists idx_test_reports_category  on public.test_reports (category);
create index if not exists idx_test_reports_test_date on public.test_reports (test_date desc nulls last);
create index if not exists idx_test_reports_user_id   on public.test_reports (user_id);

-- New test ordered by a doctor → notify the patient.
create or replace function public.notify_new_test_report()
 returns trigger language plpgsql security definer set search_path to 'public','auth' as $function$
declare
  doc_name text;
begin
  if new.ordered_by_doctor_id is null then return new; end if;
  if auth.uid() is distinct from new.ordered_by_doctor_id then return new; end if;

  doc_name := coalesce(nullif(trim(new.doctor_name), ''), 'Your doctor');

  insert into public.notifications (user_id, type, title, body, data)
  values (
    new.user_id, 'test_report_added', 'New test ordered',
    'Dr. ' || doc_name || ' ordered a new test: '
      || coalesce(nullif(trim(new.test_name), ''), 'Test') || '.',
    jsonb_build_object('test_report_id', new.id)
  );
  return new;
end;
$function$;

drop trigger if exists set_test_reports_updated_at on public.test_reports;
create trigger set_test_reports_updated_at before update on public.test_reports
  for each row execute function public.set_updated_at();

drop trigger if exists trg_notify_new_test_report on public.test_reports;
create trigger trg_notify_new_test_report after insert on public.test_reports
  for each row execute function public.notify_new_test_report();


-- ============================================================================
--  08_appointments.sql — Appointments, ticketing & the live queue engine
-- ============================================================================
--  This is the heart of the app. An appointment belongs to a patient (user_id)
--  and optionally a registered doctor (doctor_user_id) or a personal-book
--  doctor (doctor_id). Server-side rules enforced here:
--    • one active (scheduled) appointment per doctor      (prevent_duplicate…)
--    • visiting-day + daily-capacity check + ticket no.    (assign_ticket…)
--    • re-check + re-number when a reschedule lands         (reschedule…)
--    • live queue position for the patient                 (get_queue_position)
--    • bookability probe + next available date             (check_appointment_availability)
--    • auto-expire passed appointments to no_show          (expire_past_appointments)
--    • notifications on booking / reschedule / cancel / no-show
--  Both write triggers take a per-doctor+day advisory lock so concurrent
--  bookings serialise; uq_appt_scheduled_ticket is the hard duplicate guard.
--  RLS lives in 12_security.sql.
-- ============================================================================

-- ── Table ────────────────────────────────────────────────────────────────────
create table if not exists public.appointments (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,   -- patient
  doctor_id            uuid references public.doctors(id) on delete set null,       -- personal-book doctor
  doctor_user_id       uuid references public.profiles(id),                         -- registered doctor
  doctor_name_snapshot text not null,
  appointment_date     date not null,
  appointment_time     text,
  visit_reason         text,
  status               text not null default 'scheduled'
                       check (status = any (array['scheduled','completed','cancelled','no_show'])),
  notes                text,
  prescription_id      uuid references public.prescriptions(id) on delete set null,
  prescription_ids     text[] default '{}'::text[],
  test_report_ids      text[] default '{}'::text[],
  proposed_date        date,            -- doctor's reschedule proposal (patient confirms)
  ticket_no            int,             -- per doctor+day serial (assigned by trigger)
  review_prompted      boolean not null default false,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index if not exists idx_appointments_date    on public.appointments (appointment_date desc);
create index if not exists idx_appointments_doctor  on public.appointments (doctor_id);
create index if not exists idx_appointments_status  on public.appointments (user_id, status);
create index if not exists idx_appointments_user_id on public.appointments (user_id);
-- Hard guard against duplicate serials for a doctor+day among scheduled rows.
create unique index if not exists uq_appt_scheduled_ticket
  on public.appointments (doctor_user_id, appointment_date, ticket_no)
  where (status = 'scheduled' and doctor_user_id is not null and ticket_no is not null);

-- ── Functions: ticketing / queue ─────────────────────────────────────────────

-- BEFORE INSERT: validate visiting day + capacity, assign the per-day ticket.
create or replace function public.assign_ticket_and_check_slot()
 returns trigger language plpgsql security definer set search_path to 'public','auth' as $function$
declare
  v_days  smallint[];
  v_limit int;
  v_count int;
  v_max   int;
begin
  if new.doctor_user_id is null or new.status is distinct from 'scheduled' then
    return new;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(new.doctor_user_id::text || '|' || new.appointment_date::text, 0));

  select visiting_days, daily_patient_limit into v_days, v_limit
  from public.doctor_verifications where id = new.doctor_user_id;

  if v_days is not null and array_length(v_days, 1) is not null
     and not (extract(isodow from new.appointment_date)::int = any(v_days)) then
    raise exception 'INVALID_VISITING_DAY' using errcode = 'P0001';
  end if;

  select count(*) into v_count
  from public.appointments
  where doctor_user_id = new.doctor_user_id
    and appointment_date = new.appointment_date
    and status = 'scheduled';

  if v_limit is not null and v_limit > 0 and v_count >= v_limit then
    raise exception 'NO_SLOT_AVAILABLE' using errcode = 'P0001';
  end if;

  select coalesce(max(ticket_no), 0) into v_max
  from public.appointments
  where doctor_user_id = new.doctor_user_id and appointment_date = new.appointment_date;
  new.ticket_no := v_max + 1;

  return new;
end;
$function$;

-- BEFORE UPDATE: when the date changes, re-check the new day and re-number.
create or replace function public.reschedule_check_and_renumber()
 returns trigger language plpgsql security definer set search_path to 'public','auth' as $function$
declare
  v_days  smallint[];
  v_limit int;
  v_count int;
  v_max   int;
begin
  if new.appointment_date is distinct from old.appointment_date
     and new.status = 'scheduled'
     and new.doctor_user_id is not null then

    perform pg_advisory_xact_lock(
      hashtextextended(new.doctor_user_id::text || '|' || new.appointment_date::text, 0));

    select visiting_days, daily_patient_limit into v_days, v_limit
    from public.doctor_verifications where id = new.doctor_user_id;

    if v_days is not null and array_length(v_days, 1) is not null
       and not (extract(isodow from new.appointment_date)::int = any(v_days)) then
      raise exception 'INVALID_VISITING_DAY' using errcode = 'P0001';
    end if;

    select count(*) into v_count
    from public.appointments
    where doctor_user_id = new.doctor_user_id
      and appointment_date = new.appointment_date
      and status = 'scheduled'
      and id <> new.id;

    if v_limit is not null and v_limit > 0 and v_count >= v_limit then
      raise exception 'NO_SLOT_AVAILABLE' using errcode = 'P0001';
    end if;

    select coalesce(max(ticket_no), 0) into v_max
    from public.appointments
    where doctor_user_id = new.doctor_user_id
      and appointment_date = new.appointment_date
      and id <> new.id;
    new.ticket_no := v_max + 1;
  end if;

  return new;
end;
$function$;

-- Block a second active (scheduled) appointment with the same doctor.
create or replace function public.prevent_duplicate_active_appointment()
 returns trigger language plpgsql as $function$
begin
  if new.status is distinct from 'scheduled' then
    return new;
  end if;

  if exists (
    select 1 from public.appointments a
    where a.user_id = new.user_id
      and a.status  = 'scheduled'
      and a.id     <> new.id
      and (
            (new.doctor_user_id is not null and a.doctor_user_id = new.doctor_user_id)
         or (new.doctor_user_id is null and new.doctor_id is not null and a.doctor_id = new.doctor_id)
         or (new.doctor_user_id is null and new.doctor_id is null
              and lower(trim(coalesce(a.doctor_name_snapshot, ''))) =
                  lower(trim(coalesce(new.doctor_name_snapshot, ''))))
          )
  ) then
    raise exception 'DUPLICATE_ACTIVE_APPOINTMENT' using errcode = 'P0001';
  end if;

  return new;
end;
$function$;

-- Live queue position for a scheduled appointment (still-scheduled ahead + 1).
create or replace function public.get_queue_position(p_appt_id uuid)
 returns integer language plpgsql security definer set search_path to 'public' as $function$
declare
  v_doc uuid; v_date date; v_ticket int; v_status text; v_pos int;
begin
  select doctor_user_id, appointment_date, ticket_no, status
    into v_doc, v_date, v_ticket, v_status
  from public.appointments where id = p_appt_id;

  if v_doc is null or v_ticket is null or v_status <> 'scheduled' then
    return null;
  end if;

  select count(*) + 1 into v_pos
  from public.appointments
  where doctor_user_id = v_doc and appointment_date = v_date
    and status = 'scheduled' and ticket_no < v_ticket;

  return v_pos;
end;
$function$;

-- Is the requested date bookable? Also returns the next available date.
create or replace function public.check_appointment_availability(p_doctor uuid, p_date date)
 returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_days smallint[]; v_limit int; v_count int;
  v_requested_ok bool := true; v_reason text := 'ok';
  v_next date := null; v_probe date; v_i int := 0; v_isday bool;
begin
  if p_doctor is null then
    return jsonb_build_object('requested_ok', true, 'reason', 'ok', 'next_available', p_date);
  end if;

  select visiting_days, daily_patient_limit into v_days, v_limit
  from public.doctor_verifications where id = p_doctor;

  if v_days is not null and array_length(v_days, 1) is not null
     and not (extract(isodow from p_date)::int = any(v_days)) then
    v_requested_ok := false; v_reason := 'not_visiting_day';
  else
    select count(*) into v_count from public.appointments
     where doctor_user_id = p_doctor and appointment_date = p_date and status = 'scheduled';
    if v_limit is not null and v_limit > 0 and v_count >= v_limit then
      v_requested_ok := false; v_reason := 'full';
    end if;
  end if;

  v_probe := p_date;
  while v_i < 60 loop
    v_isday := (v_days is null or array_length(v_days, 1) is null
                or extract(isodow from v_probe)::int = any(v_days));
    if v_isday then
      select count(*) into v_count from public.appointments
       where doctor_user_id = p_doctor and appointment_date = v_probe and status = 'scheduled';
      if not (v_limit is not null and v_limit > 0 and v_count >= v_limit) then
        v_next := v_probe; exit;
      end if;
    end if;
    v_probe := v_probe + 1;
    v_i := v_i + 1;
  end loop;

  return jsonb_build_object('requested_ok', v_requested_ok, 'reason', v_reason,
                            'limit', v_limit, 'next_available', v_next);
end;
$function$;

-- Mark passed scheduled appointments as no_show (app calls on load; pg_cron daily).
create or replace function public.expire_past_appointments()
 returns integer language plpgsql security definer set search_path to 'public' as $function$
declare
  affected integer;
begin
  update public.appointments
     set status = 'no_show'
   where status = 'scheduled' and appointment_date < current_date;
  get diagnostics affected = row_count;
  return affected;
end;
$function$;

-- ── Functions: notifications ─────────────────────────────────────────────────

-- New booking with a registered doctor → notify the doctor.
create or replace function public.notify_new_appointment()
 returns trigger language plpgsql security definer set search_path to 'public','auth' as $function$
declare
  patient_name text;
begin
  if new.doctor_user_id is null then return new; end if;
  if auth.uid() is distinct from new.user_id then return new; end if;

  select nullif(trim(full_name), '') into patient_name
  from public.profiles where id = new.user_id;
  patient_name := coalesce(patient_name, 'A patient');

  insert into public.notifications (user_id, type, title, body, data)
  values (
    new.doctor_user_id, 'appointment_booked', 'New appointment',
    patient_name || ' booked an appointment for ' || to_char(new.appointment_date, 'DD Mon YYYY') || '.',
    jsonb_build_object('appointment_id', new.id)
  );
  return new;
end;
$function$;

-- Reschedule proposal / cancel / no-show notifications (doctor & patient sides).
create or replace function public.notify_appointment_change()
 returns trigger language plpgsql security definer set search_path to 'public','auth' as $function$
declare
  doc_name text;
  pat_name text;
begin
  doc_name := coalesce(nullif(trim(new.doctor_name_snapshot), ''), 'Your doctor');

  -- Marked as missed (manual no-show, or auto when the day passed).
  if new.status = 'no_show' and old.status is distinct from 'no_show' then
    insert into public.notifications (user_id, type, title, body, data)
    values (
      new.user_id, 'appointment_missed', 'Appointment missed',
      'You missed your appointment with Dr. ' || doc_name || ' on '
        || to_char(new.appointment_date, 'DD Mon YYYY') || '.',
      jsonb_build_object('appointment_id', new.id)
    );
    return new;
  end if;

  -- Auto-expiry to cancelled (legacy path): stay silent.
  if new.status = 'cancelled' and old.status is distinct from 'cancelled'
     and new.appointment_date < current_date then
    return new;
  end if;

  -- DOCTOR actions
  if auth.uid() = new.doctor_user_id then
    if new.proposed_date is not null and new.proposed_date is distinct from old.proposed_date then
      insert into public.notifications (user_id, type, title, body, data)
      values (
        new.user_id, 'appointment_reschedule_proposed', 'Reschedule requested',
        'Dr. ' || doc_name || ' requested to move your appointment from '
          || to_char(old.appointment_date, 'DD Mon YYYY') || ' to '
          || to_char(new.proposed_date, 'DD Mon YYYY') || '. Open to accept or cancel.',
        jsonb_build_object('appointment_id', new.id)
      );
      return new;
    end if;

    if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
      insert into public.notifications (user_id, type, title, body, data)
      values (
        new.user_id, 'appointment_cancelled', 'Appointment cancelled',
        'Dr. ' || doc_name || ' cancelled your appointment scheduled for '
          || to_char(old.appointment_date, 'DD Mon YYYY') || '.',
        jsonb_build_object('appointment_id', new.id)
      );
      return new;
    end if;

    return new;
  end if;

  -- PATIENT actions
  if auth.uid() = new.user_id then
    select nullif(trim(full_name), '') into pat_name
    from public.profiles where id = new.user_id;
    pat_name := coalesce(pat_name, 'The patient');

    if old.proposed_date is not null and new.proposed_date is null
       and new.appointment_date is distinct from old.appointment_date then
      if new.doctor_user_id is not null then
        insert into public.notifications (user_id, type, title, body, data)
        values (
          new.doctor_user_id, 'appointment_reschedule_accepted', 'Reschedule accepted',
          pat_name || ' accepted the new date ' || to_char(new.appointment_date, 'DD Mon YYYY') || '.',
          jsonb_build_object('appointment_id', new.id)
        );
      end if;
      return new;
    end if;

    if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
      if new.doctor_user_id is not null then
        insert into public.notifications (user_id, type, title, body, data)
        values (
          new.doctor_user_id, 'appointment_cancelled', 'Appointment cancelled',
          pat_name || ' cancelled the appointment scheduled for '
            || to_char(old.appointment_date, 'DD Mon YYYY') || '.',
          jsonb_build_object('appointment_id', new.id)
        );
      end if;
      return new;
    end if;

    return new;
  end if;

  return new;
end;
$function$;

-- ── Triggers ─────────────────────────────────────────────────────────────────
drop trigger if exists set_appointments_updated_at on public.appointments;
create trigger set_appointments_updated_at before update on public.appointments
  for each row execute function public.set_updated_at();

drop trigger if exists trg_prevent_duplicate_active_appointment on public.appointments;
create trigger trg_prevent_duplicate_active_appointment before insert on public.appointments
  for each row execute function public.prevent_duplicate_active_appointment();

drop trigger if exists trg_assign_ticket_and_check_slot on public.appointments;
create trigger trg_assign_ticket_and_check_slot before insert on public.appointments
  for each row execute function public.assign_ticket_and_check_slot();

drop trigger if exists trg_reschedule_check_and_renumber on public.appointments;
create trigger trg_reschedule_check_and_renumber before update on public.appointments
  for each row execute function public.reschedule_check_and_renumber();

drop trigger if exists trg_notify_new_appointment on public.appointments;
create trigger trg_notify_new_appointment after insert on public.appointments
  for each row execute function public.notify_new_appointment();

drop trigger if exists trg_notify_appointment_change on public.appointments;
create trigger trg_notify_appointment_change after update on public.appointments
  for each row execute function public.notify_appointment_change();


-- ============================================================================
--  09_doctor_patient_links.sql — Doctor ↔ patient connections
-- ============================================================================
--  A link is auto-accepted when a registered doctor writes a patient a
--  prescription (via auto_link_appointment_patient). The notify trigger sends
--  request/accept notifications. RLS lives in 12_security.sql.
--  (auto_link_appointment_patient calls doctor_has_appointment_with, which is
--   defined in 12_security.sql — fine, as it's only invoked at runtime.)
-- ============================================================================

create table if not exists public.doctor_patient_links (
  id           uuid primary key default gen_random_uuid(),
  doctor_id    uuid not null references public.profiles(id) on delete cascade,
  patient_id   uuid not null references public.profiles(id) on delete cascade,
  status       text not null default 'pending'
               check (status = any (array['pending','accepted','rejected','revoked'])),
  requested_at timestamptz not null default now(),
  accepted_at  timestamptz,
  unique (doctor_id, patient_id)
);

-- Auto-link a doctor to a patient they have an appointment with (idempotent).
create or replace function public.auto_link_appointment_patient(p_patient_id uuid)
 returns void language plpgsql security definer set search_path to 'public' as $function$
declare
  v_doctor_id uuid := auth.uid();
begin
  if not doctor_has_appointment_with(p_patient_id) then
    raise exception 'auto_link_appointment_patient: no appointment found';
  end if;

  insert into public.doctor_patient_links
    (doctor_id, patient_id, status, requested_at, accepted_at)
  values
    (v_doctor_id, p_patient_id, 'accepted', now(), now())
  on conflict (doctor_id, patient_id)
  do update set status = 'accepted', accepted_at = now()
  where doctor_patient_links.status <> 'accepted';
end;
$function$;

-- Link request / accept notifications.
create or replace function public.notify_link_change()
 returns trigger language plpgsql security definer set search_path to 'public','auth' as $function$
declare
  doc_name     text;
  patient_name text;
begin
  if (TG_OP = 'INSERT' and new.status = 'pending')
     or (TG_OP = 'UPDATE' and new.status = 'pending' and old.status is distinct from 'pending') then
    select nullif(trim(full_name), '') into doc_name from public.profiles where id = new.doctor_id;
    doc_name := coalesce(doc_name, 'A doctor');

    insert into public.notifications (user_id, type, title, body, data)
    values (
      new.patient_id, 'link_request', 'Connection request',
      'Dr. ' || doc_name || ' wants to connect with you.',
      jsonb_build_object('link_id', new.id)
    );
    return new;
  end if;

  if TG_OP = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' then
    select nullif(trim(full_name), '') into patient_name from public.profiles where id = new.patient_id;
    patient_name := coalesce(patient_name, 'A patient');

    insert into public.notifications (user_id, type, title, body, data)
    values (
      new.doctor_id, 'link_accepted', 'Connection accepted',
      patient_name || ' accepted your connection request.',
      jsonb_build_object('link_id', new.id)
    );
    return new;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_notify_link_change on public.doctor_patient_links;
create trigger trg_notify_link_change after insert or update on public.doctor_patient_links
  for each row execute function public.notify_link_change();


-- ============================================================================
--  10_doctor_reviews.sql — Anonymous doctor reviews
-- ============================================================================
--  A patient may review a doctor only after a completed appointment (enforced
--  by check_review_eligibility). Reviews are anonymous: base-table RLS lets a
--  patient see only their own row, while the public list is served by the
--  get_doctor_reviews RPC (never returns patient_id). recalc_doctor_rating
--  keeps doctor_verifications.rating_avg / rating_count in sync.
--  RLS lives in 12_security.sql.
-- ============================================================================

create table if not exists public.doctor_reviews (
  id             uuid primary key default gen_random_uuid(),
  doctor_user_id uuid not null references public.profiles(id) on delete cascade,
  patient_id     uuid not null references public.profiles(id) on delete cascade,
  rating         smallint not null check (rating >= 1 and rating <= 5),
  comment        text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (doctor_user_id, patient_id)
);
create index if not exists idx_doctor_reviews_doctor on public.doctor_reviews (doctor_user_id, created_at desc);

-- True if the caller may review the doctor (has a completed appointment).
create or replace function public.can_review_doctor(p_doctor uuid)
 returns boolean language sql security definer set search_path to 'public' as $function$
  select exists (
    select 1 from public.appointments
    where doctor_user_id = p_doctor and user_id = auth.uid() and status = 'completed'
  );
$function$;

-- BEFORE INSERT: enforce the completed-appointment rule.
create or replace function public.check_review_eligibility()
 returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  if not exists (
    select 1 from public.appointments
    where doctor_user_id = new.doctor_user_id
      and user_id = new.patient_id
      and status = 'completed'
  ) then
    raise exception 'REVIEW_NOT_ALLOWED' using errcode = 'P0001';
  end if;
  return new;
end;
$function$;

-- Anonymous public review list (never returns patient_id).
create or replace function public.get_doctor_reviews(p_doctor uuid)
 returns table(rating smallint, comment text, created_at timestamptz)
 language sql security definer set search_path to 'public' as $function$
  select rating, comment, created_at
  from public.doctor_reviews
  where doctor_user_id = p_doctor
  order by created_at desc;
$function$;

-- Recompute a doctor's aggregate rating after any review change.
create or replace function public.recalc_doctor_rating()
 returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare
  v_doc uuid;
begin
  v_doc := coalesce(new.doctor_user_id, old.doctor_user_id);
  update public.doctor_verifications dv
     set rating_count = sub.cnt, rating_avg = sub.avg
  from (
    select count(*)::int as cnt,
           coalesce(round(avg(rating)::numeric, 1), 0) as avg
    from public.doctor_reviews where doctor_user_id = v_doc
  ) sub
  where dv.id = v_doc;
  return null;
end;
$function$;

drop trigger if exists set_doctor_reviews_updated_at on public.doctor_reviews;
create trigger set_doctor_reviews_updated_at before update on public.doctor_reviews
  for each row execute function public.set_updated_at();

drop trigger if exists trg_check_review_eligibility on public.doctor_reviews;
create trigger trg_check_review_eligibility before insert on public.doctor_reviews
  for each row execute function public.check_review_eligibility();

drop trigger if exists trg_recalc_doctor_rating on public.doctor_reviews;
create trigger trg_recalc_doctor_rating after insert or update or delete on public.doctor_reviews
  for each row execute function public.recalc_doctor_rating();


-- ============================================================================
--  11_notifications.sql — In-app notifications inbox
-- ============================================================================
--  Rows are inserted by the SECURITY DEFINER notify_* triggers in the
--  appointment / prescription / test-report / link feature files. Users read
--  and manage only their own rows (RLS in 12_security.sql); realtime on this
--  table drives the live unread badge in the app.
-- ============================================================================

create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  type       text not null,          -- appointment_booked, appointment_cancelled, …
  title      text not null,
  body       text,
  data       jsonb,                  -- e.g. { "appointment_id": "…" }
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);


-- ============================================================================
--  12_security.sql — Shared security helpers + all Row Level Security
-- ============================================================================
--  Run AFTER all tables (02–11) exist. Centralises:
--    • doctor_has_appointment_with — used by many policies below; it queries
--      the appointments table, so it must be created after that table.
--    • delete_own_account — cross-cutting account teardown.
--    • RLS enable + every policy, grouped by table.
--  Notifications have no INSERT policy: they are written by SECURITY DEFINER
--  triggers, which bypass RLS.
-- ============================================================================

-- ── Shared security helpers ──────────────────────────────────────────────────

-- True if the current doctor has any appointment with the given patient.
create or replace function public.doctor_has_appointment_with(p_patient_id uuid)
 returns boolean language sql stable security definer set search_path to 'public' as $function$
  select exists (
    select 1 from public.appointments
    where doctor_user_id = auth.uid() and user_id = p_patient_id
  );
$function$;

-- Delete the caller's own account and all owned data.
create or replace function public.delete_own_account()
 returns void language plpgsql security definer set search_path to 'public' as $function$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Not authenticated'; end if;

  delete from public.doctor_verifications  where id = uid;
  delete from public.doctor_patient_links  where doctor_id = uid or patient_id = uid;
  update public.appointments  set doctor_user_id = null       where doctor_user_id = uid;
  update public.prescriptions set written_by_doctor_id = null where written_by_doctor_id = uid;
  delete from public.prescription_medicines
    where prescription_id in (select id from public.prescriptions where user_id = uid);
  delete from public.test_reports    where user_id = uid;
  delete from public.prescriptions   where user_id = uid;
  delete from public.appointments    where user_id = uid;
  delete from public.doctors         where user_id = uid;
  delete from public.health_profiles where id = uid;
  delete from public.profiles        where id = uid;
  delete from auth.users             where id = uid;
end;
$function$;

-- ── Enable RLS ───────────────────────────────────────────────────────────────
alter table public.profiles                enable row level security;
alter table public.health_profiles         enable row level security;
alter table public.doctors                 enable row level security;
alter table public.doctor_verifications    enable row level security;
alter table public.prescriptions           enable row level security;
alter table public.prescription_medicines  enable row level security;
alter table public.prescription_edit_logs  enable row level security;
alter table public.test_reports            enable row level security;
alter table public.appointments            enable row level security;
alter table public.doctor_patient_links    enable row level security;
alter table public.doctor_reviews          enable row level security;
alter table public.notifications           enable row level security;

-- ── profiles ──
create policy "Users can view own profile"   on public.profiles for select using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Doctor profiles readable by authenticated users" on public.profiles
  for select to authenticated using (role = 'doctor');
create policy "doctor_reads_appt_patient_profile" on public.profiles
  for select using (doctor_has_appointment_with(id));
create policy "read_linked_profiles" on public.profiles for select using (
  id = auth.uid() or exists (
    select 1 from public.doctor_patient_links l
    where (l.doctor_id = auth.uid() and l.patient_id = profiles.id)
       or (l.patient_id = auth.uid() and l.doctor_id = profiles.id)
  )
);

-- ── health_profiles ──
create policy "Users can view own health profile"   on public.health_profiles for select using (auth.uid() = id);
create policy "Users can insert own health profile" on public.health_profiles for insert with check (auth.uid() = id);
create policy "Users can update own health profile" on public.health_profiles for update using (auth.uid() = id);
create policy "doctor_reads_appt_patient_health" on public.health_profiles
  for select using (doctor_has_appointment_with(id));
create policy "doctor_reads_patient_health" on public.health_profiles for select using (
  id = auth.uid() or exists (
    select 1 from public.doctor_patient_links l
    where l.doctor_id = auth.uid() and l.patient_id = health_profiles.id and l.status = 'accepted'
  )
);

-- ── doctors ──
create policy "Users can view own doctors"   on public.doctors for select using (auth.uid() = user_id);
create policy "Users can insert own doctors" on public.doctors for insert with check (auth.uid() = user_id);
create policy "Users can update own doctors" on public.doctors for update using (auth.uid() = user_id);
create policy "Users can delete own doctors" on public.doctors for delete using (auth.uid() = user_id);

-- ── doctor_verifications ──
create policy "dv_approved_public_read" on public.doctor_verifications for select using (status = 'approved');
create policy "dv_self_insert" on public.doctor_verifications for insert with check (auth.uid() = id);
create policy "dv_self_read" on public.doctor_verifications for select using (
  auth.uid() = id or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
);
create policy "dv_update" on public.doctor_verifications for update using (
  auth.uid() = id or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
) with check (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') or auth.uid() = id
);

-- ── prescriptions ──
create policy "users_own_prescriptions" on public.prescriptions for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "doctor_reads_patient_rx" on public.prescriptions for select using (
  user_id = auth.uid() or written_by_doctor_id = auth.uid() or exists (
    select 1 from public.doctor_patient_links l
    where l.doctor_id = auth.uid() and l.patient_id = prescriptions.user_id and l.status = 'accepted'
  )
);
create policy "doctor_reads_appt_patient_rx" on public.prescriptions for select
  using (doctor_has_appointment_with(user_id));
create policy "doctor_inserts_patient_rx" on public.prescriptions for insert to authenticated with check (
  user_id = auth.uid() or (
    written_by_doctor_id = auth.uid() and (
      exists (select 1 from public.doctor_patient_links l
              where l.doctor_id = auth.uid() and l.patient_id = prescriptions.user_id and l.status = 'accepted')
      or doctor_has_appointment_with(user_id)
    )
  )
);
create policy "doctor_updates_own_written_rx" on public.prescriptions for update to authenticated
  using (written_by_doctor_id = auth.uid()) with check (written_by_doctor_id = auth.uid());

-- ── prescription_medicines ──
create policy "users_own_prescription_medicines" on public.prescription_medicines for all to authenticated
  using (prescription_id in (select id from public.prescriptions where user_id = auth.uid()))
  with check (prescription_id in (select id from public.prescriptions where user_id = auth.uid()));
create policy "doctor_manages_patient_rx_medicines" on public.prescription_medicines for all
  using (prescription_id in (select id from public.prescriptions
         where user_id = auth.uid() or written_by_doctor_id = auth.uid()))
  with check (prescription_id in (select id from public.prescriptions
         where user_id = auth.uid() or written_by_doctor_id = auth.uid()));

-- ── prescription_edit_logs ──
create policy "authenticated_reads_logs" on public.prescription_edit_logs for select to authenticated using (true);
create policy "doctor_inserts_own_log"  on public.prescription_edit_logs for insert to authenticated
  with check (doctor_id = auth.uid());

-- ── test_reports ──
create policy "Users can view own test_reports"   on public.test_reports for select using (auth.uid() = user_id);
create policy "Users can insert own test_reports" on public.test_reports for insert with check (auth.uid() = user_id);
create policy "Users can update own test_reports" on public.test_reports for update using (auth.uid() = user_id);
create policy "Users can delete own test_reports" on public.test_reports for delete using (auth.uid() = user_id);
create policy "doctor_reads_patient_labs" on public.test_reports for select using (
  user_id = auth.uid() or exists (
    select 1 from public.doctor_patient_links l
    where l.doctor_id = auth.uid() and l.patient_id = test_reports.user_id and l.status = 'accepted'
  )
);
create policy "doctor_reads_appt_patient_labs" on public.test_reports for select
  using (doctor_has_appointment_with(user_id));
create policy "doctor_inserts_patient_lab" on public.test_reports for insert with check (
  ordered_by_doctor_id = auth.uid() and exists (
    select 1 from public.doctor_patient_links l
    where l.doctor_id = auth.uid() and l.patient_id = test_reports.user_id and l.status = 'accepted'
  )
);
create policy "doctor_updates_own_lab_order" on public.test_reports for update using (
  ordered_by_doctor_id = auth.uid() and exists (
    select 1 from public.doctor_patient_links l
    where l.doctor_id = auth.uid() and l.patient_id = test_reports.user_id and l.status = 'accepted'
  )
);

-- ── appointments ──
create policy "Users can view own appointments"   on public.appointments for select using (auth.uid() = user_id);
create policy "Users can insert own appointments" on public.appointments for insert with check (auth.uid() = user_id);
create policy "Users can update own appointments" on public.appointments for update using (auth.uid() = user_id);
create policy "Users can delete own appointments" on public.appointments for delete using (auth.uid() = user_id);
create policy "doctor_reads_patient_appts" on public.appointments for select using (
  user_id = auth.uid() or doctor_user_id = auth.uid() or exists (
    select 1 from public.doctor_patient_links l
    where l.doctor_id = auth.uid() and l.patient_id = appointments.user_id and l.status = 'accepted'
  )
);
create policy "doctor_reads_by_name_snapshot" on public.appointments for select using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.role = 'doctor'
      and lower(appointments.doctor_name_snapshot) like ('%' || lower(profiles.full_name) || '%')
  )
);
create policy "doctor_inserts_patient_appts" on public.appointments for insert with check (
  user_id = auth.uid() or (
    doctor_user_id = auth.uid() and exists (
      select 1 from public.doctor_patient_links l
      where l.doctor_id = auth.uid() and l.patient_id = appointments.user_id and l.status = 'accepted'
    )
  )
);
create policy "patient_updates_own_appointment" on public.appointments for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "doctor_updates_own_appointment" on public.appointments for update to authenticated
  using (auth.uid() = doctor_user_id) with check (auth.uid() = doctor_user_id);

-- ── doctor_patient_links ──
create policy "dpl_select" on public.doctor_patient_links for select using (doctor_id = auth.uid() or patient_id = auth.uid());
create policy "dpl_insert" on public.doctor_patient_links for insert with check (doctor_id = auth.uid());
create policy "dpl_update" on public.doctor_patient_links for update using (doctor_id = auth.uid() or patient_id = auth.uid());

-- ── doctor_reviews (author-only on the base table; public reads via RPC) ──
create policy "dr_select_own" on public.doctor_reviews for select to authenticated using (patient_id = auth.uid());
create policy "dr_insert_own" on public.doctor_reviews for insert to authenticated with check (patient_id = auth.uid());
create policy "dr_update_own" on public.doctor_reviews for update to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());
create policy "dr_delete_own" on public.doctor_reviews for delete to authenticated using (patient_id = auth.uid());

-- ── notifications ──
create policy "users read own notifications"   on public.notifications for select using (auth.uid() = user_id);
create policy "users update own notifications" on public.notifications for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users delete own notifications" on public.notifications for delete using (auth.uid() = user_id);


-- ============================================================================
--  13_storage_and_jobs.sql — Storage buckets & scheduled jobs (documentation)
-- ============================================================================
--  These are managed in the Supabase dashboard, not created by SQL here. This
--  file documents them so the full backend is understandable from /schema.
-- ============================================================================

-- ── Storage buckets ──────────────────────────────────────────────────────────
--   avatars        — public   : profile photos
--   prescriptions  — private  : prescription images / PDFs
--   test_reports   — private  : test-report images / PDFs (current)
--   lab_reports    — private  : legacy bucket; still holds files uploaded before
--                               the test_reports rename — DO NOT DELETE.
--   Object-level access is governed by storage RLS policies in the dashboard.

-- ── Scheduled jobs (pg_cron) ─────────────────────────────────────────────────
--   A daily job runs expire_past_appointments() (see 08_appointments.sql) to
--   mark passed scheduled appointments as no_show. The app also calls it on
--   list load for immediacy. Example (run once to install the schedule):
--
--     select cron.schedule(
--       'expire-past-appointments',
--       '5 0 * * *',                         -- 00:05 every day
--       $$ select public.expire_past_appointments(); $$
--     );
-- ============================================================================


