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
| **Stage** | v0.13 — Active Development |
| **UI Status** | Auth · Animated Splash · Home · Profile · Prescriptions · Test Reports · Doctors · Appointments · Doctor Portal · Username System |
| **Backend Status** | Auth · Profile (+ username) · Prescriptions + Medicines · Test Reports (doctor-linked) · Doctors · Appointments · Doctor–Patient Links |
| **Platform** | Android · iOS |
| **Last Updated** | 2026-05-25 |

---

## Latest Updates (2026-05-25)

**v0.13 — Username System + Signup Fix + Codebase Cleanup**

- **Unique username for all users** — every account (patient & doctor) has a `@username`:
  - `profiles.username` column: unique, format `[a-z0-9_]`, 3–20 characters, nullable (existing accounts)
  - `check_username_available(uname)` Supabase RPC (SECURITY DEFINER) — bypasses RLS for safe availability check
  - `search_patient_by_query` RPC updated to return `username` in results
- **Signup screen** — username field added with 500 ms real-time availability check (green ✓ / red ✗ indicator); `FilteringTextInputFormatter` restricts input to allowed characters; username saved to `profiles` via auth metadata trigger
- **Profile screen** — `@username` shown below email in the profile header; "Change Username" tile added to Account Settings with in-dialog availability check
- **Search Patient screen** — hint text and no-result message updated to mention @username; result card shows `@username` below phone
- **Signup "Failed to fetch" fix** — SMTP delay (3–4 s) caused the Flutter client to timeout before the server responded, showing "Failed to fetch"; catch block now detects network errors and shows a "Check your email" confirmation dialog instead of retrying (which previously invalidated the OTP token)
- **RLS circular dependency fix** — previous "Doctor profiles readable" policy queried `doctor_verifications`, which had a policy querying `profiles` → infinite recursion → `fetchProfile()` threw → `_role` stayed null → role picker reappeared after restart; fixed by using `USING (role = 'doctor')` with no cross-table joins
- **Removed `public_doctors`** — dropped dead `public_doctors` Supabase table (12 stale rows never read by the app); deleted `PublicDoctor` model, `PublicDoctorService`, `DiscoverDoctorsScreen`; removed all references from `global_search_screen`, `doctors_screen`, `linked_doctors_screen`
- `dart analyze` passes clean across all changed files

---

## v0.12 Updates (2026-05-24)

**v0.12 — Doctor Prescription Images + Linked Doctor Picker + Bug Fixes**

- **Doctor prescription image upload** — doctor-written prescriptions now support image attachments (camera + gallery); images stored in Supabase Storage `prescriptions` bucket and shown in prescription detail
- **Full timing labels in doctor prescription** — dose slot labels use full words (Morning / Afternoon / Evening / Night) instead of icon-only, matching the patient-side prescription form
- **Patient image visibility** — patients can now view prescription images written by their linked doctor; previously images were visible only to the writer
- **Linked doctor picker in prescription form** — "Doctor Name" field in patient's Add/Edit Prescription now shows autocomplete suggestions from accepted linked doctors (fetched from `doctor_patient_links`); selecting a doctor auto-fills name, specialty, and hospital from their verified `doctor_verifications` record
- **Linked doctor picker in test report form** — same autocomplete behaviour in patient's Add/Edit Test Report; selecting a doctor fills name and stores `ordered_by_doctor_id`
- **New medicine added at top of list** — in the doctor prescription screen, newly added medicines appear at position 0 (top of list) instead of appended at the bottom
- **Doctor credentials edit** — fixed RLS policy that blocked updates to `doctor_verifications`; fixed `_saving` state not resetting after save, preventing the save button from re-enabling
- **Test report bug fixes** — MIME type detection corrected for HEIC/WebP images; camera permission granted flow fixed; `test_date` now required before saving; doctor portal image upload error resolved
- `dart analyze` passes clean across all changed files

---

## v0.11 Updates (2026-05-23)

**v0.11 — Doctor-Linked Test Reports + Full Doctor View Access**

- **Test Report renamed throughout doctor portal** — "Lab Report / Lab Order" renamed to "Test Report" across all doctor-facing screens (`DoctorLabReportScreen`, `PatientDetailScreen` section header)
- **Doctor → Patient Detail: all test reports tappable** — any test report in a patient's file now opens a full read-only detail view (category, date, doctor name, notes, uploaded images); previously only the edit button was shown for own reports with no way to view others
- **Edit access scoped by `ordered_by_doctor_id`** — green ✏️ edit button appears only on reports where `ordered_by_doctor_id == currentDoctorId`; all other reports are view-only with full content visible
- **Patient → Add Test Report: test name field removed** — category now serves as the report identifier; `test_name` is auto-derived from the selected category on save; custom category dialog retained for non-preset types
- **Doctor autocomplete in patient's test report form** — "Doctor Name" field now shows suggestions from the patient's accepted linked doctors (fetched from `doctor_patient_links`); selecting a doctor stores their UUID in `ordered_by_doctor_id`, granting them edit access to that report from their patient view
- **`ordered_by_doctor_id` settable by patients** — patients can now link one of their My Doctors to a self-uploaded test report; the linked doctor immediately sees the edit button on that report in the patient detail screen
- **RLS confirmed** — `doctor_reads_patient_labs` SELECT policy already covers doctors viewing linked patient reports; `doctor_updates_own_lab_order` UPDATE policy enforces the edit scope
- `dart analyze` passes clean across all changed files

**v0.10 — Plus Jakarta Sans Font + Animated Splash Screen**

- **Bundled font** — Plus Jakarta Sans variable TTF added to `assets/fonts/`; registered at weights 400/500/600/700 in `pubspec.yaml`; loads instantly offline with no network dependency
- **App theme migrated** — `app_theme.dart` fully rewritten to use `fontFamily: 'PlusJakartaSans'`; removed all `GoogleFonts.poppins(...)` calls from the theme layer; both light and dark `ThemeData` now apply Plus Jakarta Sans as the default
- **Animated splash screen** — replaced the static image splash with a "Clarity Reveal" sequence:
  - Location-pin scales in from 0.6× → 1.0× with `easeOutBack` over 600 ms
  - White ECG/heartbeat line draws itself left→right inside the pin over 700 ms
  - "TreatTrace" wordmark revealed by an expanding `ClipRect` wipe left→right over 750 ms ("Treat" in `#136AFB`, "Trace" in `#0B3D8C`)
  - Tagline "Your health, traced." fades in softly after the wordmark
  - Brand-blue circular progress indicator at bottom while the app finishes initialising
- **Minimum display guarantee** — `AuthGate` enforces a 2 500 ms floor so the full animation always plays even when the Supabase session check resolves instantly
- Role-loading screen (`_RoleAwareRouter`) now shows a plain white + spinner rather than restarting the splash animation
- `flutter analyze` passes clean

---

## v0.9 Updates (2026-05-22)

**v0.9 — Doctor Portal + Role-Based Routing**

- **Role Selection screen** — shown on first login; user picks *Patient* or *Doctor*; role saved to `profiles.role` in Supabase; never shown again once set
- **Doctor Home screen** — dedicated dashboard for doctor-role users with time-aware greeting, avatar, quick actions, and bottom nav
- **My Patients** — list of patients who have linked themselves to this doctor; tap to view their full health profile
- **Patient Detail** — doctors can view a patient's prescriptions, appointments, and health records from within the doctor portal
- **Search Patient** — doctors search for any registered patient by name/email and send a link request
- **Linked Doctors** — patient-side screen showing all doctors they are linked to; unlink option
- **Doctor Write Prescription** — doctor creates a prescription directly into a patient's account
- **Doctor Add Appointment** — doctor logs an appointment into a patient's timeline
- `doctor_patient_links` Supabase table with RLS; patients see only their own links, doctors see only their linked patients
- `AuthGate` → `_RoleAwareRouter`: role fetched after login; routes to `HomeScreen` (patient) or `DoctorHomeScreen` (doctor); unset role triggers `RoleSelectionScreen`

**App Branding — Launcher Icons + In-App Logo**

- `flutter_launcher_icons: ^0.14.4` added to dev_dependencies
- **Android launcher icon** — standard `ic_launcher.png` generated in all density buckets (mdpi → xxxhdpi); adaptive icon (`mipmap-anydpi-v26`) with `#136AFB` solid background + transparent foreground pin
- **iOS launcher icon** — all 22 required sizes generated in `AppIcon.appiconset`
- **Web icons** — `Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png` generated; `web/manifest.json` updated with `#136AFB` background and theme colour
- **App name corrected**: `AndroidManifest.xml` label `treat_trace` → `TreatTrace`; iOS `Info.plist` `CFBundleDisplayName` `Treat Trace` → `TreatTrace` and `CFBundleName` `treat_trace` → `TreatTrace`
- **Splash screen** (`_SplashScreen` in `main.dart`) — `Icons.local_hospital_rounded` replaced with `Image.asset('Logo/treattrace_icon_1024.png')`; removed hard-coded `const` to allow asset image
- **Login screen** (`_LogoBlock`) — hospital icon replaced with actual logo image
- **Signup screen header** (`MedicalHeader`) — hospital icon replaced with actual logo image
- `Logo/` directory registered as a Flutter asset in `pubspec.yaml`

---

## Previous Updates (2026-05-21)

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

- `[2026-05-25]` Username system — `profiles.username` column (unique, `[a-z0-9_]`, 3–20 chars); `check_username_available` RPC; signup field with real-time check; `@username` shown in profile header and account settings change dialog
- `[2026-05-25]` Signup "Failed to fetch" fix — network timeout on SMTP delay now shows confirmation dialog instead of error, preventing double-request OTP invalidation
- `[2026-05-25]` RLS circular dependency fix — `profiles` policy no longer cross-references `doctor_verifications`; role picker no longer reappears after restart
- `[2026-05-25]` Removed `public_doctors` table and all Discover Doctors code (`PublicDoctor` model, `PublicDoctorService`, `DiscoverDoctorsScreen`) — feature was dead (code read `doctor_verifications`, not `public_doctors`)
- `[2026-05-25]` Search Patient screen — hint text and result card updated to show `@username`
- `[2026-05-24]` Doctor prescription image upload — camera + gallery; images stored in Supabase Storage and shown in detail view
- `[2026-05-24]` Full timing labels (Morning / Afternoon / Evening / Night) in doctor prescription form
- `[2026-05-24]` Patient can view images on doctor-written prescriptions
- `[2026-05-24]` Linked doctor picker in prescription and test report forms — autocomplete from accepted `doctor_patient_links`; auto-fills name, specialty, hospital
- `[2026-05-24]` New medicine added at top of list in doctor prescription screen
- `[2026-05-24]` Doctor credentials edit — RLS policy fix + `_saving` state reset fix
- `[2026-05-24]` Test report bugs fixed — MIME type, camera permission, `test_date` required, doctor portal upload error
- `[2026-05-23]` Doctor-linked test reports — patient can link a doctor from their accepted list to a test report; doctor gains edit access via `ordered_by_doctor_id`
- `[2026-05-23]` Doctor patient view: all test reports tappable with full read-only detail (images, notes); edit button shown only for own reports
- `[2026-05-23]` Test name field removed from patient add/edit form; category auto-used as test name
- `[2026-05-23]` "Lab Report / Lab Order" renamed to "Test Report" throughout doctor portal
- `[2026-05-23]` Plus Jakarta Sans bundled font — variable TTF in `assets/fonts/`; theme fully migrated; 400/500/600/700 weights registered
- `[2026-05-23]` Animated "Clarity Reveal" splash — pin scale-in, ECG heartbeat draw, wordmark ClipRect wipe, tagline fade, 2 500 ms minimum display
- `[2026-05-22]` Doctor Portal — dedicated doctor dashboard, My Patients, Patient Detail, Search Patient, Doctor Write Prescription, Doctor Add Appointment
- `[2026-05-22]` Role Selection screen — first-login role picker (Patient / Doctor); routes to correct home screen via `_RoleAwareRouter`
- `[2026-05-22]` `doctor_patient_links` Supabase table — RLS-protected link table connecting doctors and patients
- `[2026-05-22]` App launcher icons generated for Android (standard + adaptive), iOS (22 sizes), and Web (192/512 + maskable) using `flutter_launcher_icons`
- `[2026-05-22]` App name fixed to "TreatTrace" in AndroidManifest and iOS Info.plist (was `treat_trace` / `Treat Trace`)
- `[2026-05-22]` Splash screen, login screen, signup screen — `Icons.local_hospital_rounded` replaced with real TreatTrace logo image
- `[2026-05-22]` `Logo/` registered as Flutter asset so logo PNG is accessible in all screens
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
- Add / Edit / Delete test reports
- Category picker — preset types (Blood Test, Urine Test, X-Ray, MRI/CT Scan, Ultrasound, ECG/EEG, Pathology, Other) + custom user-defined categories; category auto-used as the report name (no separate test name field)
- Test date, doctor name, lab/hospital, notes
- **Doctor autocomplete** — Doctor Name field shows suggestions from the patient's accepted linked doctors; selecting one stores `ordered_by_doctor_id`, granting that doctor edit access from the doctor portal
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

### Doctor Portal (Role: Doctor)
- **Doctor Home** — dedicated dashboard with greeting, quick actions (My Patients), and profile nav
- **My Patients** — list of all patients linked to this doctor; search by name
- **Patient Detail** — full view of a patient's health profile, prescriptions, test reports, and appointments
  - **Test Reports** — all reports are tappable; opens full read-only detail (images, notes, category); green ✏️ edit button only when `ordered_by_doctor_id == doctorId`
  - **Prescriptions** — view all; edit button only when `written_by_doctor_id == doctorId`
- **Order Test** — doctor can create a new test report for a linked patient; doctor info auto-filled from verified credentials
- **Edit Test Report** — doctor can edit any test report they ordered or that the patient linked to them
- **Search Patient** — find any registered patient and establish a doctor–patient link
- **Doctor Write Prescription** — create a prescription directly into a patient's medical record; doctor info auto-filled from `doctor_verifications`
- **Doctor Add Appointment** — log an appointment into a patient's timeline
- Edit access scoped by `ordered_by_doctor_id` (test reports) and `written_by_doctor_id` (prescriptions) at both the UI layer and Supabase RLS layer
- RLS ensures doctors only see their own linked patients; patients see only their own links

### Username System
- Every account (patient & doctor) has a unique `@username`
- Format: lowercase letters, numbers, underscore only (`[a-z0-9_]`); 3–20 characters
- Set at sign-up with real-time availability indicator (500 ms debounce, green ✓ / red ✗)
- Displayed below email on the Profile screen header
- Changeable from Account Settings with in-dialog availability check
- Searchable in Search Patient screen (doctors find patients by @username)
- Stored in `profiles.username` with a unique index; `check_username_available` RPC enforces SECURITY DEFINER to bypass RLS

### Role-Based Routing
- **Role Selection screen** — shown once on first login; user picks Patient or Doctor
- Role saved to `profiles.role`; `_RoleAwareRouter` in `main.dart` routes accordingly
- Patients → `HomeScreen`; Doctors → `DoctorHomeScreen`; no role set → `RoleSelectionScreen`

### App Branding
- **Animated Clarity Reveal splash** — pin scale-in → ECG heartbeat draw → wordmark wipe → tagline fade; guaranteed ≥ 2 500 ms display
- Custom TreatTrace logo on Login screen and Signup screen header
- Launcher icons generated for Android (standard + adaptive `#136AFB` bg), iOS (22 sizes), Web (192/512 + maskable)
- App display name is "TreatTrace" on both Android and iOS home screens

### Typography
- **Plus Jakarta Sans** bundled at `assets/fonts/PlusJakartaSans.ttf` — weights 400, 500, 600, 700 registered in `pubspec.yaml`
- Loads instantly offline; no network font fetch at runtime
- Applied as the default font family across all light and dark theme text styles

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
| **Typography** | Plus Jakarta Sans (bundled TTF, `assets/fonts/`) |
| **Animations** | `flutter_animate` |
| **Notifications** | `flutter_local_notifications` + `timezone` |
| **PDF** | `pdf` + `printing` |
| **State** | `StatefulWidget` + `setState` |
| **Architecture** | Feature-first folder structure |
| **App Icons** | `flutter_launcher_icons` |

### Key Dependencies

```yaml
supabase_flutter: ^2.5.6              # Auth, database, storage, session
google_fonts: ^6.2.1                  # Used by app_text_styles.dart (legacy; theme uses bundled font)
flutter_animate: ^4.5.0               # Smooth UI animations
image_picker: ^1.1.2                  # Camera + gallery photo selection
flutter_local_notifications: ^18.0.1  # Medicine dose reminders
timezone: ^0.9.4                      # Scheduled notification time zones
pdf: ^3.11.1                          # PDF generation
printing: ^5.13.2                     # PDF share / print

# dev
flutter_launcher_icons: ^0.14.4       # Android / iOS / Web launcher icon generation
```

---

## Project Structure

```
Logo/
├── treattrace_icon_1024.png           # Full app icon (blue bg + pin) — launcher + in-app
└── treattrace_foreground_1024.png     # Transparent foreground — Android adaptive icon
lib/
├── main.dart                          # Entry point + _SplashScreen + AuthGate + _RoleAwareRouter
├── core/
│   ├── config/
│   │   └── supabase_config.dart
│   ├── constants/
│   │   └── app_colors.dart
│   ├── l10n/
│   │   └── app_strings.dart           # English + Bangla string map
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── profile_service.dart
│   │   └── reminder_service.dart
│   └── theme/
│       └── theme_colors.dart          # ThemeColors BuildContext extension
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── role_selection_screen.dart   # First-login role picker
│   │   └── widgets/
│   │       ├── medical_header.dart
│   │       └── auth_button.dart
│   ├── home/
│   │   └── screens/
│   │       └── home_screen.dart       # Patient home dashboard
│   ├── doctor_home/                   # Doctor-role portal
│   │   ├── models/
│   │   │   └── doctor_patient_link.dart
│   │   ├── screens/
│   │   │   ├── doctor_home_screen.dart
│   │   │   ├── my_patients_screen.dart
│   │   │   ├── patient_detail_screen.dart
│   │   │   ├── search_patient_screen.dart
│   │   │   ├── linked_doctors_screen.dart
│   │   │   ├── doctor_write_prescription_screen.dart
│   │   │   ├── doctor_lab_report_screen.dart       # Order / edit test reports for patients
│   │   │   └── doctor_add_appointment_screen.dart
│   │   └── services/
│   │       └── doctor_patient_link_service.dart
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
│   │   │   ├── doctors_screen.dart         # Patient's personal doctor book
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
└── treattrace_schema.sql              # Full consolidated schema
android/app/src/main/
├── AndroidManifest.xml                # Label="TreatTrace", notification + boot permissions
└── res/
    ├── mipmap-*/ic_launcher.png       # Standard launcher icons (all densities)
    ├── mipmap-anydpi-v26/             # Adaptive icon XML (API 26+)
    ├── drawable-*/ic_launcher_foreground.png
    └── values/colors.xml              # ic_launcher_background = #136AFB
ios/Runner/Assets.xcassets/
└── AppIcon.appiconset/                # 22 iOS icon sizes
web/
├── icons/                             # Icon-192, Icon-512, maskable variants
└── manifest.json                      # background_color + theme_color = #136AFB
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
| `username` | TEXT | Unique, nullable; format `[a-z0-9_]`, 3–20 chars |
| `role` | TEXT | `patient` / `doctor`; set on first login |
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
| `test_name` | TEXT | Auto-derived from `category` on client |
| `category` | TEXT | Preset or custom; drives the report display name |
| `test_date` | DATE | |
| `doctor_name` | TEXT | |
| `hospital` | TEXT | |
| `image_urls` | TEXT[] | Array of signed Storage URLs |
| `notes` | TEXT | |
| `prescription_id` | UUID | FK → `prescriptions` (SET NULL on delete) |
| `ordered_by_doctor_id` | UUID | FK → `auth.users`; grants edit access to that doctor; set by doctor (Order Test) or by patient (Doctor autocomplete) |

**RLS policies on `lab_reports`:**
- `Users can view own lab_reports` — patient reads their own
- `doctor_reads_patient_labs` — doctor reads any linked patient's reports
- `doctor_updates_own_lab_order` — doctor updates only where `ordered_by_doctor_id = auth.uid()` and link is accepted
- `doctor_inserts_patient_lab` — doctor inserts for a linked patient

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
| **Body Font** | Plus Jakarta Sans (bundled) | Plus Jakarta Sans (bundled) |

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
