// ─────────────────────────────────────────────────────────────────────────────
// signup_screen.dart
//
// The Sign-up screen for TreatTrace.
//
// What this screen does:
//   1. Collects full name, email, password, confirm password.
//   2. Validates all fields (password strength, match check, etc.).
//   3. Requires the user to accept Terms & Conditions.
//   4. Calls AuthService.signUp() — creates an auth.users record in Supabase.
//   5. A database trigger automatically creates a matching row in `profiles`.
//   6. On success → shows a confirmation dialog, then goes to Login.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/validators.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/medical_header.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ── Form infrastructure ───────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── Services ──────────────────────────────────────────────────────────────
  final _authService = AuthService();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _termsAccepted = false;   // must be true before sign-up is allowed
  String? _errorMessage;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Sign-up action ────────────────────────────────────────────────────────
  Future<void> _handleSignUp() async {
    setState(() => _errorMessage = null);

    // 1. Validate all form fields.
    if (!_formKey.currentState!.validate()) return;

    // 2. Require Terms acceptance.
    if (!_termsAccepted) {
      setState(() =>
          _errorMessage = 'Please read and accept the Terms & Conditions.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
      );

      // Supabase sends a confirmation email by default.
      // Show a dialog telling the user to check their inbox.
      if (mounted) {
        await _showConfirmationDialog();
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps Supabase errors to user-friendly messages.
  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account with this email already exists. Try logging in.';
    }
    if (msg.contains('weak password')) {
      return 'Password is too weak. Please choose a stronger one.';
    }
    if (msg.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    return raw;
  }

  /// Shows a success dialog then pops back to the Login screen.
  Future<void> _showConfirmationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined,
                color: AppColors.success, size: 28),
            const SizedBox(width: 10),
            Text(
              'Check Your Email',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'A confirmation link has been sent to\n${_emailController.text.trim()}.\n\n'
          'Please click the link to activate your account, then log in.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();        // close dialog
              Navigator.of(context).pop();    // return to login screen
            },
            child: Text(
              'Go to Login',
              style: GoogleFonts.poppins(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              // ── Wave header ────────────────────────────────────────────────
              const MedicalHeader(
                subtitle: 'Create your account to find doctors\nand book appointments.',
              ),

              // ── Form ───────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Screen title ───────────────────────────────────────
                      Text(
                        'Create Account',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 4),
                      Text(
                        'Fill in the details below to get started.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ).animate().fadeIn(delay: 150.ms),

                      const SizedBox(height: 28),

                      // ── Error banner ───────────────────────────────────────
                      if (_errorMessage != null) ...[
                        _ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      // ── Full name ──────────────────────────────────────────
                      AuthTextField(
                        label: 'Full Name',
                        hint: 'e.g. John Smith',
                        icon: Icons.person_outline_rounded,
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        validator: Validators.fullName,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                      const SizedBox(height: 18),

                      // ── Email ──────────────────────────────────────────────
                      AuthTextField(
                        label: 'Email Address',
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                      const SizedBox(height: 18),

                      // ── Password ───────────────────────────────────────────
                      AuthTextField(
                        label: 'Password',
                        hint: 'Min. 8 chars, 1 uppercase, 1 number',
                        icon: Icons.lock_outline_rounded,
                        controller: _passwordController,
                        isPassword: true,
                        validator: Validators.password,
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                      const SizedBox(height: 8),

                      // Password strength hint bar
                      _PasswordStrengthBar(
                        password: _passwordController.text,
                      ),

                      const SizedBox(height: 18),

                      // ── Confirm password ───────────────────────────────────
                      AuthTextField(
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        icon: Icons.lock_reset_outlined,
                        controller: _confirmPasswordController,
                        isPassword: true,
                        // Rebuild on each keystroke so the validator can compare
                        // against the current value of _passwordController.
                        onChanged: (_) => setState(() {}),
                        validator: (v) => Validators.confirmPassword(
                          v,
                          _passwordController.text,
                        ),
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

                      const SizedBox(height: 20),

                      // ── Terms & Conditions checkbox ────────────────────────
                      _TermsCheckbox(
                        value: _termsAccepted,
                        onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 24),

                      // ── Sign-up button ─────────────────────────────────────
                      AuthButton(
                        label: 'Create Account',
                        isLoading: _isLoading,
                        onPressed: _handleSignUp,
                      ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1),

                      const SizedBox(height: 24),

                      // ── Back to login ──────────────────────────────────────
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Text(
                                'Log In',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PasswordStrengthBar
// Visual indicator showing how strong the entered password is.
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordStrengthBar extends StatelessWidget {
  final String password;

  const _PasswordStrengthBar({required this.password});

  /// Returns 0 (none) → 4 (strong) based on what the password contains.
  int _strength() {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;
    return score;
  }

  Color _color(int s) {
    switch (s) {
      case 1: return AppColors.error;
      case 2: return AppColors.warning;
      case 3: return AppColors.secondary;
      case 4: return AppColors.success;
      default: return AppColors.surfaceVariant;
    }
  }

  String _label(int s) {
    switch (s) {
      case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Strong';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _strength();
    return Row(
      children: [
        // 4 coloured segments
        ...List.generate(4, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: i < s ? _color(s) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
        const SizedBox(width: 10),
        Text(
          _label(s),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: s > 0 ? _color(s) : AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TermsCheckbox
// ─────────────────────────────────────────────────────────────────────────────
class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(
                text: 'I have read and agree to the ',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
                children: [
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' and ',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  TextSpan(
                    text: 'Privacy Policy.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorBanner
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().shake(hz: 3, offset: const Offset(4, 0));
  }
}
