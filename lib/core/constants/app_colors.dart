// ─────────────────────────────────────────────────────────────────────────────
// app_colors.dart
// Central color palettes for TreatTrace — light (healthcare) + dark (futuristic).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AppColors — Light theme palette (healthcare blue/teal)
// ══════════════════════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════════════════════
// DarkColors — Dark theme palette (futuristic, from Welcome.html)
// ══════════════════════════════════════════════════════════════════════════════
class DarkColors {
  // ── Backgrounds ───────────────────────────────────────────────────────────
  /// Deepest background — #050508.
  static const Color bg = Color(0xFF050508);

  /// Surface / sheet background — #0E0E18.
  static const Color surface = Color(0xFF0E0E18);

  /// Card background — #131320.
  static const Color card = Color(0xFF131320);

  /// Card hover / elevated card — #1A1A2E.
  static const Color cardHover = Color(0xFF1A1A2E);

  // ── Borders ───────────────────────────────────────────────────────────────
  /// Default border — #1E1E35.
  static const Color border = Color(0xFF1E1E35);

  /// Lighter border for dividers — #2A2A45.
  static const Color borderLight = Color(0xFF2A2A45);

  // ── Accent colors ─────────────────────────────────────────────────────────
  /// Deep purple — #6D28D9.
  static const Color purple = Color(0xFF6D28D9);

  /// Bright purple — primary accent — #8B5CF6.
  static const Color purpleBright = Color(0xFF8B5CF6);

  /// Cyan — secondary accent — #0EA5E9.
  static const Color cyan = Color(0xFF0EA5E9);

  /// Amber — warning / highlight — #F59E0B.
  static const Color amber = Color(0xFFF59E0B);

  /// Green — success / account — #10B981.
  static const Color green = Color(0xFF10B981);

  /// Red — error / emergency — #EF4444.
  static const Color red = Color(0xFFEF4444);

  // ── Text ──────────────────────────────────────────────────────────────────
  /// Primary text — near-white — #F1F5F9.
  static const Color textPrimary = Color(0xFFF1F5F9);

  /// Secondary text — muted grey — #94A3B8.
  static const Color textSec = Color(0xFF94A3B8);

  /// Muted text — for placeholders — #475569.
  static const Color textMuted = Color(0xFF475569);

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// Purple-to-cyan accent gradient — used on buttons and hero elements.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [purpleBright, cyan],
  );

  /// Purple-to-deep-purple header gradient.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [card, surface],
  );

  // Prevent instantiation — this class is a namespace only.
  DarkColors._();
}
