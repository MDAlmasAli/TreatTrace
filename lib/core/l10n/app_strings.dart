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
