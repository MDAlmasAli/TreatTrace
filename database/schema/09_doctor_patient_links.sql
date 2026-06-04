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
