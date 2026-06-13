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

-- ── Realtime ────────────────────────────────────────────────────────────────
-- Publish row changes so the notification bell's unread badge updates live.
-- REPLICA IDENTITY FULL lets clients filter on the non-PK user_id column.
alter table public.notifications replica identity full;
do $$ begin
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
