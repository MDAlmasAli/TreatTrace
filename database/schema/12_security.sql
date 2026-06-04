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
