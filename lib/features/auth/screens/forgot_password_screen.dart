// ─────────────────────────────────────────────────────────────────────────────
// forgot_password_screen.dart
//
// Allows the user to request a password reset email via Supabase.
//
// Flow:
//   1. User enters their registered email address.
//   2. We call AuthService.sendPasswordResetEmail().
//   3. Supabase emails a reset link to that address.
//   4. We show a success state and let the user navigate back to Login.
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;   // when true, we show the success state
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendReset() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordResetEmail(_emailController.text);
      if (mounted) setState(() => _emailSent = true);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Back arrow in the app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _emailSent ? _buildSuccessState() : _buildFormState(),
        ),
      ),
    );
  }

  // ── Success state (shown after email is sent) ──────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 40),

        // Big animated checkmark icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: AppColors.success, size: 52),
        )
            .animate()
            .scale(delay: 100.ms, duration: 400.ms, curve: Curves.elasticOut),

        const SizedBox(height: 28),

        Text(
          'Check Your Email',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 12),

        Text(
          'We\'ve sent a password reset link to\n${_emailController.text.trim()}.\n\n'
          'Click the link in that email to set a new password. '
          'Check your spam folder if you don\'t see it.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 36),

        // Back to login button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              'Back to Login',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 500.ms),
      ],
    );
  }

  // ── Form state ─────────────────────────────────────────────────────────────
  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Illustration icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.lock_reset_outlined,
              color: Colors.white, size: 38),
        ).animate().fadeIn().scale(curve: Curves.easeOut),

        const SizedBox(height: 24),

        Text(
          'Forgot Password?',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 8),

        Text(
          'Enter the email address associated with your\n'
          'account and we\'ll send you a reset link.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ).animate().fadeIn(delay: 150.ms),

        const SizedBox(height: 32),

        // ── Error banner ─────────────────────────────────────────────────────
        if (_errorMessage != null) ...[
          Container(
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
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Email field ──────────────────────────────────────────────────────
        Form(
          key: _formKey,
          child: AuthTextField(
            label: 'Email Address',
            hint: 'you@example.com',
            icon: Icons.email_outlined,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

        const SizedBox(height: 28),

        // ── Send reset button ────────────────────────────────────────────────
        AuthButton(
          label: 'Send Reset Link',
          isLoading: _isLoading,
          onPressed: _handleSendReset,
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 24),

        // ── Back to login link ───────────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              '← Back to Login',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }
}
