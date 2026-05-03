// ─────────────────────────────────────────────────────────────────────────────
// forgot_password_screen.dart — Dark futuristic forgot-password screen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService     = AuthService();

  bool    _isLoading  = false;
  bool    _emailSent  = false;
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
      setState(() =>
          _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: DarkColors.purpleBright, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DarkColors.bg, DarkColors.surface],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _emailSent ? _buildSuccessState() : _buildFormState(),
          ),
        ),
      ),
    );
  }

  // ── Success state ─────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 48),

        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: DarkColors.green.withAlpha(20),
            shape: BoxShape.circle,
            border: Border.all(
                color: DarkColors.green.withAlpha(60), width: 2),
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: DarkColors.green, size: 52),
        )
            .animate()
            .scale(
                delay: 100.ms,
                duration: 400.ms,
                curve: Curves.elasticOut),

        const SizedBox(height: 32),

        Text('Check Your Email',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DarkColors.textPrimary,
            )).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 12),

        Text(
          'We\'ve sent a password reset link to\n'
          '${_emailController.text.trim()}.\n\n'
          'Click the link in that email to set a new password. '
          'Check your spam folder if you don\'t see it.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: DarkColors.textSec,
            height: 1.6,
          ),
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 40),

        // Back to login button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: DarkColors.accentGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: DarkColors.purpleBright.withAlpha(60),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: Text('Back to Login',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 500.ms),
      ],
    );
  }

  // ── Form state ────────────────────────────────────────────────────────────
  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: DarkColors.accentGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: DarkColors.purpleBright.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.lock_reset_outlined,
              color: Colors.white, size: 38),
        ).animate().fadeIn().scale(curve: Curves.easeOut),

        const SizedBox(height: 28),

        Text('Forgot Password?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DarkColors.textPrimary,
            )).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 8),

        Text(
          'Enter your registered email address and\n'
          'we\'ll send you a reset link.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: DarkColors.textSec,
            height: 1.5,
          ),
        ).animate().fadeIn(delay: 140.ms),

        const SizedBox(height: 32),

        // Error banner
        if (_errorMessage != null) ...[
          _ErrorBanner(message: _errorMessage!),
          const SizedBox(height: 16),
        ],

        // Email field inside a dark card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DarkColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DarkColors.border, width: 1),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email Address',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DarkColors.textSec,
                    )),
                const SizedBox(height: 6),
                TextFormField(
                  controller:   _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator:    Validators.email,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: DarkColors.textPrimary),
                  decoration: InputDecoration(
                    hintText:  'you@example.com',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13, color: DarkColors.textMuted),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: DarkColors.textMuted, size: 20),
                    filled:    true,
                    fillColor: DarkColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: DarkColors.border, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: DarkColors.border, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: DarkColors.purpleBright, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: DarkColors.red, width: 1),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: DarkColors.red, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

        const SizedBox(height: 28),

        // Send reset button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: DarkColors.accentGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: DarkColors.purpleBright.withAlpha(60),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isLoading ? null : _handleSendReset,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text('Send Reset Link',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 24),

        // Back to login link
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              '← Back to Login',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: DarkColors.purpleBright,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DarkColors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DarkColors.red.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: DarkColors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: DarkColors.red)),
          ),
        ],
      ),
    ).animate().fadeIn().shake(hz: 3, offset: const Offset(4, 0));
  }
}
