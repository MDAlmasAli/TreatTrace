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
