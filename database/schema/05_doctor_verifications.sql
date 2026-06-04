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
