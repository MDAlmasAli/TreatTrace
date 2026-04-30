// ─────────────────────────────────────────────────────────────────────────────
// app_colors.dart
// Central color palette for TreatTrace — healthcare blue/teal theme.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class AppColors {
  // ── Primary brand colors ──────────────────────────────────────────────────
  /// Deep medical blue — used for primary buttons and key UI elements.
  static const Color primary = Color(0xFF1A6FBF);

  /// Lighter blue variant — gradients, highlights.
  static const Color primaryLight = Color(0xFF3B9EE8);

  /// Dark navy — deep backgrounds, overlays.
  static const Color primaryDark = Color(0xFF0D4A8A);

  // ── Secondary / accent ───────────────────────────────────────────────────
  /// Teal/mint green — secondary actions, success states, accents.
  static const Color secondary = Color(0xFF14B8A6);

  /// Lighter teal variant.
  static const Color secondaryLight = Color(0xFF5EEAD4);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  /// Page background — very light grey-blue, feels clinical and clean.
  static const Color background = Color(0xFFF0F4F8);

  /// Card / form container background.
  static const Color surface = Color(0xFFFFFFFF);

  /// Subtle divider or input fill colour.
  static const Color surfaceVariant = Color(0xFFEDF2F7);

  // ── Text ──────────────────────────────────────────────────────────────────
  /// Primary text — near-black for body content.
  static const Color textPrimary = Color(0xFF1E293B);

  /// Secondary text — medium grey for hints and labels.
  static const Color textSecondary = Color(0xFF64748B);

  /// Placeholder text inside input fields.
  static const Color textHint = Color(0xFFB0BEC5);

  // ── Semantic ──────────────────────────────────────────────────────────────
  /// Error / danger state.
  static const Color error = Color(0xFFEF4444);

  /// Success / confirmation state.
  static const Color success = Color(0xFF22C55E);

  /// Warning state.
  static const Color warning = Color(0xFFF59E0B);

  // ── Gradient helpers ─────────────────────────────────────────────────────
  /// Header gradient — from deep blue to mid blue.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
  );

  /// Button gradient — vivid blue.
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryLight],
  );

  // Prevent instantiation — this class is a namespace only.
  AppColors._();
}
