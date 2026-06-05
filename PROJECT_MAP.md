# TreatTrace — Project Map

> A guide to where every feature lives in `lib/`. Generated 2026-06-05.
> Structure is **feature-first**: each feature owns its `screens/`, `models/`, `services/`, and `widgets/`.
> Cross-cutting helpers live in `core/`; reusable widgets shared by multiple features live in `shared/`.

## Folder overview

```
lib/
├── main.dart                  App entry, AuthGate, role-aware router, splash
├── core/                      App-wide config, theme, services, utils (no feature logic)
├── shared/widgets/            Reusable widgets used by 2+ features
└── features/
    ├── auth/                  Login, signup, forgot password, role selection
    ├── patient/               Patient dashboard, profile, personal doctor book
    ├── doctor/                Doctor dashboard + all doctor-side tools, doctor domain model/service
    ├── admin/                 Admin verification console
    ├── appointment/           Appointment domain (shared by patient + doctor)
    ├── prescription/          Prescription domain (shared)
    ├── test_report/           Test-report domain (shared)
    ├── review/                Doctor review domain (shared)
    ├── notification/          In-app notifications (shared)
    └── search/                Doctor search + public doctor profile
```

---

## Auth
| Page / Feature | File Path | Class Name |
|---|---|---|
| Login | lib/features/auth/screens/login_screen.dart | LoginScreen |
| Sign up / Register | lib/features/auth/screens/signup_screen.dart | SignupScreen |
| Forgot / reset password | lib/features/auth/screens/forgot_password_screen.dart | ForgotPasswordScreen |
| Choose role (patient / doctor) | lib/features/auth/screens/role_selection_screen.dart | RoleSelectionScreen |
| Primary action button (widget) | lib/features/auth/widgets/auth_button.dart | AuthButton |
| Styled text field (widget) | lib/features/auth/widgets/auth_text_field.dart | AuthTextField |
| Branded header (widget) | lib/features/auth/widgets/medical_header.dart | MedicalHeader |

## Patient
| Page / Feature | File Path | Class Name |
|---|---|---|
| Patient home / dashboard | lib/features/patient/screens/patient_home_screen.dart | PatientHomeScreen |
| Profile + settings | lib/features/patient/screens/patient_profile_screen.dart | PatientProfileScreen |
| Edit profile / health info | lib/features/patient/screens/patient_edit_profile_screen.dart | PatientEditProfileScreen |
| My Doctors (personal book: list / search / filter) | lib/features/patient/screens/my_doctors_screen.dart | MyDoctorsScreen |
| Doctor record + appointment history | lib/features/patient/screens/my_doctor_detail_screen.dart | MyDoctorDetailScreen |
| Health profile (model) | lib/features/patient/models/health_profile_model.dart | HealthProfile |

## Doctor
| Page / Feature | File Path | Class Name |
|---|---|---|
| Doctor home / dashboard | lib/features/doctor/screens/doctor_home_screen.dart | DoctorHomeScreen |
| Today's schedule / live queue | lib/features/doctor/screens/doctor_today_schedule_screen.dart | DoctorTodayScheduleScreen |
| All appointments | lib/features/doctor/screens/all_appointments_screen.dart | AllAppointmentsScreen |
| All prescriptions written | lib/features/doctor/screens/all_prescriptions_screen.dart | AllPrescriptionsScreen |
| All test reports | lib/features/doctor/screens/all_test_reports_screen.dart | AllTestReportsScreen |
| My patients (linked) | lib/features/doctor/screens/my_patients_screen.dart | MyPatientsScreen |
| Patient profile / history (doctor view) | lib/features/doctor/screens/patient_detail_screen.dart | PatientDetailScreen |
| Write a prescription | lib/features/doctor/screens/doctor_write_prescription_screen.dart | DoctorWritePrescriptionScreen |
| View a prescription (doctor) | lib/features/doctor/screens/doctor_prescription_view_screen.dart | DoctorPrescriptionViewScreen |
| View / edit credentials (verification) | lib/features/doctor/screens/doctor_credentials_screen.dart | DoctorCredentialsScreen |
| Submit credentials for verification | lib/features/doctor/screens/doctor_verification_submit_screen.dart | DoctorVerificationSubmitScreen |
| Doctor (model) | lib/features/doctor/models/doctor_model.dart | Doctor |
| Doctor–patient link (model) | lib/features/doctor/models/doctor_patient_link_model.dart | DoctorPatientLink |
| Doctor CRUD (service) | lib/features/doctor/services/doctor_service.dart | DoctorService |
| Doctor–patient links (service) | lib/features/doctor/services/doctor_patient_link_service.dart | DoctorPatientLinkService |

## Admin
| Page / Feature | File Path | Class Name |
|---|---|---|
| Verify doctors + review credential edits | lib/features/admin/screens/admin_home_screen.dart | AdminHomeScreen |

## Appointment (shared: patient + doctor)
| Page / Feature | File Path | Class Name |
|---|---|---|
| Appointments list (Upcoming / Past / Cancelled) | lib/features/appointment/screens/appointments_screen.dart | AppointmentsScreen |
| Create / edit appointment | lib/features/appointment/screens/add_edit_appointment_screen.dart | AddEditAppointmentScreen |
| Appointment details + status / reschedule | lib/features/appointment/screens/appointment_detail_screen.dart | AppointmentDetailScreen |
| Appointment (model + AppointmentStatus enum) | lib/features/appointment/models/appointment_model.dart | Appointment |
| Booking / queue engine (service) | lib/features/appointment/services/appointment_service.dart | AppointmentService |

## Prescription (shared)
| Page / Feature | File Path | Class Name |
|---|---|---|
| Prescription list (All / Active / Expired) | lib/features/prescription/screens/prescriptions_screen.dart | PrescriptionsScreen |
| Create / edit prescription | lib/features/prescription/screens/add_edit_prescription_screen.dart | AddEditPrescriptionScreen |
| Prescription detail + PDF | lib/features/prescription/screens/prescription_detail_screen.dart | PrescriptionDetailScreen |
| Prescription (model) | lib/features/prescription/models/prescription_model.dart | Prescription |
| Medicine line item (model) | lib/features/prescription/models/prescription_medicine_model.dart | PrescriptionMedicine |
| Prescription CRUD (service) | lib/features/prescription/services/prescription_service.dart | PrescriptionService |

## Test Report (shared)
| Page / Feature | File Path | Class Name |
|---|---|---|
| Test report list + filter | lib/features/test_report/screens/test_reports_screen.dart | TestReportsScreen |
| Create / edit test report + upload | lib/features/test_report/screens/add_edit_test_report_screen.dart | AddEditTestReportScreen |
| Test report detail + image gallery | lib/features/test_report/screens/test_report_detail_screen.dart | TestReportDetailScreen |
| Test report (model) | lib/features/test_report/models/test_report_model.dart | TestReport |
| Test report CRUD (service) | lib/features/test_report/services/test_report_service.dart | TestReportService |

## Review (shared)
| Page / Feature | File Path | Class Name |
|---|---|---|
| Doctor's view of own anonymous reviews | lib/features/review/screens/doctor_own_reviews_screen.dart | DoctorOwnReviewsScreen |
| Doctor review (model) | lib/features/review/models/doctor_review_model.dart | DoctorReview |
| Review CRUD + eligibility (service) | lib/features/review/services/review_service.dart | ReviewService |
| Shared review UI (stars / badge / section) | lib/features/review/widgets/review_widgets.dart | StarRow, RatingBadge, DoctorReviewsSection |

## Notification (shared)
| Page / Feature | File Path | Class Name |
|---|---|---|
| In-app notification inbox | lib/features/notification/screens/notifications_screen.dart | NotificationsScreen |
| Notification (model) | lib/features/notification/models/app_notification_model.dart | AppNotification |
| Notification CRUD + realtime (service) | lib/features/notification/services/notification_service.dart | NotificationService |
| Header bell + unread badge (widget) | lib/features/notification/widgets/notification_bell.dart | NotificationBell |

## Search
| Page / Feature | File Path | Class Name |
|---|---|---|
| Global search + default doctor list | lib/features/search/screens/global_search_screen.dart | GlobalSearchScreen |
| Public doctor profile + book | lib/features/search/screens/doctor_public_profile_screen.dart | DoctorPublicProfileScreen |
| Doctor filter & sort sheet (widget + DoctorSort enum) | lib/features/search/widgets/doctor_filter_sheet.dart | DoctorFilter |

## Core (app-wide, no feature logic)
| Concern | File Path | Class Name |
|---|---|---|
| Supabase credentials | lib/core/config/supabase_config.dart | SupabaseConfig |
| Color palettes | lib/core/constants/app_colors.dart | AppColors, DarkColors |
| Text styles | lib/core/constants/app_text_styles.dart | AppTextStyles |
| Localized strings + locale propagation | lib/core/l10n/app_strings.dart | AppLocale |
| Persistent preferences (theme, locale, session) | lib/core/preferences/app_preferences.dart | AppPreferences |
| Account deletion | lib/core/services/account_service.dart | AccountService |
| Auth (sign in / out, profile) | lib/core/services/auth_service.dart | AuthService |
| Doctor verification status | lib/core/services/doctor_verification_service.dart | DoctorVerificationService |
| Profile (shared by patient + health profile) | lib/core/services/profile_service.dart | ProfileService |
| Local reminders / scheduling | lib/core/services/reminder_service.dart | ReminderService |
| Theme builder (light / dark) | lib/core/theme/app_theme.dart | AppTheme |
| Theme colors + `context.colors` | lib/core/theme/theme_colors.dart | ThemeColors |
| File-type helpers | lib/core/utils/file_utils.dart | (top-level helpers) |
| Input validators | lib/core/utils/validators.dart | Validators |

## Shared / Common Widgets
| Widget | File Path | Class Name |
|---|---|---|
| Linked-doctor picker card (used in Rx + test-report forms) | lib/shared/widgets/linked_doctor_picker_card.dart | LinkedDoctorPickerCard |

## App Entry
| Concern | File Path | Class Name |
|---|---|---|
| Entry point, AuthGate, role-aware router, splash | lib/main.dart | TreatTraceApp, AuthGate |
