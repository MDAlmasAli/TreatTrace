// ─────────────────────────────────────────────────────────────────────────────
// app_theme.dart
//
// Provides AppTheme.light() and AppTheme.dark() ThemeData objects.
// Typography uses the bundled PlusJakartaSans family (assets/fonts/).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

const _font = 'PlusJakartaSans';

class AppTheme {
  AppTheme._();

  // ── Dark Theme ─────────────────────────────────────────────────────────────
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    final textTheme = base.textTheme.apply(fontFamily: _font).copyWith(
      displayLarge:  const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w700),
      displayMedium: const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w600),
      displaySmall:  const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w600),
      headlineLarge: const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w700),
      headlineMedium:const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w600),
      titleLarge:    const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium:   const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w500),
      titleSmall:    const TextStyle(fontFamily: _font, color: DarkColors.textSec,     fontWeight: FontWeight.w500),
      bodyLarge:     const TextStyle(fontFamily: _font, color: DarkColors.textPrimary),
      bodyMedium:    const TextStyle(fontFamily: _font, color: DarkColors.textSec),
      bodySmall:     const TextStyle(fontFamily: _font, color: DarkColors.textMuted),
      labelLarge:    const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontWeight: FontWeight.w600),
      labelMedium:   const TextStyle(fontFamily: _font, color: DarkColors.textSec),
      labelSmall:    const TextStyle(fontFamily: _font, color: DarkColors.textMuted),
    );

    return base.copyWith(
      scaffoldBackgroundColor: DarkColors.bg,
      cardColor: DarkColors.card,
      dividerColor: DarkColors.border,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      colorScheme: ColorScheme.dark(
        primary:    DarkColors.purpleBright,
        secondary:  DarkColors.cyan,
        surface:    DarkColors.card,
        error:      DarkColors.red,
        onPrimary:  Colors.white,
        onSecondary:Colors.white,
        onSurface:  DarkColors.textPrimary,
        onError:    Colors.white,
        brightness: Brightness.dark,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor:  DarkColors.bg,
        foregroundColor:  DarkColors.textPrimary,
        elevation:        0,
        centerTitle:      false,
        titleTextStyle:   TextStyle(
          fontFamily: _font,
          color:      DarkColors.textPrimary,
          fontSize:   18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: DarkColors.textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: DarkColors.surface,
        hintStyle: const TextStyle(fontFamily: _font, color: DarkColors.textMuted, fontSize: 13),
        labelStyle:const TextStyle(fontFamily: _font, color: DarkColors.textSec,   fontSize: 13),
        floatingLabelStyle: const TextStyle(fontFamily: _font, color: DarkColors.purpleBright, fontSize: 12),
        prefixIconColor: DarkColors.textMuted,
        suffixIconColor: DarkColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DarkColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DarkColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DarkColors.purpleBright, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DarkColors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DarkColors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DarkColors.purpleBright,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DarkColors.purpleBright,
          side: const BorderSide(color: DarkColors.borderLight, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DarkColors.purpleBright,
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DarkColors.purpleBright;
          return DarkColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DarkColors.purpleBright.withAlpha(80);
          return DarkColors.border;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DarkColors.purpleBright;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: DarkColors.borderLight, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: DarkColors.card,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: _font,
          color: DarkColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(fontFamily: _font, color: DarkColors.textSec, fontSize: 13),
      ),

      cardTheme: CardThemeData(
        color: DarkColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DarkColors.border, width: 1),
        ),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: DarkColors.card,
        textColor: DarkColors.textPrimary,
        iconColor: DarkColors.textSec,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: const DividerThemeData(
        color: DarkColors.border,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: DarkColors.cardHover,
        contentTextStyle: const TextStyle(fontFamily: _font, color: DarkColors.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DarkColors.purpleBright,
      ),
    );
  }

  // ── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData light() {
    const primaryColor = Color(0xFF136AFB);
    const bgColor      = Color(0xFFF0F4F8);
    const surfaceColor = Color(0xFFFFFFFF);
    const textDark     = Color(0xFF1E293B);
    const textMid      = Color(0xFF64748B);
    const textHint     = Color(0xFFB0BEC5);
    const borderColor  = Color(0xFFCBD5E1);

    final base = ThemeData.light(useMaterial3: true);

    final textTheme = base.textTheme.apply(fontFamily: _font).copyWith(
      displayLarge:  const TextStyle(fontFamily: _font, color: textDark, fontWeight: FontWeight.w700),
      headlineMedium:const TextStyle(fontFamily: _font, color: textDark, fontWeight: FontWeight.w600),
      titleLarge:    const TextStyle(fontFamily: _font, color: textDark, fontWeight: FontWeight.w600),
      bodyLarge:     const TextStyle(fontFamily: _font, color: textDark),
      bodyMedium:    const TextStyle(fontFamily: _font, color: textMid),
      bodySmall:     const TextStyle(fontFamily: _font, color: textHint),
      labelLarge:    const TextStyle(fontFamily: _font, color: textDark, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bgColor,
      cardColor: surfaceColor,
      dividerColor: borderColor,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      colorScheme: const ColorScheme.light(
        primary:    primaryColor,
        secondary:  Color(0xFF14B8A6),
        surface:    surfaceColor,
        error:      Color(0xFFEF4444),
        onPrimary:  Colors.white,
        onSecondary:Colors.white,
        onSurface:  textDark,
        onError:    Colors.white,
        brightness: Brightness.light,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor:  bgColor,
        foregroundColor:  textDark,
        elevation:        0,
        centerTitle:      false,
        titleTextStyle:   TextStyle(
          fontFamily: _font,
          color:      textDark,
          fontSize:   18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: const Color(0xFFEDF2F7),
        hintStyle: const TextStyle(fontFamily: _font, color: textHint, fontSize: 13),
        labelStyle:const TextStyle(fontFamily: _font, color: textMid,  fontSize: 13),
        floatingLabelStyle: const TextStyle(fontFamily: _font, color: primaryColor, fontSize: 12),
        prefixIconColor: textMid,
        suffixIconColor: textMid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor.withAlpha(80);
          return Colors.grey.shade300;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: borderColor, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: _font,
          color:      textDark,
          fontSize:   18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(fontFamily: _font, color: textMid, fontSize: 13),
      ),

      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: textDark,
        contentTextStyle: const TextStyle(fontFamily: _font, color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
