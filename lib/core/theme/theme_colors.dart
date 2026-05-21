// ─────────────────────────────────────────────────────────────────────────────
// theme_colors.dart
//
// Runtime-resolved color palette that switches between the dark futuristic
// palette (DarkColors) and the light healthcare palette (AppColors) based on
// the current ThemeData brightness.
//
// Usage inside any build() method:
//   final c = context.colors;
//   Container(color: c.card, ...)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

extension ThemeColorsExt on BuildContext {
  ThemeColors get colors => ThemeColors.of(this);
}

class ThemeColors {
  final bool isDark;

  const ThemeColors._(this.isDark);

  factory ThemeColors.of(BuildContext context) =>
      ThemeColors._(Theme.of(context).brightness == Brightness.dark);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  Color get bg        => isDark ? DarkColors.bg        : AppColors.background;
  // Light mode depth hierarchy:
  //   card (white, elevated) > surface (page-grey, sunken info blocks/inputs)
  Color get surface   => isDark ? DarkColors.surface   : AppColors.background;
  Color get card      => isDark ? DarkColors.card      : AppColors.surface;
  Color get cardHover => isDark ? DarkColors.cardHover : AppColors.surfaceVariant;

  // ── Borders ───────────────────────────────────────────────────────────────
  Color get border      => isDark ? DarkColors.border      : const Color(0xFFCBD5E1);
  Color get borderLight => isDark ? DarkColors.borderLight : const Color(0xFFE2E8F0);

  // ── Text ──────────────────────────────────────────────────────────────────
  Color get textPrimary => isDark ? DarkColors.textPrimary : AppColors.textPrimary;
  Color get textSec     => isDark ? DarkColors.textSec     : AppColors.textSecondary;
  Color get textMuted   => isDark ? DarkColors.textMuted   : AppColors.textHint;

  // ── Accent / brand color ──────────────────────────────────────────────────
  // Single brand color: DocTime-style blue in light, purple in dark.
  static const Color _brandBlue = Color(0xFF136AFB);

  Color get accent       => isDark ? DarkColors.purpleBright : _brandBlue;
  Color get purpleBright => isDark ? DarkColors.purpleBright : _brandBlue;
  Color get purple       => isDark ? DarkColors.purple       : _brandBlue;
  Color get cyan         => isDark ? DarkColors.cyan         : _brandBlue;

  // ── Semantic status colors — same in both themes ──────────────────────────
  Color get amber => DarkColors.amber;
  Color get green => DarkColors.green;
  Color get red   => DarkColors.red;

  // ── Gradients ─────────────────────────────────────────────────────────────
  LinearGradient get accentGradient => isDark
      ? DarkColors.accentGradient
      : const LinearGradient(colors: [_brandBlue, _brandBlue]);

  // Background gradient (login/splash full-screen wash).
  LinearGradient get bgGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? [DarkColors.bg, DarkColors.surface]
        : [AppColors.background, AppColors.surface],
  );

  // Header / card-to-surface gradient (profile header).
  LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? [DarkColors.card, DarkColors.surface]
        : [AppColors.surface, AppColors.surfaceVariant],
  );

  // ── Status-bar icon brightness ────────────────────────────────────────────
  Brightness get statusBarIconBrightness =>
      isDark ? Brightness.light : Brightness.dark;
}
