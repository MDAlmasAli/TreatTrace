// ─────────────────────────────────────────────────────────────────────────────
// auth_button.dart
//
// Reusable gradient button for Login / Sign-up actions.
// Shows a circular spinner when [isLoading] is true.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class AuthButton extends StatelessWidget {
  /// The text label displayed inside the button.
  final String label;

  /// Called when the button is pressed (only when not loading).
  final VoidCallback? onPressed;

  /// When true the button shows a spinner instead of the label.
  final bool isLoading;

  /// Optional: width of the button. Defaults to full width.
  final double? width;

  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Gradient gives the button a polished, medical-professional look.
          gradient: isLoading
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withAlpha(180),
                    AppColors.primaryLight.withAlpha(180),
                  ],
                )
              : AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            // Disable tap when loading to prevent double-submissions.
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  // ── Loading spinner ────────────────────────────────────────
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  // ── Button label ───────────────────────────────────────────
                  : Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
