// ─────────────────────────────────────────────────────────────────────────────
// app_text_styles.dart
// Centralised typography styles using Google Fonts (Poppins).
// Poppins is clean, modern, and highly readable — ideal for healthcare apps.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // ── Display / Hero text ───────────────────────────────────────────────────
  /// App name / hero heading — large, bold, white (used on dark header).
  static TextStyle get displayLarge => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.5,
      );

  /// Section heading — medium size, semi-bold.
  static TextStyle get headingLarge => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get headingMedium => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // ── Body text ─────────────────────────────────────────────────────────────
  /// Standard body text.
  static TextStyle get bodyLarge => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  // ── Labels ────────────────────────────────────────────────────────────────
  /// Input field label text.
  static TextStyle get label => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  /// Hint / placeholder text inside input fields.
  static TextStyle get hint => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textHint,
      );

  // ── Button ────────────────────────────────────────────────────────────────
  /// Primary button label.
  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
      );

  // ── Links ─────────────────────────────────────────────────────────────────
  /// Clickable link text (e.g., "Forgot Password?").
  static TextStyle get link => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
      );

  /// Error message text below input fields.
  static TextStyle get error => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.error,
      );

  // Prevent instantiation.
  AppTextStyles._();
}
