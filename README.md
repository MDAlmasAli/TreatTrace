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
| **Stage** | v0.45 — Active Development |
| **UI Status** | Auth · Animated Splash · Home · Profile · Prescriptions · Test Reports · Doctors · Appointments · Doctor Portal · Username System · Global Doctor Search · Doctor Public Profile Page · Visiting Information Section |
| **Backend Status** | Auth · Profile (+ username) · Prescriptions + Medicines · Test Reports (doctor-linked) · Doctors · Appointments · Doctor–Patient Links · Approved Doctor Directory · Doctor Schedule RLS · Doctor Degree, About · Visiting Fee / Hours / Chamber (direct update, no admin review) |
| **Platform** | Android · iOS · Web (Chrome) |
| **Last Updated** | 2026-05-30 (v0.45) |

---

## Latest Updates (2026-05-30)

**v0.45 — Remove "Order Test" button from doctor patient portal**

- Doctors can no longer order new test reports from a patient's profile
- Removed `_goOrderTest` method, `onOrder` parameter, and "Order Test" button from `patient_detail_screen`
- Removed unused `doctor_test_report_screen.dart` import
- Rationale: test reports are uploaded by patients; if a doctor needs a test they note it in the prescription

**v0.44 — Fix: images opening in new browser tab instead of in-app viewer**

- Gallery thumbnails and fullscreen viewer now always attempt `Image.network` first; only fall back to a doc tile (with external open) if the image fails to load — this also fixes existing reports where the stored URL has no recognisable image extension
- Removed `isImageUrl` pre-check from gallery `itemBuilder`s in `test_report_detail_screen` and `prescription_detail_screen`; inner `GestureDetector` with `HitTestBehavior.opaque` ensures doc-tile taps don't bubble up to the fullscreen handler

**v0.43 — Fix: gallery image on web shown as document tile**

- **Root cause**: `XFile.path` on Flutter Web is a blob URL (e.g. `blob:http://localhost:9533/uuid`) with no file extension. Using `file.path.split('.').last` made the entire blob URL the "extension", stored in the Supabase path, and later extracted by `extFromUrl`, causing `isImageUrl` to return false
- **Fix 1**: `uploadImage` in both `test_report_service` and `prescription_service` now derives extension from `file.name` (which carries the real filename) instead of `file.path`; defaults to `jpg` if name has no extension
- **Fix 2**: `extFromUrl` now validates the extracted token — if it contains `/`, `:`, spaces, or is longer than 8 chars it returns `''`, preventing the blob URL from leaking into the UI as extension text

**v0.42 — Restrict doctor access to test reports (view-only)**

- Doctors can no longer edit test reports — they can only view them
- Removed edit buttons from `patient_detail_screen` and `all_test_reports_screen`
- `TestReportDetailScreen` always opens with `canEdit: false` in doctor context
- Rationale: test reports are uploaded by patients; doctors should not modify them

**v0.41 — Rename: lab report → test report (full codebase + backend)**

- All Dart files, class names, file names, and identifiers renamed from `lab_report` / `LabReport` to `test_report` / `TestReport`
- Supabase DB table renamed `lab_reports` → `test_reports` (indexes, trigger, RLS policies all updated)
- New `test_reports` storage bucket created; new uploads go there; existing files remain accessible via the legacy `lab_reports` bucket
- `_deleteImageByUrl` now handles both buckets transparently
- Migration: `2026_05_30_v17_rename_lab_reports_to_test_reports.sql`

**v0.40 — Search by date (Prescriptions + Test Reports)**

- Calendar button beside the search bar on both screens
- Tapping opens a date picker; selected date shows as a removable chip
- Date filter combines with existing text search and category chips
- Active filter button highlights in the screen's accent colour

**v0.39 — Fix: document upload dialog stuck/hanging on Flutter Web**

- **Root cause**: Browser user-gesture context was lost between `await showDialog()` and `await FilePicker.platform.pickFiles()` — Chrome silently blocks file input clicks not originating from a live user gesture, causing `pickFiles()` to hang forever with no file dialog appearing
- **Fix**: Refactored all four upload screens so each dialog tile's `onTap` directly calls its own async handler (`_pickGallery`, `_pickCamera`, `_pickDocument`) in the same synchronous call stack as the tap, before any `await`; this preserves the browser's user gesture context
- **Affected screens**: `add_edit_prescription_screen`, `add_edit_lab_report_screen`, `doctor_write_prescription_screen`, `doctor_lab_report_screen`
- Removed intermediate `_UploadSource` enum dispatch pattern; replaced with direct callback-per-option approach

**v0.38 — Fix: document upload silently failing on Android**

- **Root cause**: `FilePicker.platform.pickFiles()` was called without `withData: true`; on Android (especially when picking from cloud storage like Google Drive), `file.path` can be a content URI that Supabase's `upload()` cannot access, and `file.bytes` was null because bytes were never loaded
- **Fix 1**: All four upload screens (`add_edit_lab_report`, `add_edit_prescription`, `doctor_lab_report`, `doctor_write_prescription`) now pass `withData: true` to `pickFiles()`, ensuring bytes are always loaded regardless of file source
- **Fix 2**: Both service `uploadDocument()` methods now check `file.bytes` first, fall back to `file.path`, and return null gracefully if neither is available — no more null assertion crashes
- **Fix 3**: `doctor_write_prescription_screen` document case now supports multiple file selection (was only picking the first file)

**v0.37 — File upload support for prescriptions and test reports**

- **PDF / DOC / DOCX upload** — both patients and doctors can now attach documents (not just images) to prescriptions and test reports
- **Upload dialog** extended with a third "Document" option alongside Gallery and Camera; uses `file_picker` to pick PDF, DOC, DOCX from device storage
- **PDF tile in upload card** — non-image attachments render as an amber icon tile (with file extension label) instead of a broken image thumbnail
- **Gallery detail screens updated** — `_ReportGallery`, `_PrescriptionGallery`, and the doctor prescription view now detect file type via `isImageUrl()`:
  - Image URLs → shown in the existing swipeable photo viewer / full-screen viewer
  - Document URLs → shown as a tappable document tile; tap opens the file in the device's default external browser via `url_launcher`
- Shared helper `lib/core/utils/file_utils.dart` (`isImageUrl`, `extFromUrl`) used across all screens for consistent file-type detection

**v0.36 — Linked Prescription is now tappable in Test Report detail**

- **Linked Prescription card is now tappable** — a right-arrow indicator appears on the card; tapping it fetches and opens the full prescription detail
- **Privacy-aware navigation**:
  - Patients open their own prescription in `PrescriptionDetailScreen` (editable as always)
  - Doctors open the prescription in `DoctorPrescriptionViewScreen`; edit is permitted only if `writtenByDoctorId == currentDoctorId`, so a doctor cannot edit another doctor's prescription but can view it
- Applied consistently across all four entry points: patient lab report list, patient global search, doctor patient detail, and doctor all-lab-reports screen

**v0.35 — Fix: test report edit fails with uuid error**

- **Root cause**: `AddEditLabReportScreen` hardcoded `userId: ''` (empty string) in the edit draft; on UPDATE `toMap()` sent `user_id = ""` to PostgreSQL which rejected it as an invalid UUID (code 22P02)
- **Fix 1**: In the edit path, `userId` now carries the existing report's `userId` instead of `""`
- **Fix 2**: `LabReportService.update()` strips `user_id` from the update payload — the owner of a report never changes after creation, so sending it was both unnecessary and risky
- The CREATE path was unaffected because `create()` always overrides `user_id` with `_uid`

**v0.34 — Remove global patient search for doctors**

- **`SearchPatientScreen` deleted** — global patient search is completely removed; doctors can no longer search for arbitrary patients in the system
- **"Add Patient" FAB removed** from My Patients screen — doctors can only view patients who are already linked to them
- **Notification tap** now opens Today's Schedule (appointment-relevant) instead of the removed patient search screen
- Doctors can only access patients they already have a link with

**v0.33 — All Test Reports screen with search & filters**

- **Show More on Test Reports** — Patient Details now shows the 5 most recent test reports; if there are more, a green "Show X more →" button opens the new `AllLabReportsScreen`
- **All Test Reports screen** — loads every test report for the patient with full search and filter support:
  - **Search** by test name or category (live, client-side)
  - **Date filter** chip — filters to a single test date with an inline × to clear
  - **Newest / Oldest sort** toggle
  - **Clear all** link resets both filters at once
  - **Result count** shows `filtered / total` when any filter is active
  - **View** (eye) button always visible; **Edit** (pencil) visible only for reports ordered by this doctor
- View and Edit navigate to existing `LabReportDetailScreen` / `DoctorLabReportScreen` and reload on return

**v0.32 — Remove time field from appointments + show notes in schedule tile**

- **Time field removed** from both patient-facing (`AddEditAppointmentScreen`) and doctor-facing (`DoctorAddAppointmentScreen`) appointment forms; `appointmentTime` is always saved as `null` for new appointments
- **Notes now visible on schedule tile** — appointment `notes` text appears below the visit reason in every `_ScheduleTile` in Today's Schedule, with a notes icon and muted style to distinguish it from the primary reason

**v0.31 — Search bar in My Patients screen**

- **Live search bar** — filters the patient list in real-time as the doctor types; matches against full name, username (`@handle`), and phone number
- **Match highlighting** — the matching portion of the name/username/phone is highlighted in accent colour with a subtle background tint
- **Username shown on tile** — `@username` now appears alongside the phone number on each patient card (fetched from `profiles.username`)
- **Filtered count** — header badge shows `matched / total` when a search is active
- **No-results state** — distinct empty state with search-off icon when the query returns nothing
- `DoctorPatientLink` model and `_attachPatientProfiles` updated to carry `patientUsername`

**v0.30 — Search & sort in All Prescriptions screen**

- **Search by diagnosis / medicine** — live text search bar filters the list as the doctor types; matches against diagnosis field and medicine names
- **Filter by date** — date chip opens a date picker; selected date is shown as a highlighted chip with an inline × to clear; shows only prescriptions from that consultation date
- **Sort toggle** — "Newest ↓ / Oldest ↑" chip toggles sort order with a single tap
- **Clear all** — "Clear" link appears when any filter is active and resets everything at once
- **Result count** — shows `filtered / total` when a filter is active so the doctor can see how many records match
- **No-results state** — separate empty state for "no results" (search icon) vs "no prescriptions" (medication icon)
- All filtering is client-side on the already-loaded list — no extra network calls

**v0.29 — Multi-image select from Gallery for prescriptions and test reports**

- **Gallery now supports multi-select** — tapping Gallery opens the native multi-image picker; all selected images are uploaded sequentially and added to the form
- **Camera remains single-shot** — camera path unchanged, still picks one photo at a time
- Applies to all 4 upload screens: doctor prescription, doctor lab report, patient prescription, patient test report

**v0.28 — Fix: appointment not moving to Completed after prescription save**

- **Root cause**: `appointments` table had a SELECT policy for doctors (v07) but no UPDATE policy — `updateStatus()` was silently blocked by RLS; the `catch (_) {}` hid the error so the appointment stayed `scheduled`
- **Fix**: Added `doctor_updates_own_appointment` UPDATE policy (USING + WITH CHECK on `doctor_user_id = auth.uid()`) and `patient_updates_own_appointment` policy for patient-side cancellations
- **Database migration v16**

**v0.27 — Prescription View screen + Edit History + Show More**

- **View button on every prescription** — doctors can now tap View (eye icon) to open a read-only Prescription screen showing diagnosis, medicines, notes, and images; Edit button in the header opens the edit screen from there
- **Edit button stays** — green edit icon visible only for prescriptions the doctor wrote themselves; View is available for all prescriptions regardless of author
- **Edit History section** — every prescription now shows a date-wise log at the bottom; each unique calendar day of create/edit appears once (same-day repeated edits collapse into one entry); entries show Created or Edited badge
- **Auto-log on create/edit** — `DoctorWritePrescriptionScreen._save()` now upserts a row in `prescription_edit_logs` with today's date; `ON CONFLICT (prescription_id, action_date) DO NOTHING` prevents duplicates
- **Show More → All Prescriptions screen** — Patient Details shows the 5 most recent prescriptions; if there are more, a "Show X more →" button opens `AllPrescriptionsScreen` which loads and lists all prescriptions with View + Edit per tile
- **Database migration v15** — `prescription_edit_logs` table with RLS; unique constraint on `(prescription_id, action_date)`

**v0.26 — Auto-add patient to My Patients after prescription**

- **Patient auto-linked after prescription save** — when a doctor writes a new prescription from Today's Schedule, the patient is automatically added to the doctor's "My Patients" list with `status = accepted` (no manual request/accept flow needed)
- **Idempotent upsert** — if the link already exists as accepted, nothing changes; if it was pending/rejected, it is upgraded to accepted
- **SECURITY DEFINER function** — `auto_link_appointment_patient(p_patient_id)` handles the upsert with elevated privileges; guards against abuse by verifying the caller has an appointment with the patient via `doctor_has_appointment_with()`
- **Database migration v14** — adds the `auto_link_appointment_patient` function

**v0.25 — Today's Schedule: Completed tab + auto-complete on Rx save**

- **New "Completed" tab in Today's Schedule** — third filter chip alongside Today and Upcoming; shows all completed appointments sorted most-recent-first
- **Auto-mark appointment as completed** — when a doctor writes and saves a new prescription for a patient opened from Today's Schedule, that appointment's status is automatically set to `completed` and moves out of the Today/Upcoming list into the Completed tab
- **Today/Upcoming tabs now exclude completed** — only `scheduled` appointments appear in Today and Upcoming, so the list stays clean after each consultation
- **Date shown on Completed tiles** — appointment date is displayed on each completed card (same as Upcoming)
- **Schedule reloads on return** — navigating back from Patient Details always refreshes the list to reflect any status changes

**v0.24 — Fix doctor prescription save RLS**

- **Fixed "Failed to save" when doctor writes prescription from Today's Schedule** — the `doctor_inserts_patient_rx` INSERT policy only allowed doctors to write prescriptions for patients in their `doctor_patient_links` (accepted), but not for appointment-only patients; updated policy now also permits insert when `doctor_has_appointment_with(user_id)` is true
- **Fixed doctor unable to edit prescriptions they wrote** — no UPDATE policy existed for doctors; added `doctor_updates_own_written_rx` policy so doctors can update any prescription where `written_by_doctor_id = auth.uid()`
- **Database migration v13** — recreates `doctor_inserts_patient_rx` and adds `doctor_updates_own_written_rx` on `prescriptions` table

**v0.23 — Visiting Information section (Doctor home + public profile)**

- **New "Visiting Information" section on Doctor Home** — doctors can set Visiting Fee (BDT), Visiting Hours, and Chamber directly from their home screen via an Edit button; data is saved instantly with no admin review required
- **Visiting Fee moved out of Credentials** — removed from the credential submit/edit form and from the admin-reviewed flow entirely; now lives only in the Visiting Information section
- **Migration v12** — added `visiting_hours TEXT` and `chamber TEXT` columns to `doctor_verifications`; `visiting_fee` column already existed
- **Visiting Information shown on patient-facing Doctor Profile** — patients viewing a doctor's public profile now see a "Visiting Information" card with Fee, Hours, and Chamber (when set)
- **Swipe-to-delete on My Doctors list** — patients can swipe left on any doctor in their list to delete with a confirmation dialog
- **Delete button on Doctor Public Profile** — "Remove from My Doctors" outlined red button appears below "Take Appointment" when the doctor is already in the patient's list

**v0.22 — Fix RLS circular reference (HTTP 500 on login)**

- **Fixed HTTP 500 on `fetchProfile()`** — the v10 RLS policies created a circular reference: `profiles → appointments → profiles` (via `doctor_reads_by_name_snapshot`), causing a 500 error on every profile read for doctor accounts; this broke login routing and role selection on Chrome (web) and anywhere the doctor tried to log in
- **Fix: SECURITY DEFINER function** — replaced the raw `EXISTS (SELECT ... FROM appointments)` subquery inside profiles/health_profiles/prescriptions/lab_reports policies with a call to `doctor_has_appointment_with(uuid)` — a `SECURITY DEFINER` function that reads `appointments` bypassing its own RLS, breaking the cycle
- **Database migration v11** — creates `doctor_has_appointment_with()` function and recreates all 4 appointment-patient RLS policies to use it
- **Fixed VS Code launch config** — replaced the generic Chrome URL launcher in `.vscode/launch.json` with proper `dart` type Flutter launch configs; "Run Without Debugging" now correctly starts the Flutter dev server instead of opening a dead `localhost:8080`
- **Fixed `_loadRole` silent swallow** — `fetchMyVerification()` errors are now caught in their own inner try-catch so a verification fetch failure no longer incorrectly shows the role selection screen

**v0.21 — Fix doctor RLS for appointment patients**

- **Fixed patient name showing "Patient"** in Today's Schedule — `profiles` RLS was blocking doctors from reading profiles of patients who booked appointments without being linked; new policy `doctor_reads_appt_patient_profile` added
- **Fixed Patient Details all-empty** — added RLS policies on `health_profiles`, `prescriptions`, `lab_reports` so doctors can read data for appointment-based patients (not just linked ones)
- **Database migration v10** — 4 new SELECT policies covering `profiles`, `health_profiles`, `prescriptions`, `lab_reports` for any patient with an appointment with the doctor

**v0.20 — Patient Details UI fix**

- **Removed "Add Appointment" button** from Patient Details screen bottom bar — only "Write Prescription" remains

**v0.19 — Doctor Full Profile Page**

- **Full-page doctor profile screen** — replaced the old bottom sheet popup with a dedicated `DoctorPublicProfileScreen`; shows doctor photo (large hero), name, specialty, visiting fee badge, hospital, degree, email, and "About" paragraph in a scrollable full-page layout
- **Accessible from three places** — opens from (1) global doctor search results, (2) patient's "My Doctors" list when tapping any saved doctor that has a Supabase sourceId, (3) patient's "Linked Doctors" list when tapping any linked doctor
- **Action buttons retained** — "Add to My Doctors" (green) and "Take Appointment" (accent blue) are on the profile page with the same logic as before
- **Service method added** — `fetchDoctorPublicProfile(doctorId)` in `DoctorPatientLinkService` fetches combined `profiles` + `doctor_verifications` data for a single doctor in parallel

**v0.18 — Doctor Visiting Fee + Admin Pending Edits Fix**

- **Visiting Fee field added** — required field on doctor signup and credentials edit screen; stored in `doctor_verifications.visiting_fee` (INTEGER, BDT); pending edit stored in `pending_visiting_fee`; shown with green badge in credentials view
- **Fee shown in patient-facing search** — `fetchApprovedDoctors()` now returns `visiting_fee`; displayed as green "BDT X" row in doctor search result tiles
- **Admin panel shows visiting fee** — appears in both the verification review card and the pending-edit diff view
- **Fixed admin "Edits (0)" bug** — `fetchPendingEdits()` was using an embedded `profiles(...)` join which PostgREST was silently dropping rows for (inner-join behavior on filtered queries); fixed by separating into two queries
- **Fixed `approve_doctor_edit` RPC** — now also copies `degree`, `about`, `visiting_fee` when approving edits
- **Database migration v09** — adds `visiting_fee`, `pending_visiting_fee`; recreates `approve_doctor_edit` with full field set

---

**v0.17 — Doctor Degree & About Myself Fields**

- **Degree field added** — required field on both the initial verification submit screen and the credentials edit screen; stored in `doctor_verifications.degree`; pending edit stored in `pending_degree`
- **About Myself field added** — required field on both forms; multi-line; stored in `doctor_verifications.about`; pending edit stored in `pending_about`
- **Admin panel updated** — Degree and About now shown in both the verification review card and the pending-edit diff view
- **Database migration v08** — added `degree`, `about`, `pending_degree`, `pending_about` columns to `doctor_verifications`

---

**v0.16 — Doctor Appointment Notifications + Patient Requests Section**

- **Real-time appointment notifications** — when a patient books an appointment the doctor's app receives a Supabase Realtime event; a local push notification fires immediately with the patient's name and appointment date; tapping the notification navigates the doctor directly to the Search Patient screen to send a link request
- **`showAppointmentNotification()` added to `ReminderService`** — dedicated `doctor_appointments` notification channel (high importance); static `onNotificationTapped` callback wired in `DoctorHomeScreen` so taps navigate correctly; `getLaunchPayload()` handles cold-start launches from notification tray
- **Patient Requests section on Doctor Home** — new section below Quick Actions listing all pending outgoing link requests the doctor has sent; each tile shows patient avatar, name, phone, and "Pending" amber badge; tapping navigates to Search Patient; empty state shown when no pending requests
- **Test Reports removed from Doctor Home quick actions** — section was redundant (accessed via My Patients → Patient Detail); replaced Write Prescription with a full-width card
- **Supabase Realtime subscription** — `doctor_home_screen` subscribes to `appointments` INSERT filtered by `doctor_user_id = uid`; channel cleaned up on dispose

---

**v0.15 — Doctor Today's Schedule Fix**

- **Today's Schedule now shows appointments correctly** — doctors can see all appointments booked under their name from the doctor portal; root cause was `doctor_user_id = null` on existing appointments combined with RLS blocking the name-snapshot fallback query
- **New RLS policy `doctor_reads_by_name_snapshot`** — added to `appointments` table; allows a doctor to read any appointment where `doctor_name_snapshot ILIKE their profile full_name`; acts as a permanent safety net for appointments where `doctor_user_id` is not set
- **`doctor_user_id` backfilled** — all existing appointments where `doctor_name_snapshot` exactly matches a doctor's `profiles.full_name` (case-insensitive) have been updated to set `doctor_user_id` to that doctor's UUID; primary query path (`doctor_user_id = uid`) now returns results directly

---

**v0.14 — Global Doctor Search + UI Fixes**

- **Global search now finds all approved doctors** — any patient can search for any doctor in the system by name or hospital; results show "My Doctor" badge (green) if already linked, or "Doctor" badge (blue) if not; previously only manually added doctors from the `doctors` table were searchable
- **Doctor profile bottom sheet on tap** — tapping a doctor in search results shows a modal sheet with avatar, name, hospital, and "Linked Doctor" badge; "Save to My Doctors" button creates a record in the `doctors` table and navigates to `DoctorDetailScreen`
- **`fetchApprovedDoctors()` added to `DoctorPatientLinkService`** — fetches all `profiles` with `role = 'doctor'` joined with `doctor_verifications` where `status = 'approved'`; both linked status and full doctor list loaded in parallel
- **"Last Prescribed" button wired up** — bottom bar button on the home screen (patient) now navigates to the Prescriptions screen; was previously a no-op (`onTap: null`)
- **"Add Doctor" FAB restored** — `FloatingActionButton.extended` restored in "My Doctors" screen; since patients can't initiate links (doctors do), tap now shows an info dialog explaining how to get linked

---

## v0.13 Updates (2026-05-25)

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

- `[2026-05-25]` Doctor appointment notifications — Supabase Realtime fires local push when patient books; tap navigates to Search Patient screen
- `[2026-05-25]` Patient Requests section added to Doctor Home — pending link requests with avatar, name, phone, Pending badge; empty state when none
- `[2026-05-25]` Test Reports quick action removed from Doctor Home; Write Prescription promoted to full-width card
- `[2026-05-25]` Doctor Today's Schedule fix — `doctor_reads_by_name_snapshot` RLS policy added; `doctor_user_id` backfilled for all existing appointments matching a doctor's `full_name`
- `[2026-05-25]` Doctor profile bottom sheet — tapping a doctor in global search shows profile sheet with Save to My Doctors button; navigates to DoctorDetailScreen on save
- `[2026-05-25]` Global doctor search — all approved doctors in system now searchable by name/hospital; linked doctors shown with "My Doctor" badge; `fetchApprovedDoctors()` added to `DoctorPatientLinkService`
- `[2026-05-25]` "Last Prescribed" button wired to Prescriptions screen; "Add Doctor" FAB restored with info dialog in My Doctors screen
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
