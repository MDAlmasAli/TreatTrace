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
