# TreatTrace — Database

This folder contains all SQL files for the TreatTrace Supabase database.

---

## Which file do I run?

| Situation | File to run |
|---|---|
| **Fresh Supabase project** (first-time setup) | `treattrace_schema.sql` |
| **Applying only new changes** (incremental) | `migrations/<date>_v<N>_<desc>.sql` in order |
| **Understanding what changed in a version** | See the migration file header + `treattrace_schema.sql` Section 11 changelog |

---

## Folder structure

```
database/
├── treattrace_schema.sql                          ← Full schema v0.7 — run for fresh setup
└── migrations/
    ├── 2026_05_19_v06_lab_reports.sql             ← lab_reports table + RLS + storage bucket
    └── 2026_05_19_v07_doctors_and_appointments.sql← doctors + appointments tables + RLS
```

---

## Schema version history

| Version | Date | What was added |
|---|---|---|
| v0.7 | 2026-05-19 | `doctors`, `appointments` tables; RLS; updated_at triggers |
| v0.6 | 2026-05-19 | `lab_reports` table; `lab_reports` storage bucket; RLS |
| v0.5 | 2026-05-18 | `prescriptions`, `prescription_medicines` tables; `prescriptions` storage bucket |
| v0.4 | 2026-05-03 | `profiles.phone` column; `avatars` storage bucket policies |
| v0.3 | 2026-05-03 | Consolidated schema file created; all prior SQL merged |
| v0.2 | 2026-05-03 | `health_profiles` table + RLS |
| v0.1 | 2026-04-30 | `profiles` table; `handle_new_user()` trigger; `set_updated_at()` |

---

## Adding a new table (workflow)

1. **Write a migration file**: `database/migrations/<YYYY_MM_DD>_v<N>_<desc>.sql`
   - Copy the template from Section 10 of `treattrace_schema.sql`
   - Make it fully self-contained and idempotent (safe to re-run)
   - Include: the table, indexes, trigger, RLS policies

2. **Run it** in Supabase SQL Editor (or via Supabase MCP)

3. **Merge into `treattrace_schema.sql`** in the correct sections:
   - Section 4/5 — table definition
   - Section 6 — indexes
   - Section 7 — updated_at trigger
   - Section 8 — RLS policies
   - Section 11 — changelog entry

4. **Add Flutter code**: model → service → screens

---

## Rules

- Every file must be **idempotent** — safe to run more than once.
  Use `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS` before `CREATE TRIGGER`, `DROP POLICY IF EXISTS` before `CREATE POLICY`.
- Every table in the `public` schema **must have RLS enabled**.
- **BMI is never stored** — always computed in Flutter from `height_cm` and `weight_kg`.
- `treattrace_schema.sql` is always the **authoritative fresh-setup reference**. Keep it in sync with every migration.
