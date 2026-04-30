// ─────────────────────────────────────────────────────────────────────────────
// login_screen.dart
//
// The Login screen for TreatTrace.
//
// What this screen does:
//   1. Collects the user's email and password.
//   2. Validates both fields before attempting login.
//   3. Calls AuthService.signIn() via Supabase.
//   4. On success → navigates to the Home screen.
//   5. On failure → shows a user-friendly error message.
//   6. Also provides links to Sign-up and Forgot Password flows.
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
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../../home/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Form infrastructure ───────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ── Services ──────────────────────────────────────────────────────────────
  final _authService = AuthService();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;   // true while waiting for Supabase response
  String? _errorMessage;     // shown in a red banner when login fails

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    // Always dispose controllers to free memory when the screen is removed.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Login action ──────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    // Clear any previous error first.
    setState(() => _errorMessage = null);

    // Run every field's validator — if any fail, stop here.
    if (!_formKey.currentState!.validate()) return;

    // Show loading spinner on the button.
    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // If we reach here, login succeeded. Navigate to Home.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      // AuthException contains Supabase-specific error messages.
      setState(() => _errorMessage = _friendlyError(e.message));
    } catch (e) {
      // Generic unexpected error fallback.
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      // Always hide the spinner, whether success or failure.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps Supabase's technical error strings into beginner-friendly messages.
  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please check your email and confirm your account first.';
    }
    if (msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return raw; // show the original message if we don't recognise it
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          // Prevents overflow when the keyboard appears.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              // ── Wave header ────────────────────────────────────────────────
              const MedicalHeader(
                subtitle: 'Welcome back! Log in to manage\nyour health appointments.',
              ),

              // ── Form card ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Screen title ───────────────────────────────────────
                      Text(
                        'Log In',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 4),
                      Text(
                        'Enter your credentials to continue.',
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

                      // ── Email field ────────────────────────────────────────
                      AuthTextField(
                        label: 'Email Address',
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                      const SizedBox(height: 18),

                      // ── Password field ─────────────────────────────────────
                      AuthTextField(
                        label: 'Password',
                        hint: 'Your password',
                        icon: Icons.lock_outline_rounded,
                        controller: _passwordController,
                        isPassword: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Password is required.' : null,
                      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                      // ── Forgot password link ───────────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 0),
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 10),

                      // ── Login button ───────────────────────────────────────
                      AuthButton(
                        label: 'Log In',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

                      const SizedBox(height: 32),

                      // ── Divider ────────────────────────────────────────────
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              "Don't have an account?",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 16),

                      // ── Sign-up button (outlined style) ────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Create an Account',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 450.ms),

                      const SizedBox(height: 24),

                      // ── App tagline ────────────────────────────────────────
                      Center(
                        child: Text(
                          '🏥  Find doctors · Book appointments · Stay healthy',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().fadeIn(delay: 500.ms),
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
// _ErrorBanner — shown when login fails.
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
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().shake(hz: 3, offset: const Offset(4, 0));
  }
}
