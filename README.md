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

## Current Project Status

| Item | Detail |
|---|---|
| **Stage** | v0.8 — Active Development |
| **UI Status** | Auth · Home · Profile · Prescriptions · Test Reports · Doctors · Appointments |
| **Backend Status** | Auth · Profile · Prescriptions + Medicines · Lab Reports · Doctors · Appointments |
| **Platform** | Android · iOS · Web |
| **Last Updated** | 2026-05-21 |

---

## Latest Updates (2026-05-21)

**v0.8 — DocTime-Style UI Overhaul**

- Entire app visual language redesigned to match DocTime (professional Bangladeshi healthcare app)
- **Single brand blue `#136AFB`** replaces the previous multi-colour feature accent system (purple / cyan / green / amber per module)
- **Light theme is now the default** — was previously `system` (often dark on most devices)
- `ThemeColors` centralised: `c.accent` = `#136AFB` in light mode, purple in dark mode; `c.purpleBright` / `c.cyan` alias to brand blue in light
- Removed `ShaderMask` gradient text ("Quick Actions" header was purple→cyan gradient)
- All coloured glow box-shadows (`DarkColors.X.withAlpha(N)`) replaced with neutral `Colors.black.withAlpha(small)`
- Splash screen rewritten to white/blue light theme (removed dark gradient)
- Fixed light-mode dialogs that were incorrectly rendering with dark card background
- All 22 Dart files updated; zero `DarkColors` hardcodes remain in feature screens
- `flutter analyze` passes clean (exit code 0)

**v0.7 — Doctor Book + Appointment Log**

- **My Doctors** — personal doctor address book with name, specialty, hospital, chamber address, phone, fee, notes; favorites toggle (heart icon)
- **Appointments** — full appointment log with 3-tab view (Upcoming / Past / Cancelled); status management (Mark Completed / Cancel)
- Doctor and Appointment screens linked: doctor detail screen shows all visits for that doctor; add appointment pre-fills the doctor
- `doctor_name_snapshot` preserves doctor name on appointments even if the doctor record is later deleted
- Home screen Quick Actions grid now shows **My Doctors** (green) and **Appointments** (amber) as live navigation cards
- Supabase tables: `doctors` + `appointments` with full RLS and `updated_at` triggers

**v0.6 — Test Report Viewer**

- **Test Reports** — upload lab results with category (Blood Test, X-Ray, MRI/CT, Ultrasound, ECG, Pathology, or custom), test date, referring doctor, lab/hospital, notes
- Multi-image upload per report (same pattern as prescriptions)
- Category filter chips on the list screen
- Optional prescription link — reports can reference an existing prescription
- Supabase table: `lab_reports` with `image_urls TEXT[]` and `prescription_id` nullable FK

---

## Update History

- `[2026-05-21]` DocTime-style UI overhaul — single `#136AFB` brand blue, light theme default, no gradient text, neutral shadows
- `[2026-05-21]` ThemeColors centralised — `c.accent` is the single brand colour entry point for all feature screens
- `[2026-05-21]` Splash screen rewritten to light theme; dialog backgrounds fixed for light mode
- `[2026-05-19]` My Doctors — personal doctor book with favorites, search, specialty filter
- `[2026-05-19]` Appointments — log with Upcoming / Past / Cancelled tabs; status change flow
- `[2026-05-19]` Doctor detail screen — full profile + linked appointments list + add appointment shortcut
- `[2026-05-19]` Appointment detail screen — Mark Completed / Cancel buttons + edit / delete
- `[2026-05-19]` Test Report viewer — upload, category picker (preset + custom), search, detail view with gallery
- `[2026-05-18]` Full Prescription Management system — add, view, edit, delete prescriptions with doctor info
- `[2026-05-18]` Medicine list per prescription — name, dose, frequency (Morning / Afternoon / Evening / Night), duration, instructions
- `[2026-05-18]` Multi-page image upload — stored as `image_urls TEXT[]` in Supabase Storage (private bucket, signed URLs)
- `[2026-05-18]` Active / Expired medicine status — auto-detected from `start_date + duration_days` vs today
- `[2026-05-18]` Refill Soon alert — warns when a medicine is within 3 days of running out
- `[2026-05-18]` Medicine reminders — local push notifications at 8 AM / 1 PM / 6 PM / 10 PM
- `[2026-05-18]` Allergy cross-check — warns if any medicine name matches user's saved allergies
- `[2026-05-18]` PDF export & share — formatted A4 prescription PDF
- `[2026-05-03]` Fully editable user profile connected to Supabase
- `[2026-05-03]` Medical Identity card — Blood Group, Age, Height, Weight + auto-calculated BMI
- `[2026-05-03]` Health Records — Allergies & Conditions, Ongoing Treatment
- `[2026-05-03]` Emergency Contact (ICE) card with call button
- `[2026-05-03]` `health_profiles` Supabase table with RLS policies
- `[2026-05-02]` Home dashboard — time-aware greeting, Quick Actions grid, bottom nav bar
- `[2026-04-30]` Authentication screens — Login, Sign-up, Forgot Password
- `[2026-04-30]` Supabase Auth integration — signUp, signIn, signOut, resetPassword
- `[2026-04-30]` `profiles` table with auto-create trigger on user registration
- Dark/light theme system with `ThemeColors` extension on `BuildContext`
- Profile photo upload to Supabase Storage (`avatars` private bucket, signed URLs)
- Bangla (বাংলা) language support via `S.of(context)` localisation
- Mouse-drag scroll on Flutter Web via custom `ScrollBehavior`

---

## About TreatTrace

TreatTrace is a healthcare companion mobile app designed to help users:

- **Track prescriptions** — doctor info, medicines, doses, frequencies, and images
- **Get reminded** — local notifications at the right time for each dose
- **Stay safe** — allergy cross-check catches conflicts before they happen
- **Log test results** — upload lab reports with images, category, and prescription links
- **Manage their doctors** — personal address book with contact info, fees, and favorites
- **Log appointments** — track visits with status management (scheduled / completed / cancelled)
- **Manage their medical profile** — vitals, BMI, emergency contacts

Built as a portfolio project demonstrating real-world Flutter + Supabase integration with production-level architecture.

---

## Completed Features

### Authentication
- Email + password sign-up and login
- Password strength indicator (Weak / Fair / Good / Strong)
- Forgot Password → email reset link flow
- Real-time form validation with user-friendly error messages
- Keep-me-logged-in toggle — auto session persistence across restarts

### Home Dashboard
- Time-aware personalised greeting (*Good morning / afternoon / evening, Name*)
- Daily health tip banner
- **Quick Actions 2×2 grid** — Prescriptions, Test Reports, My Doctors, Appointments
- Custom bottom navigation bar with profile avatar

### User Profile (Full CRUD)
- **Medical Identity Card** — Blood Group, Age, Height (ft + in), Weight, auto-calculated BMI
- BMI Status badge (Underweight / Normal Weight / Overweight / Obese)
- **Health Records** — Allergies & Conditions, Ongoing Treatment
- **Emergency Contact (ICE)** — name + phone with one-tap call button
- **Profile Photo** — upload from camera or gallery to Supabase Storage; shown in bottom nav
- **App Settings** — Dark Mode toggle, Language selector (English / বাংলা), Logout
- All data persisted in Supabase with Row Level Security

### Prescription Management
- Add / Edit / Delete prescriptions
- Doctor info — Name, Specialty, Hospital / Clinic, Phone
- Diagnosis and general notes
- Multi-page image upload (camera + gallery) stored as URL array
- Swipeable gallery in detail view with page counter and full-screen pinch-to-zoom
- Medicine list — name, dose, Morning / Afternoon / Evening / Night toggles, duration, instructions, start date
- **Active / Expired** status — auto-detected from start date + duration vs today
- **Refill Soon** alert — triggers within 3 days of running out
- **Medicine reminders** — daily alarms at 8 AM, 1 PM, 6 PM, 10 PM; persists across reboots
- **Allergy cross-check** — prominent warning if medicine matches user's saved allergies
- **PDF export & share** — formatted A4 PDF with TreatTrace branding
- **Search** by doctor name or diagnosis; **Tab filter** — All / Active / Expired

### Test Report Viewer
- Add / Edit / Delete lab/test reports
- Category picker — preset types (Blood Test, Urine Test, X-Ray, MRI/CT Scan, Ultrasound, ECG/EEG, Pathology, Other) + custom user-defined categories
- Test date, referring doctor, lab/hospital, notes
- Multi-image upload per report (camera + gallery)
- Optional prescription link
- Search by test name, doctor, hospital, category
- Category filter chips on list screen

### My Doctors (Personal Doctor Book)
- Add / Edit / Delete doctor records
- Fields: name, specialty, hospital, chamber address, phone, consultation fee, notes
- Favorites toggle (heart icon) — favorited doctors appear first
- Search by name, specialty, hospital
- Specialty filter chips
- Doctor detail screen shows all appointments for that doctor

### Appointments
- Add / Edit / Delete appointments
- Doctor picker from saved doctor list (pre-fills from doctor detail screen)
- Date picker, time (optional text field), visit reason, notes
- Optional prescription link
- Status management: **Scheduled → Mark Completed / Cancel Appointment**
- 3-tab list view: **Upcoming** / **Past** / **Cancelled**
- `doctor_name_snapshot` preserves doctor name if doctor record is deleted later
- Search across all tabs

### Theme & Localisation
- Full dark + light theme via `ThemeColors` extension on `BuildContext`; **light is the default**
- Single brand blue `#136AFB` in light mode; purple `#8B5CF6` in dark mode — both via `c.accent`
- All UI strings in English + Bangla via `S.of(context)` — switchable at runtime

---

## In Progress / Upcoming

- [ ] Offline-first caching for health records
- [ ] Biometric login (fingerprint / Face ID)
- [ ] Calendar view for appointments
- [ ] Medicine dose tracker (mark taken / skipped)

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **Backend & Auth** | Supabase (PostgreSQL + Auth + Storage + RLS) |
| **Typography** | Poppins (via `google_fonts`) |
| **Animations** | `flutter_animate` |
| **Notifications** | `flutter_local_notifications` + `timezone` |
| **PDF** | `pdf` + `printing` |
| **State** | `StatefulWidget` + `setState` |
| **Architecture** | Feature-first folder structure |

### Key Dependencies

```yaml
supabase_flutter: ^2.5.6              # Auth, database, storage, session
google_fonts: ^6.2.1                  # Poppins typography
flutter_animate: ^4.5.0               # Smooth UI animations
image_picker: ^1.1.2                  # Camera + gallery photo selection
flutter_local_notifications: ^18.0.1  # Medicine dose reminders
timezone: ^0.9.4                      # Scheduled notification time zones
pdf: ^3.11.1                          # PDF generation
printing: ^5.13.2                     # PDF share / print
```

---

## Project Structure

```
lib/
├── main.dart
├── core/
│   ├── config/
│   │   └── supabase_config.dart
│   ├── constants/
│   │   └── app_colors.dart              # DarkColors + AppColors palettes
│   ├── l10n/
│   │   └── app_strings.dart             # English + Bangla string map
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── profile_service.dart
│   │   └── reminder_service.dart
│   └── theme/
│       └── theme_colors.dart            # ThemeColors BuildContext extension
├── features/
│   ├── auth/
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       ├── signup_screen.dart
│   │       └── forgot_password_screen.dart
│   ├── home/
│   │   └── screens/
│   │       └── home_screen.dart
│   ├── prescription/
│   │   ├── models/
│   │   │   ├── prescription.dart
│   │   │   └── prescription_medicine.dart
│   │   ├── screens/
│   │   │   ├── prescriptions_screen.dart
│   │   │   ├── add_edit_prescription_screen.dart
│   │   │   └── prescription_detail_screen.dart
│   │   └── services/
│   │       └── prescription_service.dart
│   ├── test_report/
│   │   ├── models/
│   │   │   └── lab_report.dart
│   │   ├── screens/
│   │   │   ├── lab_reports_screen.dart
│   │   │   ├── add_edit_lab_report_screen.dart
│   │   │   └── lab_report_detail_screen.dart
│   │   └── services/
│   │       └── lab_report_service.dart
│   ├── doctor/
│   │   ├── models/
│   │   │   └── doctor.dart
│   │   ├── screens/
│   │   │   ├── doctors_screen.dart
│   │   │   ├── add_edit_doctor_screen.dart
│   │   │   └── doctor_detail_screen.dart
│   │   └── services/
│   │       └── doctor_service.dart
│   ├── appointment/
│   │   ├── models/
│   │   │   └── appointment.dart
│   │   ├── screens/
│   │   │   ├── appointments_screen.dart
│   │   │   ├── add_edit_appointment_screen.dart
│   │   │   └── appointment_detail_screen.dart
│   │   └── services/
│   │       └── appointment_service.dart
│   └── profile/
│       ├── models/
│       │   └── health_profile.dart
│       └── screens/
│           ├── profile_screen.dart
│           └── edit_profile_screen.dart
database/
├── migrations/
│   ├── 2026_05_19_v06_lab_reports.sql
│   └── 2026_05_19_v07_doctors_and_appointments.sql
└── treattrace_schema.sql              # Full consolidated schema (v0.7)
android/
└── app/src/main/AndroidManifest.xml   # Notification + boot permissions
```

---

## Installation

### Prerequisites
- Flutter SDK >= 3.x
- A [Supabase](https://supabase.com) project (free tier works)

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/TreatTraceV1.git
cd TreatTraceV1
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Supabase

Open `lib/core/config/supabase_config.dart` and replace the placeholders:

```dart
static const String supabaseUrl     = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

### 4. Run the database setup

In your Supabase dashboard → **SQL Editor**, run the full consolidated schema:

```
database/treattrace_schema.sql
```

Or apply only the latest migrations:

```
database/migrations/2026_05_19_v06_lab_reports.sql
database/migrations/2026_05_19_v07_doctors_and_appointments.sql
```

### 5. Create Supabase Storage buckets

| Bucket | Visibility | Purpose |
|---|---|---|
| `avatars` | Private | User profile photos |
| `prescriptions` | Private | Prescription page images |
| `lab_reports` | Private | Test report images |

### 6. Run the app

```bash
flutter run
```

---

## Usage

| Step | Action |
|---|---|
| 1 | Sign up with name, email, and password |
| 2 | Log in — session is remembered automatically |
| 3 | Tap **My Profile** → fill in your health details and allergies |
| 4 | Tap **Prescriptions** → **+** to add a prescription with doctor info and medicines |
| 5 | Tap **Test Reports** → **+** to upload a lab result with category and images |
| 6 | Tap **My Doctors** → **+** to save a doctor's contact and chamber details |
| 7 | Tap **Appointments** → **+** to log a visit; pick a doctor from your book |
| 8 | From a doctor's detail screen, tap **Add** to log an appointment pre-filled with that doctor |
| 9 | Open any appointment → **Mark as Completed** or **Cancel Appointment** |

---

## Database Schema

### `public.profiles`
Auto-created for every new user via a Supabase trigger.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | FK → `auth.users` |
| `full_name` | TEXT | Set at sign-up |
| `email` | TEXT | |
| `phone` | TEXT | Optional |
| `avatar_url` | TEXT | Signed Storage URL |
| `created_at` | TIMESTAMPTZ | |

### `public.health_profiles`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | FK → `auth.users` |
| `blood_group` | TEXT | One of 8 standard types |
| `age` | INTEGER | |
| `height_cm` | DECIMAL | Stored in cm; displayed as ft + in |
| `weight_kg` | DECIMAL | |
| `allergies` | TEXT | Used by allergy cross-check |
| `ongoing_treatment` | TEXT | |
| `emergency_name` | TEXT | ICE contact |
| `emergency_phone` | TEXT | |

> **BMI** is never stored — always computed on the client from `height_cm` and `weight_kg`.

### `public.prescriptions`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → `auth.users` |
| `doctor_name` | TEXT | |
| `doctor_specialty` | TEXT | |
| `doctor_hospital` | TEXT | |
| `doctor_phone` | TEXT | |
| `diagnosis` | TEXT | |
| `prescription_date` | DATE | |
| `image_urls` | TEXT[] | Array of signed Storage URLs |
| `notes` | TEXT | |

### `public.prescription_medicines`

| Column | Type | Notes |
|---|---|---|
| `prescription_id` | UUID | FK → `prescriptions` (cascade delete) |
| `medicine_name` | TEXT | |
| `dose` | TEXT | e.g. "500mg" |
| `morning / afternoon / evening / night` | BOOLEAN | Dose slot flags |
| `duration_days` | INTEGER | |
| `start_date` | DATE | For active/expired calculation |

### `public.lab_reports`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → `auth.users` |
| `test_name` | TEXT | Required |
| `category` | TEXT | Preset or custom |
| `test_date` | DATE | |
| `doctor_name` | TEXT | |
| `hospital` | TEXT | |
| `image_urls` | TEXT[] | Array of signed Storage URLs |
| `notes` | TEXT | |
| `prescription_id` | UUID | FK → `prescriptions` (SET NULL on delete) |

### `public.doctors`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → `auth.users` |
| `name` | TEXT | Required (stored without "Dr." prefix) |
| `specialty` | TEXT | |
| `hospital` | TEXT | |
| `chamber_address` | TEXT | |
| `phone` | TEXT | |
| `fee` | TEXT | Free text, e.g. "৳ 800" |
| `notes` | TEXT | |
| `is_favorite` | BOOLEAN | Default false |

### `public.appointments`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → `auth.users` |
| `doctor_id` | UUID | FK → `doctors` (SET NULL on delete) |
| `doctor_name_snapshot` | TEXT | Doctor name frozen at booking time |
| `appointment_date` | DATE | Required |
| `appointment_time` | TEXT | Optional, e.g. "10:30 AM" |
| `visit_reason` | TEXT | |
| `status` | TEXT | `scheduled` / `completed` / `cancelled` |
| `notes` | TEXT | |
| `prescription_id` | UUID | FK → `prescriptions` (SET NULL on delete) |

---

## Design System

| Token | Light mode | Dark mode |
|---|---|---|
| **Brand / Accent** | `#136AFB` (DocTime blue) | `#8B5CF6` (purple) |
| **Success / Active** | `#10B981` (green) | `#10B981` |
| **Warning / Refill** | `#F59E0B` (amber) | `#F59E0B` |
| **Error / Danger** | `#EF4444` (red) | `#EF4444` |
| **Background** | `#F0F4F8` | `#050508` |
| **Card** | `#FFFFFF` | `#0F0F18` |
| **Border** | `#CBD5E1` | `#1E1E2E` |
| **Card Radius** | 16 – 24 px | 16 – 24 px |
| **Body Font** | Poppins (via `google_fonts`) | Poppins |

**Colour usage rules:**
- `c.accent` — single brand colour for all interactive elements (FAB, tab indicator, search icon, card bar, badges, chips)
- `c.green` — semantic only: Active status, success states
- `c.amber` — semantic only: Refill Soon alerts, warning states
- `c.red` — semantic only: Error, Cancelled, Allergy warnings, Delete actions

---

## Future Improvements

- Offline-first caching for health records
- Biometric login (fingerprint / Face ID)
- Calendar view for appointments
- Medicine dose tracker (mark taken / skipped)
- Cloud backup & export

---

## Authors / Contributors

- **MD Almas Ali**
- **Tasmina Rahman Chowdhury**
- **Sharon Sahrin Mim**

Built as a collaborative project. Contributions and feedback are welcome.

---

<div align="center">

*TreatTrace — Your health, our priority.*

</div>
