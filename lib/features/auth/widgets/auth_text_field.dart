// ─────────────────────────────────────────────────────────────────────────────
// auth_text_field.dart
//
// A reusable styled text input field used across Login and Sign-up screens.
// Supports icons, password toggle, validation, and focus animations.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class AuthTextField extends StatefulWidget {
  /// The label shown above or inside the field (e.g. "Email Address").
  final String label;

  /// Placeholder text shown when the field is empty.
  final String hint;

  /// Leading icon (left side of the field).
  final IconData icon;

  /// Set to true for password fields — enables the show/hide toggle.
  final bool isPassword;

  /// The controller that holds and reads the field's text value.
  final TextEditingController controller;

  /// Validation function — returns null if valid, error string if not.
  final String? Function(String?)? validator;

  /// Keyboard type — e.g. TextInputType.emailAddress for the email field.
  final TextInputType keyboardType;

  /// Called every time the user changes the text (useful for real-time checks).
  final void Function(String)? onChanged;

  /// If true, the field cannot be edited (used for display-only scenarios).
  final bool readOnly;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.isPassword = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  // Tracks whether the password is currently visible.
  bool _obscureText = true;

  // Tracks whether this field is focused so we can animate the border colour.
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    // The border colour changes when the field is focused.
    final borderColor = _isFocused ? AppColors.primary : AppColors.surfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Field label ──────────────────────────────────────────────────────
        Text(
          widget.label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _isFocused ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        // ── Input field ──────────────────────────────────────────────────────
        Focus(
          // Detect when the field gains or loses focus to update the border.
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.isPassword && _obscureText,
            keyboardType: widget.keyboardType,
            readOnly: widget.readOnly,
            onChanged: widget.onChanged,
            validator: widget.validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textHint,
              ),

              // ── Leading icon ───────────────────────────────────────────────
              prefixIcon: Icon(
                widget.icon,
                color: _isFocused ? AppColors.primary : AppColors.textHint,
                size: 20,
              ),

              // ── Password show/hide toggle ──────────────────────────────────
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscureText = !_obscureText);
                      },
                    )
                  : null,

              // ── Background fill ────────────────────────────────────────────
              filled: true,
              fillColor: widget.readOnly
                  ? AppColors.surfaceVariant
                  : AppColors.surface,

              // ── Borders ────────────────────────────────────────────────────
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 2),
              ),

              // ── Error text style ───────────────────────────────────────────
              errorStyle: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.error,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
