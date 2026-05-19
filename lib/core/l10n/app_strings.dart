// ─────────────────────────────────────────────────────────────────────────────
// app_strings.dart
//
// Simple localization system for TreatTrace.
// Supports English ('en') and Bangla ('bn').
//
// Usage:
//   final s = S.of(context);
//   Text(s.login)
//
// The locale is propagated via AppLocale InheritedWidget from main.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// S — Localized strings accessor
// ══════════════════════════════════════════════════════════════════════════════
class S {
  final String locale;
  const S._(this.locale);

  static S of(BuildContext context) {
    final locale = AppLocale.of(context)?.locale ?? 'en';
    return S._(locale);
  }

  String get(String key) => _strings[locale]?[key] ?? _strings['en']![key] ?? key;

  // ── Auth ──────────────────────────────────────────────────────────────────
  String get login          => get('login');
  String get createAccount  => get('create_account');
  String get forgotPassword => get('forgot_password');
  String get emailAddress   => get('email_address');
  String get password       => get('password');
  String get keepMeLoggedIn => get('keep_me_logged_in');

  // ── Navigation ────────────────────────────────────────────────────────────
  String get home             => get('home');
  String get myProfile        => get('my_profile');
  String get settings         => get('settings');
  String get logout           => get('logout');

  // ── Profile sections ──────────────────────────────────────────────────────
  String get medicalIdentity  => get('medical_identity');
  String get healthRecords    => get('health_records');
  String get emergencyContact => get('emergency_contact');
  String get accountSettings  => get('account_settings');

  // ── Settings ──────────────────────────────────────────────────────────────
  String get darkMode         => get('dark_mode');
  String get language         => get('language');
  String get changePassword   => get('change_password');
  String get changeEmail      => get('change_email');
  String get changePhone      => get('change_phone');

  // ── Health fields ─────────────────────────────────────────────────────────
  String get bloodGroup       => get('blood_group');
  String get age              => get('age');
  String get height           => get('height');
  String get weight           => get('weight');
  String get bmi              => get('bmi');
  String get allergies        => get('allergies');
  String get ongoingTreatment => get('ongoing_treatment');

  // ── Profile fields ────────────────────────────────────────────────────────
  String get phoneNumber      => get('phone_number');
  String get fullName         => get('full_name');

  // ── Actions ───────────────────────────────────────────────────────────────
  String get saveChanges      => get('save_changes');
  String get editProfile      => get('edit_profile');
  String get noDataYet        => get('no_data_yet');
  String get addInfo          => get('add_info');
  String get cancel           => get('cancel');
  String get confirm          => get('confirm');
  String get send             => get('send');

  // ── Greetings ─────────────────────────────────────────────────────────────
  String get goodMorning      => get('good_morning');
  String get goodAfternoon    => get('good_afternoon');
  String get goodEvening      => get('good_evening');

  // ── Home ──────────────────────────────────────────────────────────────────
  String get quickActions     => get('quick_actions');
  String get prescription     => get('prescription');
  String get testReport       => get('test_report');

  // ── Prescription ──────────────────────────────────────────────────────────
  String get prescriptions        => get('prescriptions');
  String get addPrescription      => get('add_prescription');
  String get editPrescription     => get('edit_prescription');
  String get doctorName           => get('doctor_name');
  String get doctorSpecialty      => get('doctor_specialty');
  String get hospitalClinic       => get('hospital_clinic');
  String get doctorPhone          => get('doctor_phone');
  String get diagnosis            => get('diagnosis');
  String get prescriptionDate     => get('prescription_date');
  String get notes                => get('notes');
  String get medicines            => get('medicines');
  String get addMedicine          => get('add_medicine');
  String get medicineName         => get('medicine_name');
  String get dose                 => get('dose');
  String get frequency            => get('frequency');
  String get durationDays         => get('duration_days');
  String get instructions         => get('instructions');
  String get morning              => get('morning');
  String get afternoon            => get('afternoon');
  String get evening              => get('evening');
  String get night                => get('night');
  String get active               => get('active');
  String get expired              => get('expired');
  String get all                  => get('all');
  String get noPrescriptions      => get('no_prescriptions');
  String get deletePrescription   => get('delete_prescription');
  String get deleteConfirm        => get('delete_confirm');
  String get exportPdf            => get('export_pdf');
  String get refillSoon           => get('refill_soon');
  String get allergyWarning       => get('allergy_warning');
  String get uploadImage          => get('upload_image');
  String get viewImage            => get('view_image');
  String get searchPrescriptions  => get('search_prescriptions');
  String get reminderSet          => get('reminder_set');

  // ── Doctors ───────────────────────────────────────────────────────────────
  String get myDoctors            => get('my_doctors');
  String get addDoctor            => get('add_doctor');
  String get editDoctor           => get('edit_doctor');
  String get specialty            => get('specialty');
  String get chamberAddress       => get('chamber_address');
  String get consultationFee      => get('consultation_fee');
  String get noDoctors            => get('no_doctors');
  String get searchDoctors        => get('search_doctors');
  String get deleteDoctor         => get('delete_doctor');
  String get deleteDoctorConfirm  => get('delete_doctor_confirm');

  // ── Appointments ──────────────────────────────────────────────────────────
  String get appointments         => get('appointments');
  String get addAppointment       => get('add_appointment');
  String get editAppointment      => get('edit_appointment');
  String get appointmentDate      => get('appointment_date');
  String get appointmentTime      => get('appointment_time');
  String get visitReason          => get('visit_reason');
  String get statusScheduled      => get('status_scheduled');
  String get statusCompleted      => get('status_completed');
  String get statusCancelled      => get('status_cancelled');
  String get upcoming             => get('upcoming');
  String get past                 => get('past');
  String get noAppointments       => get('no_appointments');
  String get searchAppointments   => get('search_appointments');
  String get deleteAppointment    => get('delete_appointment');
  String get deleteApptConfirm    => get('delete_appt_confirm');
  String get markCompleted        => get('mark_completed');
  String get cancelAppointment    => get('cancel_appointment');
  String get selectDoctor         => get('select_doctor');
  String get noLinkedDoctor       => get('no_linked_doctor');

  // ── Test Report ──────────────────────────────────────────────────────────
  String get testReports          => get('test_reports');
  String get addTestReport        => get('add_test_report');
  String get editTestReport       => get('edit_test_report');
  String get testName             => get('test_name');
  String get category             => get('category');
  String get testDate             => get('test_date');
  String get labHospital          => get('lab_hospital');
  String get noTestReports        => get('no_test_reports');
  String get searchTestReports    => get('search_test_reports');
  String get deleteTestReport     => get('delete_test_report');
  String get deleteReportConfirm  => get('delete_report_confirm');
  String get linkedPrescription   => get('linked_prescription');
  String get noLinkedPrescription => get('no_linked_prescription');
  String get customCategory       => get('custom_category');
  String get enterCustomCategory  => get('enter_custom_category');

  // ── Welcome ───────────────────────────────────────────────────────────────
  String get welcome          => get('welcome');
  String get tagline          => get('tagline');

  // ══════════════════════════════════════════════════════════════════════════
  // String maps
  // ══════════════════════════════════════════════════════════════════════════
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'login':              'Log In',
      'create_account':     'Create Account',
      'forgot_password':    'Forgot Password',
      'email_address':      'Email Address',
      'password':           'Password',
      'keep_me_logged_in':  'Keep me logged in',
      'home':               'Home',
      'my_profile':         'My Profile',
      'medical_identity':   'Medical Identity',
      'health_records':     'Health Records',
      'emergency_contact':  'Emergency Contact (ICE)',
      'settings':           'Settings & Preferences',
      'logout':             'Log Out',
      'dark_mode':          'Dark Mode',
      'language':           'Language',
      'change_password':    'Change Password',
      'change_email':       'Change Email',
      'change_phone':       'Change Phone Number',
      'account_settings':   'Account Settings',
      'blood_group':        'Blood Group',
      'age':                'Age',
      'height':             'Height',
      'weight':             'Weight',
      'bmi':                'BMI',
      'allergies':          'Allergies & Conditions',
      'ongoing_treatment':  'Ongoing Treatment',
      'phone_number':       'Phone Number',
      'full_name':          'Full Name',
      'save_changes':       'Save Changes',
      'edit_profile':       'Edit Profile',
      'no_data_yet':        'No data yet — tap to add',
      'add_info':           'Add Info',
      'cancel':             'Cancel',
      'confirm':            'Confirm',
      'send':               'Send',
      'good_morning':       'Good morning,',
      'good_afternoon':     'Good afternoon,',
      'good_evening':       'Good evening,',
      'quick_actions':      'Quick Actions',
      'prescription':       'Prescription',
      'test_report':        'Test Report',
      'welcome':            'Welcome',
      'tagline':            'Your health, our priority.',
      'prescriptions':      'Prescriptions',
      'add_prescription':   'Add Prescription',
      'edit_prescription':  'Edit Prescription',
      'doctor_name':        'Doctor Name',
      'doctor_specialty':   'Specialty',
      'hospital_clinic':    'Hospital / Clinic',
      'doctor_phone':       'Doctor Phone',
      'diagnosis':          'Diagnosis',
      'prescription_date':  'Prescription Date',
      'notes':              'Notes',
      'medicines':          'Medicines',
      'add_medicine':       'Add Medicine',
      'medicine_name':      'Medicine Name',
      'dose':               'Dose (e.g. 500mg)',
      'frequency':          'Frequency',
      'duration_days':      'Duration (days)',
      'instructions':       'Instructions (e.g. after meal)',
      'morning':            'Morning',
      'afternoon':          'Afternoon',
      'evening':            'Evening',
      'night':              'Night',
      'active':             'Active',
      'expired':            'Expired',
      'all':                'All',
      'no_prescriptions':   'No prescriptions yet — tap + to add one',
      'delete_prescription':'Delete Prescription',
      'delete_confirm':     'This prescription and all its medicines will be permanently deleted.',
      'export_pdf':         'Export PDF',
      'refill_soon':        'Refill Soon',
      'allergy_warning':    'Allergy Warning',
      'upload_image':       'Upload Prescription Image',
      'view_image':         'View Image',
      'search_prescriptions': 'Search by doctor, diagnosis…',
      'reminder_set':       'Medicine reminders set',
      'my_doctors':             'My Doctors',
      'add_doctor':             'Add Doctor',
      'edit_doctor':            'Edit Doctor',
      'specialty':              'Specialty',
      'chamber_address':        'Chamber Address',
      'consultation_fee':       'Consultation Fee',
      'no_doctors':             'No doctors saved yet — tap + to add one',
      'search_doctors':         'Search by name, specialty…',
      'delete_doctor':          'Delete Doctor',
      'delete_doctor_confirm':  'This doctor will be permanently deleted.',
      'appointments':           'Appointments',
      'add_appointment':        'Add Appointment',
      'edit_appointment':       'Edit Appointment',
      'appointment_date':       'Appointment Date',
      'appointment_time':       'Time (optional)',
      'visit_reason':           'Visit Reason',
      'status_scheduled':       'Scheduled',
      'status_completed':       'Completed',
      'status_cancelled':       'Cancelled',
      'upcoming':               'Upcoming',
      'past':                   'Past',
      'no_appointments':        'No appointments here',
      'search_appointments':    'Search by doctor, reason…',
      'delete_appointment':     'Delete Appointment',
      'delete_appt_confirm':    'This appointment will be permanently deleted.',
      'mark_completed':         'Mark as Completed',
      'cancel_appointment':     'Cancel Appointment',
      'select_doctor':          'Select Doctor',
      'no_linked_doctor':       'No Doctor Linked',
      'test_reports':           'Test Reports',
      'add_test_report':        'Add Test Report',
      'edit_test_report':       'Edit Test Report',
      'test_name':              'Test Name',
      'category':               'Category',
      'test_date':              'Test Date',
      'lab_hospital':           'Lab / Hospital',
      'no_test_reports':        'No test reports yet — tap + to add one',
      'search_test_reports':    'Search by test, doctor…',
      'delete_test_report':     'Delete Test Report',
      'delete_report_confirm':  'This report and all its images will be permanently deleted.',
      'linked_prescription':    'Linked Prescription',
      'no_linked_prescription': 'None',
      'custom_category':        'Custom',
      'enter_custom_category':  'Enter category name',
    },
    'bn': {
      'login':              'লগ ইন',
      'create_account':     'অ্যাকাউন্ট তৈরি করুন',
      'forgot_password':    'পাসওয়ার্ড ভুলে গেছেন',
      'email_address':      'ইমেইল ঠিকানা',
      'password':           'পাসওয়ার্ড',
      'keep_me_logged_in':  'লগইন মনে রাখুন',
      'home':               'হোম',
      'my_profile':         'আমার প্রোফাইল',
      'medical_identity':   'স্বাস্থ্য পরিচয়',
      'health_records':     'স্বাস্থ্য রেকর্ড',
      'emergency_contact':  'জরুরি যোগাযোগ',
      'settings':           'সেটিংস',
      'logout':             'লগ আউট',
      'dark_mode':          'ডার্ক মোড',
      'language':           'ভাষা',
      'change_password':    'পাসওয়ার্ড পরিবর্তন',
      'change_email':       'ইমেইল পরিবর্তন',
      'change_phone':       'ফোন নম্বর পরিবর্তন',
      'account_settings':   'অ্যাকাউন্ট সেটিংস',
      'blood_group':        'রক্তের গ্রুপ',
      'age':                'বয়স',
      'height':             'উচ্চতা',
      'weight':             'ওজন',
      'bmi':                'বিএমআই',
      'allergies':          'অ্যালার্জি ও রোগ',
      'ongoing_treatment':  'চলমান চিকিৎসা',
      'phone_number':       'ফোন নম্বর',
      'full_name':          'পুরো নাম',
      'save_changes':       'পরিবর্তন সংরক্ষণ',
      'edit_profile':       'প্রোফাইল সম্পাদনা',
      'no_data_yet':        'এখনো কোনো তথ্য নেই — যোগ করতে ট্যাপ করুন',
      'add_info':           'তথ্য যোগ করুন',
      'cancel':             'বাতিল',
      'confirm':            'নিশ্চিত করুন',
      'send':               'পাঠান',
      'good_morning':       'শুভ সকাল,',
      'good_afternoon':     'শুভ বিকেল,',
      'good_evening':       'শুভ সন্ধ্যা,',
      'quick_actions':      'দ্রুত কার্যক্রম',
      'prescription':       'প্রেসক্রিপশন',
      'test_report':        'পরীক্ষার রিপোর্ট',
      'welcome':            'স্বাগতম',
      'tagline':            'আপনার স্বাস্থ্য, আমাদের অগ্রাধিকার।',
      'prescriptions':      'প্রেসক্রিপশন',
      'add_prescription':   'প্রেসক্রিপশন যোগ করুন',
      'edit_prescription':  'প্রেসক্রিপশন সম্পাদনা',
      'doctor_name':        'ডাক্তারের নাম',
      'doctor_specialty':   'বিশেষজ্ঞতা',
      'hospital_clinic':    'হাসপাতাল / চেম্বার',
      'doctor_phone':       'ডাক্তারের ফোন',
      'diagnosis':          'রোগ নির্ণয়',
      'prescription_date':  'প্রেসক্রিপশনের তারিখ',
      'notes':              'মন্তব্য',
      'medicines':          'ওষুধ',
      'add_medicine':       'ওষুধ যোগ করুন',
      'medicine_name':      'ওষুধের নাম',
      'dose':               'ডোজ (যেমন ৫০০মিগ্রা)',
      'frequency':          'ফ্রিকোয়েন্সি',
      'duration_days':      'মেয়াদ (দিন)',
      'instructions':       'নির্দেশনা (যেমন খাবার পরে)',
      'morning':            'সকাল',
      'afternoon':          'দুপুর',
      'evening':            'বিকেল',
      'night':              'রাত',
      'active':             'চলমান',
      'expired':            'মেয়াদোত্তীর্ণ',
      'all':                'সব',
      'no_prescriptions':   'এখনো কোনো প্রেসক্রিপশন নেই — + চাপুন',
      'delete_prescription':'প্রেসক্রিপশন মুছুন',
      'delete_confirm':     'এই প্রেসক্রিপশন এবং সকল ওষুধ স্থায়ীভাবে মুছে যাবে।',
      'export_pdf':         'PDF রপ্তানি করুন',
      'refill_soon':        'শীঘ্রই শেষ হবে',
      'allergy_warning':    'অ্যালার্জি সতর্কতা',
      'upload_image':       'প্রেসক্রিপশনের ছবি আপলোড করুন',
      'view_image':         'ছবি দেখুন',
      'search_prescriptions': 'ডাক্তার, রোগ দিয়ে খুঁজুন…',
      'reminder_set':       'ওষুধের রিমাইন্ডার সেট হয়েছে',
      'my_doctors':             'আমার ডাক্তার',
      'add_doctor':             'ডাক্তার যোগ করুন',
      'edit_doctor':            'ডাক্তার সম্পাদনা',
      'specialty':              'বিশেষজ্ঞতা',
      'chamber_address':        'চেম্বারের ঠিকানা',
      'consultation_fee':       'ভিজিট ফি',
      'no_doctors':             'এখনো কোনো ডাক্তার নেই — + চাপুন',
      'search_doctors':         'নাম, বিশেষজ্ঞতা দিয়ে খুঁজুন…',
      'delete_doctor':          'ডাক্তার মুছুন',
      'delete_doctor_confirm':  'এই ডাক্তারের তথ্য স্থায়ীভাবে মুছে যাবে।',
      'appointments':           'অ্যাপয়েন্টমেন্ট',
      'add_appointment':        'অ্যাপয়েন্টমেন্ট যোগ করুন',
      'edit_appointment':       'অ্যাপয়েন্টমেন্ট সম্পাদনা',
      'appointment_date':       'অ্যাপয়েন্টমেন্টের তারিখ',
      'appointment_time':       'সময় (ঐচ্ছিক)',
      'visit_reason':           'পরিদর্শনের কারণ',
      'status_scheduled':       'নির্ধারিত',
      'status_completed':       'সম্পন্ন',
      'status_cancelled':       'বাতিল',
      'upcoming':               'আসন্ন',
      'past':                   'অতীত',
      'no_appointments':        'এখানে কোনো অ্যাপয়েন্টমেন্ট নেই',
      'search_appointments':    'ডাক্তার, কারণ দিয়ে খুঁজুন…',
      'delete_appointment':     'অ্যাপয়েন্টমেন্ট মুছুন',
      'delete_appt_confirm':    'এই অ্যাপয়েন্টমেন্ট স্থায়ীভাবে মুছে যাবে।',
      'mark_completed':         'সম্পন্ন হিসেবে চিহ্নিত করুন',
      'cancel_appointment':     'অ্যাপয়েন্টমেন্ট বাতিল করুন',
      'select_doctor':          'ডাক্তার বেছে নিন',
      'no_linked_doctor':       'কোনো ডাক্তার লিঙ্ক নেই',
      'test_reports':           'টেস্ট রিপোর্ট',
      'add_test_report':        'টেস্ট রিপোর্ট যোগ করুন',
      'edit_test_report':       'টেস্ট রিপোর্ট সম্পাদনা',
      'test_name':              'পরীক্ষার নাম',
      'category':               'ধরন',
      'test_date':              'পরীক্ষার তারিখ',
      'lab_hospital':           'ল্যাব / হাসপাতাল',
      'no_test_reports':        'এখনো কোনো রিপোর্ট নেই — + চাপুন',
      'search_test_reports':    'পরীক্ষা, ডাক্তার দিয়ে খুঁজুন…',
      'delete_test_report':     'রিপোর্ট মুছুন',
      'delete_report_confirm':  'এই রিপোর্ট এবং সকল ছবি স্থায়ীভাবে মুছে যাবে।',
      'linked_prescription':    'সংযুক্ত প্রেসক্রিপশন',
      'no_linked_prescription': 'নেই',
      'custom_category':        'কাস্টম',
      'enter_custom_category':  'ধরনের নাম লিখুন',
    },
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// AppLocale — InheritedWidget that propagates the active locale down the tree.
// ══════════════════════════════════════════════════════════════════════════════
class AppLocale extends InheritedWidget {
  final String locale;

  const AppLocale({
    super.key,
    required this.locale,
    required super.child,
  });

  static AppLocale? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocale>();

  @override
  bool updateShouldNotify(AppLocale old) => old.locale != locale;
}
