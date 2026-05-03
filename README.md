<div align="center">

# 🏥 TreatTrace

### A modern healthcare companion app built with Flutter & Supabase

*Find doctors · Track prescriptions · Manage your health — all in one place.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## 🚀 Current Project Status

| Item | Detail |
|---|---|
| **Stage** | 🟡 v0.3 — Active Development |
| **UI Status** | ✅ Auth + Home + Profile — Complete |
| **Backend Status** | ✅ Auth CRUD · ✅ Profile CRUD · 🔲 Appointments |
| **Platform** | Android · iOS |
| **Last Updated** | 2026-05-03 |

---

## 🆕 Latest Updates

- `[2026-05-03]` Fully editable user profile system connected to Supabase
- `[2026-05-03]` Medical Identity card — Blood Group, Age, Height, Weight + auto-calculated BMI
- `[2026-05-03]` Health Records — Allergies & Conditions, Ongoing Treatment (stored in DB)
- `[2026-05-03]` Emergency Contact (ICE) card with call button
- `[2026-05-03]` Edit Profile screen with field validation + live BMI preview
- `[2026-05-03]` Empty states for new users — no hardcoded placeholder values
- `[2026-05-03]` `health_profiles` Supabase table with RLS policies

---

## 📜 Update History

- `[2026-05-02]` Home dashboard UI — Deep Blue header, time-aware greeting, Quick Actions 2×2 grid
- `[2026-05-02]` Quick Actions — Prescription (Manual/File), Test Report, Ongoing Treatment, My Health
- `[2026-05-02]` Custom bottom bar — Last Prescribed · Search · My Profile navigation
- `[2026-04-30]` Authentication screens — Login, Sign-up, Forgot Password
- `[2026-04-30]` Password strength indicator, real-time validation, session persistence
- `[2026-04-30]` Supabase Auth integration — signUp, signIn, signOut, resetPassword
- `[2026-04-30]` `profiles` table with auto-create trigger on user registration
- `[2026-04-30]` Initial Flutter project setup — Supabase config, theme, fonts, routing

---

## 📖 About TreatTrace

TreatTrace is a healthcare companion mobile app designed to help users:

- **Track health records** — prescriptions, test reports, allergies, and treatments
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
- Auto session persistence — user stays logged in across app restarts

### 🏠 Home Dashboard
- Time-aware personalised greeting (*Good morning / afternoon / evening, Name*)
- Daily health tip banner
- **Quick Actions 2×2 grid:**
  - Prescription — Manual entry + File upload sub-options
  - Test Report — File upload
  - Ongoing Treatment
  - My Health
- Custom bottom navigation bar with search and profile access

### 👤 User Profile (Full CRUD)
- **Medical Identity Card**
  - Blood Group (dropdown — A+, A−, B+, B−, AB+, AB−, O+, O−)
  - Age, Height (ft + in), Weight (kg)
  - BMI — **auto-calculated** from height & weight, never manually entered
  - BMI Status badge (Underweight / Normal Weight / Overweight / Obese)
- **Health Records**
  - Allergies & Conditions (free text)
  - Ongoing Treatment plan (free text)
- **Emergency Contact (ICE)**
  - Contact name + phone with one-tap call button
- **App Settings**
  - Dark Mode toggle
  - Language selector (English / বাংলা)
  - Logout with confirmation dialog
- New users see clean empty states — zero hardcoded placeholder values
- All data persisted to Supabase with Row Level Security

---

## 🔲 In Progress / Upcoming

- [ ] Doctor search and listing
- [ ] Appointment booking flow
- [ ] Prescription upload (camera + file)
- [ ] Test report viewer
- [ ] Notification system
- [ ] Dark mode implementation (toggle is wired, theme not yet applied)
- [ ] Profile photo upload

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **Backend & Auth** | Supabase (PostgreSQL + Auth + RLS) |
| **Typography** | DM Serif Display · DM Sans · Poppins (via `google_fonts`) |
| **Animations** | `flutter_animate` |
| **State** | `StatefulWidget` + `setState` |
| **Architecture** | Feature-first folder structure |

### Key Dependencies

```yaml
supabase_flutter: ^2.5.6   # Auth, database, session management
google_fonts: ^6.2.1        # DM Serif Display, DM Sans, Poppins
flutter_animate: ^4.5.0     # Smooth UI animations
```

---

## 🗂 Project Structure

```
lib/
├── main.dart                        # App entry, Supabase init, AuthGate routing
├── core/
│   ├── config/
│   │   └── supabase_config.dart     # Supabase URL + anon key
│   ├── constants/
│   │   ├── app_colors.dart          # Global colour palette
│   │   └── app_text_styles.dart     # Typography styles
│   ├── services/
│   │   ├── auth_service.dart        # Supabase Auth wrapper
│   │   └── profile_service.dart     # Health profile CRUD
│   └── utils/
│       └── validators.dart          # Form field validators
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   └── forgot_password_screen.dart
│   │   └── widgets/
│   │       ├── auth_button.dart
│   │       ├── auth_text_field.dart
│   │       └── medical_header.dart
│   ├── home/
│   │   └── screens/
│   │       └── home_screen.dart
│   └── profile/
│       ├── models/
│       │   └── health_profile.dart  # Data model (pure Dart)
│       └── screens/
│           ├── profile_screen.dart
│           └── edit_profile_screen.dart
└── shared/
    └── widgets/                     # Cross-feature reusable widgets
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

In your Supabase dashboard → **SQL Editor**, paste and run the single consolidated schema file:

```
database/treattrace_schema.sql    # complete schema — all tables, triggers, RLS
```

### 5. Run the app

```bash
flutter run
```

---

## 📱 Usage

| Step | Action |
|---|---|
| 1 | Sign up with name, email, and password |
| 2 | Log in — session is remembered automatically |
| 3 | Explore the Home dashboard Quick Actions |
| 4 | Tap **My Profile** → fill in your health details |
| 5 | Tap the ✏️ edit icon to update any information |

---

## 🗄 Database Schema

### `public.profiles`
Auto-created for every new user via a Supabase trigger.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | FK → `auth.users` |
| `full_name` | TEXT | Set at sign-up |
| `email` | TEXT | |
| `created_at` | TIMESTAMPTZ | |

### `public.health_profiles`
Created on first profile save. All health fields are nullable — new users start blank.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | FK → `auth.users` |
| `blood_group` | TEXT | One of 8 standard types |
| `age` | INTEGER | |
| `height_cm` | DECIMAL | Stored in cm; displayed as ft + in |
| `weight_kg` | DECIMAL | |
| `allergies` | TEXT | |
| `ongoing_treatment` | TEXT | |
| `emergency_name` | TEXT | ICE contact |
| `emergency_phone` | TEXT | |
| `updated_at` | TIMESTAMPTZ | Auto-managed by trigger |

> **BMI** is never stored — it is always computed on the client from `height_cm` and `weight_kg`.

---

## 🎨 Design System

| Token | Value |
|---|---|
| Primary (Deep Blue) | `#2563EB` |
| Background | `#EEF2FF` |
| Surface | `#FFFFFF` |
| Heading Font | DM Serif Display |
| Body Font | DM Sans |
| Card Radius | 20 – 24 px |

---

## 🔮 Future Improvements

- Doctor search with filtering (specialty, location, rating)
- Real-time appointment booking and calendar integration
- Push notifications for medication reminders
- Prescription and lab report document viewer
- Full dark mode theme
- Profile photo upload via Supabase Storage
- Multi-language support (Bangla UI strings)
- Offline-first caching for health records

---

## 👨‍💻 Author

**MD Almas Ali**
Built as a portfolio project — contributions and feedback welcome.

---

<div align="center">

*TreatTrace — Your health, our priority.*

</div>
