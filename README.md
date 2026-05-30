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
| **Version** | v0.53 — Active Development |
| **Platform** | Android · iOS · Web (Chrome) |
| **Last Updated** | 2026-05-30 |

---

## Recent Updates

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

## Authors

- **MD Almas Ali**
- **Tasmina Rahman Chowdhury**
- **Sharon Sahrin Mim**

---

<div align="center">

*TreatTrace — Your health, our priority.*

</div>
