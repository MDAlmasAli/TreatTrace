// ─────────────────────────────────────────────────────────────────────────────
// validators.dart
//
// Pure validation functions for form fields.
// Each function returns null on success, or an error message string on failure.
// Flutter's Form / TextFormField uses this exact pattern.
// ─────────────────────────────────────────────────────────────────────────────

class Validators {
  // ── Email ─────────────────────────────────────────────────────────────────

  /// Validates that [value] is a properly formatted email address.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }

    // Simple but reliable email pattern check.
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }

    return null; // null means valid
  }

  // ── Password ──────────────────────────────────────────────────────────────

  /// Validates that [value] meets the minimum password requirements.
  /// Rules: at least 8 characters, one uppercase, one digit.
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }
    return null;
  }

  // ── Confirm Password ──────────────────────────────────────────────────────

  /// Checks that [value] exactly matches [originalPassword].
  static String? confirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != originalPassword) {
      return 'Passwords do not match.';
    }
    return null;
  }

  // ── Full Name ─────────────────────────────────────────────────────────────

  /// Validates that [value] is a non-empty name with at least 2 characters.
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required.';
    }
    if (value.trim().length < 2) {
      return 'Please enter your full name.';
    }
    return null;
  }

  // ── Required field (generic) ──────────────────────────────────────────────

  /// Generic required-field check with a custom [fieldName] for the message.
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  // Prevent instantiation.
  Validators._();
}
