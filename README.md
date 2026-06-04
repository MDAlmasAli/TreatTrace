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
| **Version** | v0.91 — Active Development |
| **Platform** | Android · iOS · Web (Chrome) |
| **Last Updated** | 2026-06-04 |

---

## 1. What is TreatTrace?

TreatTrace is a two-sided healthcare app. A single account can act as a **patient** or a **doctor** (verified), and the UI adapts to the role:

- **Patients** keep their full medical record in one place — prescriptions, test reports, a personal doctor book, a health profile (vitals/allergies/emergency contact), and appointment booking with a live clinic queue.
- **Doctors** get a portal to manage their patients, write prescriptions and order tests straight from an appointment, control their visiting days/time/capacity, run a daily ticket-based queue (with bulk reschedule/cancel), and see their anonymous patient reviews.

Everything is backed by **Supabase** (PostgreSQL + Auth + Storage + Realtime), with security enforced at the database layer through **Row Level Security (RLS)** policies, **SECURITY DEFINER** RPCs, and **triggers** — so the rules hold no matter what the client does.

---

## 2. Core Functionality

### Patient side
- **Prescriptions** — doctor info, medicines/doses, reminders, allergy check, PDF export & share.
- **Test Reports** — category picker, image/file upload to Storage, link to a doctor and to prescriptions.
- **My Doctors** — a personal doctor book (favourites, contact info, per-doctor appointment history).
- **Appointments** — book with a registered doctor, see a **live queue serial + estimated visit time**, accept/decline doctor-proposed reschedules, view linked prescriptions & test reports.
- **Doctor Reviews** — rate (1–5) + review a doctor **only after a completed appointment**; anonymous; one editable review per doctor; prompted once after each completed visit.
- **Health Profile** — vitals, BMI, allergies, emergency contact.
- **Search** — global search for doctors by `@username`, name, specialty, or hospital, with rating badges.

### Doctor side
- **Doctor Portal Home** — verified badge, today's appointment count, total patients, quick actions.
- **Patient list & detail** — every patient who's been auto-linked (linking happens automatically when a doctor writes that patient a prescription); full history of their prescriptions, test reports, and appointments.
- **Write from appointment** — write a prescription or order a test directly from the appointment detail; writing a prescription marks the appointment completed.
- **Visiting Info** — structured visiting days (weekday chips) + start/end time, daily patient limit, and minutes/patient — these drive slot capacity and time estimates.
- **Today / Upcoming schedule** — ticketed queue with a live serial; **long-press for multi-select** to bulk **reschedule** (proposal — patient still confirms) or **cancel**.
- **No-show** — mark "didn't come" from the appointment detail (distinct from cancel); the patient is notified and the queue behind them moves up.
- **My Reviews** — read-only list of the anonymous ratings/reviews received.

### Cross-cutting
- **Notifications** — in-app `notifications` table + RLS + Realtime; live unread badge and inbox. Events: new booking, prescription/test written, reschedule proposed/accepted, cancel, no-show. Local notification pops while the app is open (push-when-closed = future FCM phase).
- **Localisation** — English + Bangla via `S.of(context)`.
- **Theming** — light-default theme, single brand blue `#136AFB`; bundled Plus Jakarta Sans; animated "Clarity Reveal" splash with a 2500 ms minimum.

---

## 3. The Queue & Booking Engine (how it works)

This is the heart of the app and is enforced server-side:

1. **Visiting rules** — a doctor's `doctor_verifications` row holds `visiting_days`, `visiting_start_time`, `visiting_end_time`, daily patient `limit`, and `minutes/patient`.
2. **Booking guards** — you can't book a past date, can't book a non-visiting day, can't exceed the daily limit (offered the **next available day** instead), and can't hold more than **one active appointment per doctor** at a time.
3. **Tickets** — a `BEFORE INSERT` trigger assigns a per-doctor/per-day ticket number and the booking gets an estimated visit time (`start + ticket × minutes`).
4. **Live serial (no gaps)** — what a patient sees isn't the raw ticket but a **live queue position** (still-scheduled patients ahead + 1), computed via the `get_queue_position` RPC. When someone ahead cancels, no-shows, or reschedules away, everyone behind moves up automatically → no gaps, earlier estimates.
5. **Reschedule** — a doctor reschedule is a **proposal** (`proposed_date`); the patient accepts/declines. Accepting re-checks the new day's visiting-day + capacity via a `BEFORE UPDATE` trigger and re-assigns the serial.
6. **Auto-expire** — a passed scheduled appointment is auto-marked `no_show` (silently, no misleading alert) by a daily `pg_cron` job plus a lazy check on list-load.
7. **Race safety** — both the insert and reschedule triggers take a **per-doctor-per-day advisory lock** so concurrent bookings serialise, and a **partial unique index** on `(doctor_user_id, appointment_date, ticket_no)` for scheduled rows hard-blocks duplicate serials.

---

## 4. Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart 3.11+) |
| **Backend** | Supabase — PostgreSQL, Auth, Storage, Realtime, RLS |
| **State / structure** | Feature-first folders, service classes per feature |
| **Animations** | `flutter_animate` |
| **Fonts** | Plus Jakarta Sans (bundled) + `google_fonts` |
| **Notifications** | `flutter_local_notifications` + `timezone` |
| **PDF** | `pdf` + `printing` |
| **Files / media** | `file_picker`, `image_picker`, `url_launcher` |
| **Local prefs** | `shared_preferences` (theme, locale, keep-logged-in) |

---

## 5. Project Structure

The app is **feature-first**: each feature owns its `models/`, `screens/`, `services/`, and (where needed) `widgets/`.

```
lib/
├── core/                       # App-wide foundation (no feature logic)
│   ├── config/                 # Supabase credentials/config
│   ├── constants/              # App-wide constants
│   ├── l10n/                   # Localisation strings (EN + BN)
│   ├── preferences/            # SharedPreferences wrappers
│   ├── services/               # auth, account, profile, doctor verification, reminders
│   ├── theme/                  # Colours (brand #136AFB), typography, ThemeData
│   ├── utils/                  # Helpers & extensions
│   └── widgets/                # Shared UI components
├── features/
│   ├── admin/                  # Admin panel (doctor verification, etc.)
│   ├── appointment/            # Booking, status, queue serial, detail
│   ├── auth/                   # Login, register, AuthGate + splash
│   ├── doctor/                 # My Doctors (patient-side doctor book)
│   ├── doctor_home/            # Doctor portal: patient list, detail, schedule
│   ├── home/                   # Patient home screen
│   ├── notification/           # Notifications inbox + service + realtime badge
│   ├── prescription/           # Prescriptions CRUD + PDF
│   ├── profile/                # Health profile, vitals
│   ├── review/                 # Anonymous doctor review system
│   ├── search/                 # Global search + public doctor profile
│   └── test_report/            # Test reports CRUD + uploads
├── shared/
│   └── widgets/                # Cross-feature widgets
└── main.dart                   # Entry point, splash, AuthGate, role routing

database/
└── schema/                     # The full schema — one file per feature, run 00_→13_ in order
```

---

## 6. Data Model (key tables)

| Table | Purpose |
|---|---|
| `profiles` | User profile, `@username`, full name, role flags |
| `doctor_verifications` | Doctor verification + visiting days/time, capacity, `rating_avg`/`rating_count` |
| `appointments` | Bookings: status, ticket_no, proposed_date, linked Rx/test arrays, `review_prompted` |
| `prescriptions` | Doctor info, medicines, diagnosis, reminders |
| `test_reports` | Category, file URL, linked doctor & prescriptions |
| `doctor_patient_links` | Auto-link between a doctor and a patient |
| `doctor_reviews` | Anonymous 1–5 reviews (RLS: author sees only own) |
| `notifications` | In-app notifications (RLS + Realtime, unread badge) |

Security is layered: **RLS** restricts base-table rows to their owner; **SECURITY DEFINER RPCs** (e.g. `get_doctor_reviews`, `get_queue_position`, `can_review_doctor`) expose only safe, aggregated/anonymous data; **triggers** enforce booking rules, ticketing, queue renumbering, review eligibility, and notifications.

---

## 7. Quick Setup

```bash
git clone https://github.com/MDAlmasAli/TreatTrace.git
cd TreatTraceV1
flutter pub get
```

1. Set your Supabase URL + anon key in `lib/core/config/supabase_config.dart`.
2. Run the SQL in `database/schema/` in numeric order (`00_`…`13_`) — or `cat database/schema/*.sql | psql "$DATABASE_URL"`. See `database/README.md`.
3. Launch:

```bash
flutter run
```

---

## 8. Changelog (highlights)

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
