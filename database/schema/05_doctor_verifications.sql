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

-- Notifications around a profile-edit review (a doctor is "on hold" while
-- edit_status = 'pending' — see the booking guards in 08_appointments.sql):
--   • edit goes → 'pending' : reassure patients with a scheduled appointment
--   • edit leaves 'pending'  : tell those patients the doctor is back to normal
--   • edit → 'rejected'      : notify the doctor (with the reason)
create or replace function public.notify_doctor_edit_status_change()
 returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare
  doc_name text;
begin
  if new.edit_status is not distinct from old.edit_status then
    return new;
  end if;

  select coalesce(nullif(trim(full_name), ''), 'your doctor')
    into doc_name from public.profiles where id = new.id;

  if new.edit_status = 'pending' and old.edit_status is distinct from 'pending' then
    insert into public.notifications (user_id, type, title, body, data)
    select distinct a.user_id, 'doctor_under_review', 'Doctor profile update',
      'Dr. ' || doc_name || ' is currently updating their profile details. '
        || 'Your scheduled appointment is not affected.',
      jsonb_build_object('doctor_id', new.id)
    from public.appointments a
    where a.doctor_user_id = new.id and a.status = 'scheduled';
  end if;

  if old.edit_status = 'pending' and new.edit_status is distinct from 'pending' then
    insert into public.notifications (user_id, type, title, body, data)
    select distinct a.user_id, 'doctor_available', 'Doctor profile updated',
      'Dr. ' || doc_name || ' is available as usual. '
        || 'Your scheduled appointment is unaffected.',
      jsonb_build_object('doctor_id', new.id)
    from public.appointments a
    where a.doctor_user_id = new.id and a.status = 'scheduled';
  end if;

  if new.edit_status = 'rejected' and old.edit_status is distinct from 'rejected' then
    insert into public.notifications (user_id, type, title, body, data)
    values (new.id, 'edit_rejected', 'Profile edit rejected',
      'Your profile changes were rejected'
        || coalesce(': ' || nullif(trim(new.edit_rejection_reason), ''), '') || '.',
      jsonb_build_object('doctor_id', new.id));
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_notify_doctor_edit_status_change on public.doctor_verifications;
create trigger trg_notify_doctor_edit_status_change
  after update on public.doctor_verifications
  for each row execute function public.notify_doctor_edit_status_change();
