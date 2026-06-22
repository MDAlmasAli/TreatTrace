<div align="center">

# TreatTrace

### A modern healthcare companion built with Flutter & Supabase

*One app for patients **and** doctors — track prescriptions, log test reports, manage your doctors, book appointments, and run a clinic queue.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## Current Status

| Item | Detail |
|---|---|
| **Version** | v1.0.1 — Active Development |
| **Platform** | Android · iOS · Web (Chrome) |
| **Last Updated** | 2026-06-23 |

---

## 1. What is TreatTrace?

TreatTrace is a two-sided healthcare app. A single account can act as a **patient** or a **doctor** (verified), and the UI adapts to the role:

- **Patients** keep their full medical record in one place — prescriptions, test reports, a personal doctor book, a health profile (vitals/allergies/emergency contact), and appointment booking with a live clinic queue.
- **Doctors** get a portal to manage their patients, write prescriptions straight from an appointment, control their visiting days/time/capacity, run a daily ticket-based queue (with bulk reschedule/cancel), and see their anonymous patient reviews.

Everything is backed by **Supabase** (PostgreSQL + Auth + Storage + Realtime), with security enforced at the database layer through **Row Level Security (RLS)** policies, **SECURITY DEFINER** RPCs, and **triggers** — so the rules hold no matter what the client does.

---

## 2. Core Functionality

### Patient side
- **Prescriptions** — doctor info, medicines/doses/quantity, reminders, allergy check, PDF export & share.
- **Test Reports** — category picker, image/file upload to Storage, link to a doctor and to prescriptions.
- **My Doctors** — a personal doctor book (add from search, favourites, contact info, per-doctor appointment history).
- **Appointments** — book with a registered doctor, see a **live queue serial + estimated visit time**, accept/decline doctor-proposed reschedules, view linked prescriptions & test reports.
- **Doctor Reviews** — rate (1–5) + review a doctor **only after a completed appointment**; anonymous; one editable review per doctor; prompted once after each completed visit.
- **Health Profile** — vitals, BMI, allergies, emergency contact.
- **Search** — global search for doctors by `@username`, name, specialty, or hospital (with rating badges), plus your own prescriptions and test reports.

### Doctor side
- **Doctor Portal Home** — verified badge, today's appointment count, total patients, quick actions; an "under review" banner while a credential edit is pending.
- **Patient list & detail** — every patient who's been auto-linked (linking happens automatically when a doctor writes that patient a prescription); full history of their prescriptions, test reports, and appointments.
- **Write a prescription** — for a patient from the today's-schedule queue, the patient detail, or the prescriptions list; writing one from the queue marks that appointment completed. The prescription date is set automatically (read-only).
- **Visiting Info** — structured visiting days (weekday chips) + start/end time, daily patient limit, and minutes/patient — these drive slot capacity and time estimates.
- **Today / Upcoming schedule** — ticketed queue with a live serial; **long-press for multi-select** to bulk **reschedule** (proposal — patient still confirms) or **cancel**.
- **No-show** — mark "didn't come" from the appointment detail (distinct from cancel); the patient is notified and the queue behind them moves up.
- **My Reviews** — read-only list of the anonymous ratings/reviews received.
- **Credentials** — submit BMDC/specialty/hospital for verification and edit the public profile; edits go through admin approval (the doctor is put "on hold" while pending).

### Cross-cutting
- **Notifications** — in-app `notifications` table + RLS + Realtime; live unread badge and inbox. Events: new booking, prescription/test written, reschedule proposed/accepted, cancel, no-show, queue-moved-up, and doctor-under-review/available/edit-rejected. Local notification pops while the app is open (push-when-closed = future FCM phase).
- **Localisation** — English + Bangla via a custom `AppStrings` + `AppLocale` (no codegen).
- **Theming** — light-default theme, single brand blue `#136AFB`; bundled Plus Jakarta Sans; animated "Clarity Reveal" splash with a 2500 ms minimum.

---

## 3. The Queue & Booking Engine (how it works)

This is the heart of the app and is enforced server-side:

1. **Visiting rules** — a doctor's `doctor_verifications` row holds `visiting_days`, `visiting_start_time`, `visiting_end_time`, daily patient `limit`, and `minutes/patient`.
2. **Booking guards** — you can't book a past date, can't book a non-visiting day, can't exceed the daily limit (offered the **next available day** instead), can't book a doctor who is "on hold" for a pending credential edit, and can't hold more than **one active appointment per doctor** at a time.
3. **Tickets** — a `BEFORE INSERT` trigger assigns a per-doctor/per-day ticket number and the booking gets an estimated visit time (`start + ticket × minutes`).
4. **Live serial (no gaps)** — what a patient sees isn't the raw ticket but a **live queue position** (still-scheduled patients ahead + 1), computed via the `get_queue_position` RPC. When someone ahead cancels, no-shows, or reschedules away, everyone behind moves up automatically and is notified → no gaps, earlier estimates.
5. **Reschedule** — a doctor reschedule is a **proposal** (`proposed_date`); the patient accepts/declines. A normal date edit re-checks the new day's visiting-day + capacity via a `BEFORE UPDATE` trigger; accepting the doctor's proposal skips those checks (the doctor already chose the date) and re-assigns the serial.
6. **Auto-expire** — a passed scheduled appointment is auto-marked `no_show` (silently, no misleading alert) by a daily `pg_cron` job plus a lazy check on list-load.
7. **Race safety** — both the insert and reschedule triggers take a **per-doctor-per-day advisory lock** so concurrent bookings serialise, and a **partial unique index** on `(doctor_user_id, appointment_date, ticket_no)` for scheduled rows hard-blocks duplicate serials.

---

## 4. Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart 3.11+) |
| **Backend** | Supabase — PostgreSQL, Auth, Storage, Realtime, RLS |
| **State / structure** | Feature-first folders, a service class per feature |
| **Animations** | `flutter_animate` |
| **Fonts** | Plus Jakarta Sans (bundled) + `google_fonts` |
| **Notifications** | `flutter_local_notifications` + `timezone` |
| **PDF** | `pdf` + `printing` |
| **Files / media** | `file_picker`, `image_picker`, `url_launcher` |
| **Local prefs** | `shared_preferences` (theme, locale, keep-logged-in) |

---

## 5. Project Structure

The app is **feature-first** and **role-aware**: each feature owns its `models/`, `screens/`, `services/`, and (where needed) `widgets/`. Patient-facing screens live under `features/patient/`, the doctor portal under `features/doctor/`, and domains shared by both (appointments, prescriptions, test reports, reviews, notifications, search) are their own features.

```
lib/
├── core/                       # App-wide foundation (no feature logic)
│   ├── config/                 # Supabase credentials (supabase_config.dart)
│   ├── constants/              # App colour palette (#136AFB brand)
│   ├── l10n/                   # Localisation strings + AppLocale (EN + BN)
│   ├── preferences/            # SharedPreferences wrappers
│   ├── services/               # auth, account, profile, doctor-verification, reminders
│   ├── theme/                  # ThemeColors + ThemeData (light default)
│   └── utils/                  # validators, file helpers
├── shared/
│   └── widgets/                # cross-feature widgets (linked-doctor picker)
├── features/
│   ├── auth/                   # login, signup, forgot-password, role selection
│   ├── patient/                # patient home, profile, edit profile, My Doctors book
│   ├── doctor/                 # doctor portal: home, patients, schedule, write Rx, credentials
│   ├── admin/                  # admin verification console
│   ├── appointment/            # booking, status, live queue serial, detail
│   ├── prescription/           # prescriptions + medicines (+ PDF)
│   ├── test_report/            # test reports + uploads
│   ├── review/                 # anonymous doctor review system
│   ├── notification/           # notifications inbox + service + realtime badge
│   └── search/                 # global search + public doctor profile
└── main.dart                   # entry point, splash, AuthGate, role routing

database/
├── schema/                     # full schema — one file per feature, run 00_→13_ in order
├── README.md                   # how to set up / run the schema
└── SCHEMA_VERIFICATION.md      # object-by-object proof the SQL matches the live DB

PROJECT_MAP.md                  # find-anything index: every screen/model/service → file + class
```

> **New to the code?** Open [`PROJECT_MAP.md`](PROJECT_MAP.md) — it lists every page/feature with its file path and class name, grouped by area.

---

## 6. Data Model

Twelve PostgreSQL tables, all with RLS enabled:

| Table | Purpose |
|---|---|
| `profiles` | User profile, `@username`, full name, role (patient/doctor/admin) |
| `health_profiles` | Patient vitals, allergies, emergency contact (BMI computed client-side) |
| `doctors` | A patient's personal doctor book (free-text entries) |
| `doctor_verifications` | Doctor verification + visiting days/time, capacity, `rating_avg`/`rating_count`, staged `pending_*` edits |
| `prescriptions` | Doctor info, diagnosis, dates, image URLs, who wrote it |
| `prescription_medicines` | Per-medicine rows (dose, quantity, timing, before/after meal) |
| `prescription_edit_logs` | One create/edit entry per prescription per day (rate-limit) |
| `test_reports` | Category, file URLs, linked doctor & prescriptions |
| `appointments` | Bookings: status, `ticket_no`, `proposed_date`, linked Rx/test arrays, `review_prompted` |
| `doctor_patient_links` | Auto-link between a doctor and a patient |
| `doctor_reviews` | Anonymous 1–5 reviews (RLS: author sees only own) |
| `notifications` | In-app notifications (RLS + Realtime, unread badge) |

Security is layered: **RLS** restricts base-table rows to their owner; **SECURITY DEFINER RPCs** (e.g. `get_doctor_reviews`, `get_queue_position`, `can_review_doctor`) expose only safe, aggregated/anonymous data; **triggers** enforce booking rules, ticketing, queue renumbering, review eligibility, and notifications.

A full column-by-column proof that `database/schema/` matches the live Supabase database is in [`database/SCHEMA_VERIFICATION.md`](database/SCHEMA_VERIFICATION.md).

---

## 7. Quick Setup

```bash
git clone https://github.com/MDAlmasAli/TreatTrace.git
cd TreatTraceV1
flutter pub get
```

1. Set your Supabase URL + anon key in `lib/core/config/supabase_config.dart`.
2. Run the SQL in `database/schema/` in numeric order (`00_`…`13_`) — or `cat database/schema/*.sql | psql "$DATABASE_URL"`. See [`database/README.md`](database/README.md).
3. Launch:

```bash
flutter run
```

---

## 8. Changelog (highlights)

**v1.0.1** *(2026-06-23)* — Shortened verbose inline and doc comments in `appointment_detail_screen.dart` (code-only cleanup, no behaviour change).

**v1.0.1** *(2026-06-21)* — Removed the "Manual", "File", and "File Upload" sub-chips from the Prescription and Test Report quick-action cards on the patient home screen.

**v1.0.0** — Fixed "Manual" button text being clipped in the patient home screen Prescription card. Wrapped `_SubChip`'s label in `Flexible` with `overflow: TextOverflow.ellipsis` so button text renders fully at all screen sizes.

**v0.99** — Prescription list now has a **stable sort order**. Lists were ordered by `prescription_date` (descending) only, so multiple prescriptions sharing the same date had no guaranteed order and could shuffle between refreshes. A secondary `created_at` (descending) tiebreaker was added to both the patient's own list and the doctor's patient-view, so same-day prescriptions stay in a consistent, newest-added-first order.

**v0.98** — Location is now constrained to a fixed district + hospital list during doctor credential submission, search results update in realtime, and long doctor reviews get a "show more" expander.

**v0.97** — Live "now serving" queue: the patient's queue screen shows the doctor's current serving ticket in realtime, and ticket serials are now permanent (assigned once and kept) rather than recomputed.

**v0.96** — Appointment privacy, richer tiles, and an auth fix. (1) **Privacy:** in a doctor's view of a patient, only the doctor's *own* appointments show full details and open; other doctors' appointments are redacted (doctor name, date, status only) and can't be opened. (2) **Tiles:** each appointment row now leads with the doctor's name and shows linked prescription / test-report counts; the doctor's own appointments are tappable in both the patient-detail preview **and** the All Appointments list (both now share one `PatientAppointmentTile` widget). (3) **Logout→login fix:** logging out used to wipe the whole navigator stack and push a bare login screen, destroying the `AuthGate` that auto-navigates on login — so signing into a second account left it "stuck" until an app restart. Logout now pops back to the `AuthGate` root (which survives), so the next login routes itself. The same fix is applied to account deletion (which now also clears the local session).

**v0.95** — Codebase housekeeping (no behaviour change). `lib/` reorganised into a clean role-based, feature-first layout: patient screens consolidated under `features/patient/`, the doctor portal merged under `features/doctor/`, and the one shared widget moved to `shared/widgets/`. Screens and classes renamed for clarity (e.g. `HomeScreen`→`PatientHomeScreen`, `DoctorsScreen`→`MyDoctorsScreen`); model files now use the `*_model.dart` suffix. Removed 7 dead/unwired files. Added [`PROJECT_MAP.md`](PROJECT_MAP.md) (a find-anything index of every screen/model/service) and [`database/SCHEMA_VERIFICATION.md`](database/SCHEMA_VERIFICATION.md) (object-by-object proof that the SQL matches the live database). All READMEs rebuilt to match the current code.

**v0.94** — Three scheduling refinements: (1) a doctor can write a prescription only on the appointment's own date — earlier/later dates show a locked note instead of the button; (2) when someone ahead leaves the queue (cancel / no-show / reschedule away), every patient behind is notified that their serial moved up ("You are now #N"), today/future queues only; (3) accepting a doctor-proposed reschedule no longer fails when the chosen date isn't a visiting day or is full — the doctor picked it, so the patient can just accept (a ticket is still assigned).

**v0.93** — Write Prescription: the prescription date is now set automatically (today) and shown read-only — no date picker. Medicines gain a free-text **Quantity** field (e.g. "10 tablets", "1 strip"), shown on the prescription detail and PDF. Patient home's "Last Prescribed" button now opens the most recent prescription directly. Doctors can also revise a still-pending credential edit (a prominent "Edit Submission" button; re-submitting overwrites the pending one).

**v0.92** — Doctor "on hold" while a credential edit awaits admin approval (`edit_status = 'pending'`): the doctor is hidden from patient search, new bookings are blocked server-side (`DOCTOR_ON_HOLD` / availability `on_hold`) with a clear message on the patient and doctor booking screens, the public profile shows a "temporarily unavailable" note with the booking button disabled, and the doctor portal shows an "under review" banner (existing appointments keep working). Patients with a scheduled appointment are notified when the doctor goes under review and again when it lifts; the doctor is notified if the edit is rejected. A pending edit can now be revised before approval (re-submitting overwrites it). Admin approve/reject lifts the hold automatically.

**v0.91** — Patient doctor search overhaul: all registered doctors now show by default (sorted by rating), and a filter/sort button beside the search bar opens a sheet with sort (rating / fee / name / most reviewed) and filters for specialty, hospital, visiting-fee range, visiting day, time of day, and minimum rating. Tapping a doctor opens their public profile. Also fixed the booking confirmation SnackBar (and the detail "Serial" row) to show the live queue position instead of the raw ticket number.

**v0.90** — Dropped the redundant combined `treattrace_schema.sql`; `database/schema/` (run `00_`…`13_` in order) is now the single source of truth. READMEs updated accordingly.

**v0.89** — Database SQL brought in line with the live schema and reorganized: the stale `database/features/` + `database/migrations/` fragments are replaced by a per-feature `database/schema/` breakdown (one file per table, with RLS grouped in `12_security.sql`). Also fixed `delete_own_account()` which still referenced the renamed `lab_reports` table.

**v0.88** — Highlight the doctor's name in the post-appointment "Rate your visit" prompt (brand-blue bold, easier to read).

**v0.87** — Race-safe ticket booking: per-doctor-per-day advisory lock on the insert/reschedule triggers + partial unique index on scheduled tickets (no duplicate serials / overbooking under concurrency).

**v0.86** — Patient appointment cards show the live queue serial + estimated visit time (e.g. "#2 · ~5:10 PM").

**v0.85** — Post-appointment review prompt: after a completed visit the patient is prompted once (Submit/Skip), tracked via `appointments.review_prompted`.

**v0.84** — Doctor picker "No Doctor Linked" renamed to "Clear selection".

**v0.83** — Searchable doctor picker (bottom sheet) in Add Appointment — filter My Doctors by name/specialty/hospital.

**v0.82** — Removed unused manual doctor-patient request code (linking is automatic via prescriptions); dropped the always-zero "Pending Tasks" stat.

**v0.81** — Compact doctor home header & stats.

**v0.80** — "Write Prescription" only shows while an appointment is `scheduled`.

**v0.79** — Fixed `no_show` status CHECK violation + Pick Date button overflow (chips now scroll horizontally).

**v0.78** — Fixed clipped "View Appointment" button on large font scales.

**v0.77** — Added `INTERNET` permission so release APKs can reach Supabase (was failing with errno=7).

**v0.76** — Removed standalone "Write Prescription" card from doctor home; "My Reviews" placed beside "Visiting Info".

**v0.75** — Anonymous, verified doctor review system (rate only after a completed appointment; RPC-anonymous public list; aggregate rating on profile/search/portal).

**v0.74** — Live queue serial (no gaps), `no_show` status, reschedule renumber + notifications.

**v0.73** — Bulk reschedule/cancel from the doctor schedule (long-press multi-select).

**v0.72** — No past-date booking + auto-expire (silent) of passed appointments via `pg_cron`.

**v0.71** — Ticket system + daily capacity + minutes/patient time estimates.

**v0.70** — Structured visiting days & start/end time (doctor Visiting Info).

**v0.69** — One active appointment per doctor (DB-enforced).

**v0.68** — Reschedule requires patient confirmation (proposal + accept/decline).

**v0.66–v0.67** — In-app notification system (table + RLS + Realtime + inbox) and the first reschedule/cancel + notification events.

**v0.50–v0.65** — Prescription/test-report linking (multi-link), doctor-side appointment detail & write-from-appointment, richer tiles (doctor name + date + diagnosis), and assorted crash/UX fixes.

---

## 9. Authors

- **MD Almas Ali**
- **Tasmina Rahman Chowdhury**
- **Sharon Sahrin Mim**

---

<div align="center">

*TreatTrace — Your health, our priority.*

</div>
