// ─────────────────────────────────────────────────────────────────────────────
// app_preferences.dart
//
// Thin wrapper around SharedPreferences for persistent app settings.
//
// Stores:
//   • theme_mode        — 'system' | 'light' | 'dark'
//   • locale            — 'en' | 'bn'
//   • keep_me_logged_in — bool (default: true)
//   • remembered_email  — nullable String (only set when keep-me-logged-in is on)
//
// Call AppPreferences.init() in main() before runApp().
// ─────────────────────────────────────────────────────────────────────────────

import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  // ── Storage keys ──────────────────────────────────────────────────────────
  static const _keyTheme          = 'theme_mode';
  static const _keyLocale         = 'locale';
  static const _keyKeepLoggedIn   = 'keep_me_logged_in';
  static const _keyRememberedEmail= 'remembered_email';

  // ── Internal instance ─────────────────────────────────────────────────────
  static late SharedPreferences _prefs;

  /// Must be called once in main() before runApp().
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Theme ─────────────────────────────────────────────────────────────────
  /// One of: 'system', 'light', 'dark'
  static String get themeMode => _prefs.getString(_keyTheme) ?? 'light';
  static Future<void> setThemeMode(String v) => _prefs.setString(_keyTheme, v);

  // ── Locale ────────────────────────────────────────────────────────────────
  /// One of: 'en', 'bn'
  static String get locale => _prefs.getString(_keyLocale) ?? 'en';
  static Future<void> setLocale(String v) => _prefs.setString(_keyLocale, v);

  // ── Keep-me-logged-in ─────────────────────────────────────────────────────
  static bool get keepLoggedIn => _prefs.getBool(_keyKeepLoggedIn) ?? true;
  static Future<void> setKeepLoggedIn(bool v) =>
      _prefs.setBool(_keyKeepLoggedIn, v);

  // ── Remembered email ──────────────────────────────────────────────────────
  /// Only stored when keep-me-logged-in is true. Never stores passwords.
  static String? get rememberedEmail => _prefs.getString(_keyRememberedEmail);
  static Future<void> setRememberedEmail(String? v) => v != null
      ? _prefs.setString(_keyRememberedEmail, v)
      : _prefs.remove(_keyRememberedEmail);
}
