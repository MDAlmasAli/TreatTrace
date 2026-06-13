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

-- ── Realtime ────────────────────────────────────────────────────────────────
-- Publish row changes so the patient's test-report list updates live. REPLICA
-- IDENTITY FULL lets clients filter on non-PK columns (e.g. user_id).
alter table public.test_reports replica identity full;
do $$ begin
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'test_reports') then
    alter publication supabase_realtime add table public.test_reports;
  end if;
end $$;
