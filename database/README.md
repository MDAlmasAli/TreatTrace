# TreatTrace — Database

This folder contains all SQL files for the TreatTrace Supabase database.

---

## Which file do I run?

| Situation | File to run |
|---|---|
| **Fresh Supabase project** (first-time setup) | `treattrace_schema.sql` |
| **Adding a new feature** (one table at a time) | `features/<NN>_<feature>.sql` |
| **Understanding what changed in a version** | `migrations/<date>_v<N>_<desc>.sql` |

---

## Folder structure

```
database/
├── treattrace_schema.sql           ← Full schema — run this for a fresh setup
├── features/
│   ├── 01_auth_profiles.sql        ← profiles table + handle_new_user + RLS
│   └── 02_health_profile.sql       ← health_profiles table + indexes + RLS
└── migrations/
    ├── 2026_05_03_v01_initial.sql  ← Snapshot: what was set up on 2026-04-30
    └── 2026_05_03_v02_health_profile.sql ← Snapshot: health_profiles added 2026-05-03
```

---

## Adding a new table (workflow)

1. **Create a feature file**: `database/features/<NN>_<feature_name>.sql`
   - Copy the template from Section 10 of `treattrace_schema.sql`
   - Make it fully self-contained and idempotent (safe to re-run)
   - Include: extensions, `set_updated_at()` (CREATE OR REPLACE), the table, indexes, trigger, RLS

2. **Run the feature file** in Supabase SQL Editor to apply it

3. **Add the same SQL** into `treattrace_schema.sql` in the correct sections:
   - Section 4 (tables) or Section 5 (junction tables)
   - Section 6 (indexes)
   - Section 7 (triggers)
   - Section 8 (RLS policies)
   - Section 11 (changelog)

4. **Create a migration snapshot**: `database/migrations/<YYYY_MM_DD>_v<N>_<desc>.sql`
   - Contains only the new SQL (not the full schema)
   - Add a header comment explaining what was added and why

5. **Update the Flutter code**: create or update the service in `lib/core/services/`

---

## Rules

- Every file must be **idempotent** — safe to run more than once.
  Use `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS` before `CREATE TRIGGER`, `DROP POLICY IF EXISTS` before `CREATE POLICY`.
- Every table in the `public` schema **must have RLS enabled**.
- **BMI is never stored** — always computed in Flutter from `height_cm` and `weight_kg`.
- The `treattrace_schema.sql` file is always the **authoritative fresh-setup reference**.
  Keep it up to date whenever you add or change anything.
