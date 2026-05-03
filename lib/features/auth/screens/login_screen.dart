// ─────────────────────────────────────────────────────────────────────────────
// login_screen.dart — Dark futuristic login screen for TreatTrace.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/validators.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService        = AuthService();

  bool    _isLoading      = false;
  bool    _keepLoggedIn   = true;
  bool    _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _keepLoggedIn = AppPreferences.keepLoggedIn;
    final remembered = AppPreferences.rememberedEmail;
    if (remembered != null) _emailController.text = remembered;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        email:    _emailController.text,
        password: _passwordController.text,
      );

      // Persist keep-me-logged-in preference and optional email.
      await AppPreferences.setKeepLoggedIn(_keepLoggedIn);
      await AppPreferences.setRememberedEmail(
          _keepLoggedIn ? _emailController.text.trim() : null);

      // Auth stream in AuthGate will navigate automatically.
    } on AuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.message));
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }
    if (msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),

                // ── Logo ───────────────────────────────────────────────────
                _LogoBlock()
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.easeOut,
                    ),

                const SizedBox(height: 40),

                // ── Card ───────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: DarkColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: DarkColors.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: DarkColors.purpleBright.withAlpha(20),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log In',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: DarkColors.textPrimary,
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 4),

                        Text(
                          'Enter your credentials to continue.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: DarkColors.textSec,
                          ),
                        ).animate().fadeIn(delay: 240.ms),

                        const SizedBox(height: 28),

                        // Error banner
                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 16),
                        ],

                        // Email field
                        _DarkTextField(
                          label:       'Email Address',
                          hint:        'you@example.com',
                          icon:        Icons.email_outlined,
                          controller:  _emailController,
                          keyboardType:TextInputType.emailAddress,
                          validator:   Validators.email,
                        ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1),

                        const SizedBox(height: 16),

                        // Password field
                        _DarkTextField(
                          label:          'Password',
                          hint:           'Your password',
                          icon:           Icons.lock_outline_rounded,
                          controller:     _passwordController,
                          obscureText:    _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: DarkColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Password is required.'
                              : null,
                        ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.1),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordScreen()),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 0),
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: DarkColors.purpleBright,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 360.ms),

                        // Keep me logged in
                        GestureDetector(
                          onTap: () => setState(
                              () => _keepLoggedIn = !_keepLoggedIn),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _keepLoggedIn,
                                  onChanged: (v) => setState(
                                      () => _keepLoggedIn = v ?? true),
                                  side: const BorderSide(
                                      color: DarkColors.borderLight,
                                      width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(4)),
                                  fillColor: WidgetStateProperty.resolveWith(
                                    (s) => s.contains(WidgetState.selected)
                                        ? DarkColors.purpleBright
                                        : Colors.transparent,
                                  ),
                                  checkColor: Colors.white,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Keep me logged in',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: DarkColors.textSec,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 380.ms),

                        const SizedBox(height: 24),

                        // Login button
                        _GradientButton(
                          label:     'Log In',
                          isLoading: _isLoading,
                          onPressed: _handleLogin,
                        ).animate().fadeIn(delay: 420.ms).slideY(begin: 0.1),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.06),

                const SizedBox(height: 28),

                // Divider
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: DarkColors.border, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "Don't have an account?",
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: DarkColors.textSec),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: DarkColors.border, thickness: 1)),
                  ],
                ).animate().fadeIn(delay: 480.ms),

                const SizedBox(height: 16),

                // Sign-up button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SignupScreen()),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: DarkColors.borderLight, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Create an Account',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DarkColors.purpleBright,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 520.ms),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo block ────────────────────────────────────────────────────────────────
class _LogoBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: DarkColors.accentGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: DarkColors.purpleBright.withAlpha(80),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.local_hospital_rounded,
              color: Colors.white, size: 38),
        ),
        const SizedBox(height: 16),
        Text(
          'TreatTrace',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: DarkColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your health, our priority.',
          style: GoogleFonts.poppins(
              fontSize: 13, color: DarkColors.textSec),
        ),
      ],
    );
  }
}

// ── Dark text field ───────────────────────────────────────────────────────────
class _DarkTextField extends StatelessWidget {
  final String                     label;
  final String                     hint;
  final IconData                   icon;
  final TextEditingController      controller;
  final TextInputType?             keyboardType;
  final bool                       obscureText;
  final Widget?                    suffixIcon;
  final String? Function(String?)? validator;
  const _DarkTextField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DarkColors.textSec,
            )),
        const SizedBox(height: 6),
        TextFormField(
          controller:   controller,
          keyboardType: keyboardType,
          obscureText:  obscureText,
          validator:    validator,
          style: GoogleFonts.poppins(
              fontSize: 14, color: DarkColors.textPrimary),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: GoogleFonts.poppins(
                fontSize: 13, color: DarkColors.textMuted),
            prefixIcon: Icon(icon,
                color: DarkColors.textMuted, size: 20),
            suffixIcon: suffixIcon,
            filled:    true,
            fillColor: DarkColors.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: DarkColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: DarkColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: DarkColors.purpleBright, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: DarkColors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: DarkColors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Gradient login button ─────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String       label;
  final bool         isLoading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
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
