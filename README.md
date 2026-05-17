<div align="center">

# 🏥 TreatTrace

### A modern healthcare companion app built with Flutter & Supabase

*Track prescriptions · Manage your health · Stay on top of your medicines — all in one place.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## 🚀 Current Project Status

| Item | Detail |
|---|---|
| **Stage** | 🟡 v0.5 — Active Development |
| **UI Status** | ✅ Auth · ✅ Home · ✅ Profile · ✅ Prescriptions |
| **Backend Status** | ✅ Auth · ✅ Profile · ✅ Prescriptions + Medicines · 🔲 Appointments |
| **Platform** | Android · iOS · Web |
| **Last Updated** | 2026-05-18 |

---

## 🆕 Latest Updates (2026-05-18)

- Full **Prescription Management** system — add, view, edit, delete prescriptions with doctor info
- **Medicine list** per prescription — name, dose, frequency (Morning/Afternoon/Evening/Night), duration, instructions
- **Multi-page image upload** — prescriptions can have 2+ pages; stored as `image_urls TEXT[]` in Supabase Storage (private bucket, signed URLs)
- **Swipeable image gallery** in detail view — page indicator dots, full-screen pinch-to-zoom viewer
- **Active / Expired** medicine status — auto-detected from `start_date + duration_days` vs today
- **Refill Soon** alert — warns when a medicine is within 3 days of running out
- **Medicine reminders** — local push notifications scheduled at 8 AM / 1 PM / 6 PM / 10 PM for each active dose slot
- **Allergy cross-check** — warns if any medicine name matches the user's saved allergies
- **PDF export & share** — generates a formatted A4 prescription PDF with doctor info, medicines, and diagnosis
- **Search & filter** in prescriptions list — search by doctor name / diagnosis; tab filter: All / Active / Expired
- Supabase tables: `prescriptions` + `prescription_medicines` with RLS policies and `updated_at` trigger
- Android permissions wired: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`

---

## 📜 Update History

- `[2026-05-03]` Fully editable user profile system connected to Supabase
- `[2026-05-03]` Medical Identity card — Blood Group, Age, Height, Weight + auto-calculated BMI
- `[2026-05-03]` Health Records — Allergies & Conditions, Ongoing Treatment (stored in DB)
- `[2026-05-03]` Emergency Contact (ICE) card with call button
- `[2026-05-03]` Edit Profile screen with field validation + live BMI preview
- `[2026-05-03]` Empty states for new users — no hardcoded placeholder values
- `[2026-05-03]` `health_profiles` Supabase table with RLS policies
- `[2026-05-02]` Home dashboard UI — Deep Blue header, time-aware greeting, Quick Actions 2×2 grid
- `[2026-05-02]` Custom bottom navigation bar with search and profile access
- `[2026-04-30]` Authentication screens — Login, Sign-up, Forgot Password
- `[2026-04-30]` Password strength indicator, real-time form validation, session persistence
- `[2026-04-30]` Supabase Auth integration — signUp, signIn, signOut, resetPassword
- `[2026-04-30]` `profiles` table with auto-create trigger on user registration
- `[2026-04-30]` Initial Flutter project setup — Supabase config, theme, fonts, routing
- Dark/light theme system with `ThemeColors` extension on `BuildContext`
- Profile photo upload to Supabase Storage (`avatars` private bucket, signed URLs)
- Profile avatar shown in bottom navigation bar
- Phone number field on sign-up + editable in profile
- Bangla (বাংলা) language support via `S.of(context)` localisation
- Mouse-drag scroll on Flutter Web via custom `ScrollBehavior`
- Keep-me-logged-in toggle on login screen

---

## 📖 About TreatTrace

TreatTrace is a healthcare companion mobile app designed to help users:

- **Track prescriptions** — doctor info, medicines, doses, frequencies, and images
- **Get reminded** — local notifications at the right time for each dose
- **Stay safe** — allergy cross-check catches conflicts before they happen
- **Manage their medical profile** — vitals, BMI, emergency contacts
- **Navigate the healthcare system** — find doctors and book appointments *(upcoming)*

Built as a portfolio project demonstrating real-world Flutter + Supabase integration with production-level architecture.

---

## ✅ Completed Features

### 🔐 Authentication
- Email + password sign-up and login
- Password strength indicator (Weak / Fair / Good / Strong)
- Forgot Password → email reset link flow
- Real-time form validation with user-friendly error messages
- Keep-me-logged-in toggle — auto session persistence across restarts

### 🏠 Home Dashboard
- Time-aware personalised greeting (*Good morning / afternoon / evening, Name*)
- Daily health tip banner
- **Quick Actions 2×2 grid** — Prescriptions, Test Report, Ongoing Treatment, My Health
- Prescription shortcut card — taps through to prescriptions list
- Custom bottom navigation bar with profile avatar

### 👤 User Profile (Full CRUD)
- **Medical Identity Card** — Blood Group, Age, Height (ft + in), Weight, auto-calculated BMI
- BMI Status badge (Underweight / Normal Weight / Overweight / Obese)
- **Health Records** — Allergies & Conditions, Ongoing Treatment
- **Emergency Contact (ICE)** — name + phone with one-tap call button
- **Profile Photo** — upload from camera or gallery to Supabase Storage (private bucket, signed URLs); shown in bottom nav
- **App Settings** — Dark Mode toggle, Language selector (English / বাংলা), Logout
- All data persisted in Supabase with Row Level Security

### 💊 Prescription Management (NEW)

#### Core
- Add / Edit / Delete prescriptions
- Doctor info — Name, Specialty, Hospital / Clinic, Phone
- Diagnosis and general notes
- Multi-page image upload (camera + gallery) — up to unlimited pages stored as URL array
- Swipeable gallery in detail view with page counter and full-screen pinch-to-zoom

#### Smart
- Medicine list — name, dose, Morning / Afternoon / Evening / Night toggles, duration (days), instructions, start date
- **Active / Expired** status — auto-detected from start date + duration vs today
- **Refill Soon** alert — triggers within 3 days of the medicine running out
- **Medicine reminders** — `flutter_local_notifications` schedules daily alarms at 8 AM, 1 PM, 6 PM, 10 PM for each active dose slot; persists across reboots
- **Allergy cross-check** — compares medicine names against user's saved allergy string; shows prominent warning banner

#### Nice-to-Have
- **PDF export & share** — formatted A4 PDF with TreatTrace branding, doctor info, medicines table, diagnosis, notes
- **Search** by doctor name or diagnosis (live filter)
- **Tab filter** — All / Active / Expired prescriptions

### 🌗 Theme & Localisation
- Full dark + light theme via `ThemeColors` extension on `BuildContext`
- All UI strings in English + Bangla via `S.of(context)` — switchable at runtime

---

## 🔲 In Progress / Upcoming

- [ ] Doctor search and listing
- [ ] Appointment booking flow
- [ ] Test report viewer (upload + view)
- [ ] Offline-first caching for health records

---

## 🛠 Tech Stack

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
supabase_flutter: ^2.5.6          # Auth, database, storage, session
google_fonts: ^6.2.1              # Poppins typography
flutter_animate: ^4.5.0           # Smooth UI animations
image_picker: ^1.1.2              # Camera + gallery photo selection
flutter_local_notifications: ^18.0.1  # Medicine dose reminders
timezone: ^0.9.4                  # Scheduled notification time zones
pdf: ^3.11.1                      # PDF generation
printing: ^5.13.2                 # PDF share / print
```

---

## 🗂 Project Structure

```
lib/
├── main.dart                              # App entry, Supabase + ReminderService init
├── core/
│   ├── config/
│   │   └── supabase_config.dart
│   ├── constants/
│   │   └── app_colors.dart               # DarkColors palette
│   ├── l10n/
│   │   └── app_strings.dart              # English + Bangla string map
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── profile_service.dart
│   │   └── reminder_service.dart         # flutter_local_notifications singleton
│   └── theme/
│       └── theme_colors.dart             # ThemeColors + BuildContext extension
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
│   │   │   ├── prescription.dart         # Prescription model (imageUrls: List<String>)
│   │   │   └── prescription_medicine.dart
│   │   ├── screens/
│   │   │   ├── prescriptions_screen.dart       # List + search + tab filter
│   │   │   ├── add_edit_prescription_screen.dart  # Form — doctor, images, medicines
│   │   │   └── prescription_detail_screen.dart    # Detail — gallery, PDF, edit/delete
│   │   └── services/
│   │       └── prescription_service.dart  # Supabase CRUD + Storage + allergy check
│   └── profile/
│       ├── models/
│       │   └── health_profile.dart
│       └── screens/
│           ├── profile_screen.dart
│           └── edit_profile_screen.dart
└── shared/
    └── widgets/
database/
├── migrations/
│   └── 2026_05_18_v05_prescriptions.sql  # prescriptions + prescription_medicines
└── treattrace_schema.sql                 # consolidated schema (all versions)
android/
└── app/src/main/AndroidManifest.xml      # Notification + boot permissions
```

---

## ⚙️ Installation

### Prerequisites
- Flutter SDK ≥ 3.x
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

In your Supabase dashboard → **SQL Editor**, run the migrations in order:

```
database/migrations/2026_05_18_v05_prescriptions.sql
```

Or run the full consolidated schema (creates everything from scratch):

```
database/treattrace_schema.sql
```

### 5. Create Supabase Storage buckets

| Bucket | Visibility | Purpose |
|---|---|---|
| `avatars` | Private | User profile photos |
| `prescriptions` | Private | Prescription page images |

### 6. Run the app

```bash
flutter run
```

---

## 📱 Usage

| Step | Action |
|---|---|
| 1 | Sign up with name, email, and password |
| 2 | Log in — session is remembered automatically |
| 3 | Tap **My Profile** → fill in your health details and allergies |
| 4 | Tap **Prescriptions** on the home screen → **+** to add a new prescription |
| 5 | Fill in doctor info, upload prescription pages (camera or gallery) |
| 6 | Add medicines with dose, frequency slots, and duration |
| 7 | Save — reminders are scheduled automatically for active medicines |
| 8 | Tap any prescription → view details, export PDF, or edit |

---

## 🗄 Database Schema

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
Created on first profile save. All health fields are nullable.

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
| `updated_at` | TIMESTAMPTZ | Auto-managed by trigger |

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
| `image_urls` | TEXT[] | Array of signed Storage URLs (multi-page) |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | Auto-managed by trigger |

### `public.prescription_medicines`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `prescription_id` | UUID | FK → `prescriptions` (cascade delete) |
| `medicine_name` | TEXT | |
| `dose` | TEXT | e.g. "500mg" |
| `morning` | BOOLEAN | Dose slot flag |
| `afternoon` | BOOLEAN | |
| `evening` | BOOLEAN | |
| `night` | BOOLEAN | |
| `duration_days` | INTEGER | |
| `instructions` | TEXT | |
| `start_date` | DATE | For active/expired calculation |

---

## 🎨 Design System

| Token | Value |
|---|---|
| Primary Purple | `#7C3AED` |
| Cyan Accent | `#06B6D4` |
| Green | `#22C55E` |
| Amber | `#F59E0B` |
| Red | `#EF4444` |
| Dark Background | `#0F0F23` |
| Light Background | `#F1F5F9` |
| Card Radius | 16 – 24 px |
| Body Font | Poppins (via `google_fonts`) |

---

## 🔮 Future Improvements

- Doctor search with filtering (specialty, location, rating)
- Real-time appointment booking and calendar integration
- Test report document viewer
- Offline-first caching for health records
- Biometric login (fingerprint / Face ID)

---

## 🧑‍💻 Authors / Contributors

- **MD Almas Ali**
- **Tasmina Rahman Chowdhury**
- **Sharon Sahrin Mim**

Built as a collaborative project. Contributions and feedback are welcome.

---

<div align="center">

*TreatTrace — Your health, our priority.*

</div>
