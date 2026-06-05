# TreatTrace — Database

All SQL for the TreatTrace Supabase (PostgreSQL) backend. The SQL mirrors the
live project exactly — what you read here is what runs in production. That claim
is not just a promise: [`SCHEMA_VERIFICATION.md`](SCHEMA_VERIFICATION.md) is an
object-by-object proof (every table, column, function, trigger, RLS policy and
index) that `schema/` matches the live database, with the read-only queries to
re-check it yourself.

---

## Layout

```
database/
├── schema/                    ← the single source of truth — one file per feature
│   ├── 00_extensions.sql          pgcrypto (gen_random_uuid)
│   ├── 01_functions_shared.sql    set_updated_at()  — used by every updated_at trigger
│   ├── 02_profiles.sql            profiles + signup trigger + username / patient-search RPCs
│   ├── 03_health_profiles.sql     patient vitals / allergies / emergency contact
│   ├── 04_doctors.sql             a patient's personal doctor book (free-text)
│   ├── 05_doctor_verifications.sql registered-doctor profile, visiting schedule/capacity, rating
│   ├── 06_prescriptions.sql       prescriptions + medicines + edit logs + notify
│   ├── 07_test_reports.sql        lab / diagnostic test reports + notify
│   ├── 08_appointments.sql        appointments + ticketing / queue / availability / expire + notify
│   ├── 09_doctor_patient_links.sql doctor↔patient links + auto-link + notify
│   ├── 10_doctor_reviews.sql      anonymous reviews + eligibility + rating recalc + public RPC
│   ├── 11_notifications.sql       in-app notifications inbox
│   ├── 12_security.sql            shared security helpers + ALL Row Level Security policies
│   └── 13_storage_and_jobs.sql    storage buckets + pg_cron (documentation only)
├── README.md                  ← this file
└── SCHEMA_VERIFICATION.md     ← proof the SQL matches the live Supabase database
```

**Each feature file owns its table + that table's functions + triggers**, so to
understand one feature you read one file. The only cross-cutting concerns are
pulled out: `set_updated_at` (used everywhere) sits in `01_`, and everything
access-control — RLS plus the `doctor_has_appointment_with` helper the policies
depend on — is grouped in `12_security.sql`.

---

## Tables (12)

`profiles` · `health_profiles` · `doctors` · `doctor_verifications` ·
`prescriptions` · `prescription_medicines` · `prescription_edit_logs` ·
`test_reports` · `appointments` · `doctor_patient_links` · `doctor_reviews` ·
`notifications` — all with Row Level Security enabled. Backed by 25 functions,
19 triggers, and 55 RLS policies (see `SCHEMA_VERIFICATION.md` for the full
breakdown and which file defines each object).

---

## Setting up a fresh Supabase project

Run the files in `schema/` **in numeric order** (`00_` → `13_`). The order
matters: there are dependencies between files (e.g. policies in `12_` use a
function that needs the `appointments` table from `08_`).

- **Supabase SQL editor:** paste and run each file `00_`…`13_` in turn.
- **psql / CLI:** concatenate and run in one go:

  ```bash
  cd database
  cat schema/*.sql | psql "$DATABASE_URL"
  ```

  (`schema/*.sql` already sorts in the correct order because of the numeric
  prefixes.)

Every file is **idempotent**, so re-running the whole set is safe.

---

## Rules

- Everything is **idempotent** — safe to re-run: `create table if not exists`,
  `create or replace function`, `drop trigger/policy if exists` before create.
- Every `public` table **has RLS enabled** (see `12_security.sql`).
- **BMI is never stored** — computed in Flutter from `height_cm` / `weight_kg`.
- **Storage buckets & pg_cron** are managed in the Supabase dashboard; they are
  documented (not created) in `13_storage_and_jobs.sql`.
- The legacy `lab_reports` storage bucket is **kept** — it still holds files
  uploaded before the `test_reports` rename. The live `test_reports` table's
  constraints also still carry the legacy `lab_reports_*` names (harmless — same
  columns and behaviour; a fresh run from `07_` would simply name them
  `test_reports_*`). See `SCHEMA_VERIFICATION.md` §6.
