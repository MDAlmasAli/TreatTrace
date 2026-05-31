<div align="center">

# TreatTrace

### A modern healthcare companion app built with Flutter & Supabase

*Track prescriptions · Log test reports · Manage your doctors · Book appointments — all in one place.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## Current Status

| Item | Detail |
|---|---|
| **Version** | v0.55 — Active Development |
| **Platform** | Android · iOS · Web (Chrome) |
| **Last Updated** | 2026-05-31 |

---

## Recent Updates

**v0.55 — Fix appointment tile in doctor patient detail: navigate to full appointment detail**
- Doctor patient detail: tapping an appointment tile now opens AppointmentDetailScreen
- All linked prescriptions and test reports visible and tappable from appointment detail
- Removed stale single-prescription direct-navigation from appointment tile

**v0.54 — Fix appointment detail: show all linked prescriptions and test reports**
- Appointment detail: all linked prescriptions shown with doctor name + date, each tappable
- Appointment detail: all linked test reports shown with test name, each tappable
- Appointment list card: updated to use `prescriptionIds` array; test report icon added

**v0.53 — Multiple link support for prescriptions and test reports**
- Appointment add/edit: link multiple prescriptions + multiple test reports (chip picker + bottom sheet)
- Test report add/edit: link multiple prescriptions
- DB: `prescription_ids text[]` + `test_report_ids text[]` added; existing data migrated from single-id columns

**v0.52 — Appointment tile shows doctor name and date**
- Appointment badge now shows "Dr. Name — DD Mon YYYY" instead of static "Linked Prescription"

**v0.51 — Appointment sort in doctor patient detail**
- Upcoming appointments first (ascending); completed below (descending)

**v0.50 — Fix linked prescription UUID in test report detail**
- Shows "Dr. Name — DD/MM/YYYY" instead of raw UUID
- Doctor patient detail: linked appointment tiles now tappable, open prescription

---

## Features

- **Prescriptions** — doctor info, medicines, doses, reminders, allergy check, PDF export
- **Test Reports** — category picker, image/file upload, doctor link, prescription link
- **My Doctors** — personal doctor book with favorites, contact info, appointments
- **Appointments** — booking, status management (Scheduled / Completed / Cancelled)
- **Doctor Portal** — patient list, full patient detail, write prescriptions, view test reports
- **Health Profile** — vitals, BMI, allergies, emergency contact
- **Username System** — unique `@username` per account, searchable
- **Animated Splash** — Clarity Reveal sequence with 2500 ms minimum display
- **Localisation** — English + Bangla (`S.of(context)`)

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + RLS) |
| **Animations** | `flutter_animate` |
| **Fonts** | Plus Jakarta Sans (bundled TTF) |
| **Notifications** | `flutter_local_notifications` |
| **PDF** | `pdf` + `printing` |

---

## Quick Setup

```bash
git clone https://github.com/MDAlmasAli/TreatTrace.git
cd TreatTraceV1
flutter pub get
```

Set your Supabase credentials in `lib/core/config/supabase_config.dart`, run `database/treattrace_schema.sql` in the Supabase SQL editor, then:

```bash
flutter run
```

---

## Project Structure

```
lib/
├── core/
│   ├── config/          # Supabase config
│   ├── constants/       # App-wide constants
│   ├── l10n/            # Localisation (EN + BN)
│   ├── preferences/     # Local prefs (SharedPreferences)
│   ├── services/        # Auth, storage, notifications
│   ├── theme/           # Colours, typography, ThemeData
│   ├── utils/           # Helpers, extensions
│   └── widgets/         # Shared UI components
├── features/
│   ├── admin/           # Admin panel
│   ├── appointment/     # Booking, status management
│   ├── auth/            # Login, register, auth gate
│   ├── doctor/          # My Doctors (patient side)
│   ├── doctor_home/     # Doctor portal (patient list, detail)
│   ├── home/            # Patient home screen
│   ├── prescription/    # Prescriptions CRUD
│   ├── profile/         # Health profile, vitals
│   ├── search/          # Global search
│   └── test_report/     # Test reports CRUD
├── shared/
│   └── widgets/         # Cross-feature widgets
└── main.dart
```

---

## Authors

- **MD Almas Ali**
- **Tasmina Rahman Chowdhury**
- **Sharon Sahrin Mim**

---

<div align="center">

*TreatTrace — Your health, our priority.*

</div>
