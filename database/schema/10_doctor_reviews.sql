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
