// ─────────────────────────────────────────────────────────────────────────────
// signup_screen.dart — Dark futuristic sign-up screen for TreatTrace.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/validators.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey                   = GlobalKey<FormState>();
  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService               = AuthService();

  bool    _isLoading       = false;
  bool    _termsAccepted   = false;
  bool    _obscurePassword = true;
  bool    _obscureConfirm  = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      setState(() =>
          _errorMessage = 'Please read and accept the Terms & Conditions.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signUp(
        email:    _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone:    _phoneController.text,
      );
      if (mounted) await _showConfirmationDialog();
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
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('weak password')) return 'Password is too weak.';
    if (msg.contains('invalid email')) return 'Invalid email address.';
    return raw;
  }

  Future<void> _showConfirmationDialog() async {
    final c = context.colors;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined,
                color: DarkColors.green, size: 26),
            const SizedBox(width: 10),
            Text('Check Your Email',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: c.textPrimary)),
          ],
        ),
        content: Text(
          'A confirmation link has been sent to\n'
          '${_emailController.text.trim()}.\n\n'
          'Click the link to activate your account, then log in.',
          style: GoogleFonts.poppins(
              fontSize: 13, color: c.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text('Go to Login',
                style: GoogleFonts.poppins(
                    color: DarkColors.purpleBright,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Container(
        decoration: BoxDecoration(gradient: c.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Logo
                _LogoBlock()
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.85, 0.85),
                        curve: Curves.easeOut),

                const SizedBox(height: 32),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.border, width: 1),
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
                        Text('Create Account',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            )).animate().fadeIn(delay: 150.ms),

                        const SizedBox(height: 4),

                        Text('Fill in the details below to get started.',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: c.textSec))
                            .animate()
                            .fadeIn(delay: 190.ms),

                        const SizedBox(height: 24),

                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 16),
                        ],

                        // Full name
                        _DarkTextField(
                          label:       'Full Name',
                          hint:        'e.g. John Smith',
                          icon:        Icons.person_outline_rounded,
                          controller:  _nameController,
                          keyboardType:TextInputType.name,
                          validator:   Validators.fullName,
                        ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.1),

                        const SizedBox(height: 16),

                        // Email
                        _DarkTextField(
                          label:        'Email Address',
                          hint:         'you@example.com',
                          icon:         Icons.email_outlined,
                          controller:   _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator:    Validators.email,
                        ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.1),

                        const SizedBox(height: 16),

                        // Phone
                        _DarkTextField(
                          label:        'Phone Number (optional)',
                          hint:         '+880 1XXX-XXXXXX',
                          icon:         Icons.phone_outlined,
                          controller:   _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (v.replaceAll(RegExp(r'\D'), '').length < 7) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1),

                        const SizedBox(height: 16),

                        // Password
                        _DarkTextField(
                          label:       'Password',
                          hint:        'Min. 8 chars, 1 uppercase, 1 number',
                          icon:        Icons.lock_outline_rounded,
                          controller:  _passwordController,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: c.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: Validators.password,
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                        const SizedBox(height: 8),

                        // Password strength bar
                        _PasswordStrengthBar(
                            password: _passwordController.text),

                        const SizedBox(height: 16),

                        // Confirm password
                        _DarkTextField(
                          label:       'Confirm Password',
                          hint:        'Re-enter your password',
                          icon:        Icons.lock_reset_outlined,
                          controller:  _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: c.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) => Validators.confirmPassword(
                              v, _passwordController.text),
                        ).animate().fadeIn(delay: 340.ms).slideY(begin: 0.1),

                        const SizedBox(height: 20),

                        // Terms checkbox
                        _TermsCheckbox(
                          value:     _termsAccepted,
                          onChanged: (v) =>
                              setState(() => _termsAccepted = v ?? false),
                        ).animate().fadeIn(delay: 380.ms),

                        const SizedBox(height: 24),

                        // Sign-up button
                        _GradientButton(
                          label:     'Create Account',
                          isLoading: _isLoading,
                          onPressed: _handleSignUp,
                        ).animate().fadeIn(delay: 420.ms).slideY(begin: 0.1),

                        const SizedBox(height: 20),

                        // Back to login
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Already have an account? ',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: c.textSec)),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Text('Log In',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: DarkColors.purpleBright,
                                    )),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 460.ms),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06),

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
    final c = context.colors;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: DarkColors.accentGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: DarkColors.purpleBright.withAlpha(80),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.local_hospital_rounded,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: 12),
        Text('TreatTrace',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            )),
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
  final void Function(String)?     onChanged;

  const _DarkTextField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textSec,
            )),
        const SizedBox(height: 6),
        TextFormField(
          controller:   controller,
          keyboardType: keyboardType,
          obscureText:  obscureText,
          validator:    validator,
          onChanged:    onChanged,
          style: GoogleFonts.poppins(
              fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: GoogleFonts.poppins(
                fontSize: 13, color: c.textMuted),
            prefixIcon: Icon(icon, color: c.textMuted, size: 20),
            suffixIcon: suffixIcon,
            filled:    true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border, width: 1),
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

// ── Gradient button ───────────────────────────────────────────────────────────
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
                  : Text(label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      )),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Password strength bar ─────────────────────────────────────────────────────
class _PasswordStrengthBar extends StatelessWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

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
      case 1:  return DarkColors.red;
      case 2:  return DarkColors.amber;
      case 3:  return DarkColors.cyan;
      case 4:  return DarkColors.green;
      default: return DarkColors.border;
    }
  }

  String _label(int s) {
    switch (s) {
      case 1:  return 'Weak';
      case 2:  return 'Fair';
      case 3:  return 'Good';
      case 4:  return 'Strong';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _strength();
    return Row(
      children: [
        ...List.generate(4, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: i < s ? _color(s) : c.border,
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
            color: s > 0 ? _color(s) : c.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── Terms checkbox ────────────────────────────────────────────────────────────
class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value:    value,
          onChanged: onChanged,
          side: BorderSide(color: c.borderLight, width: 1.5),
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? DarkColors.purpleBright
                : Colors.transparent,
          ),
          checkColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(
                text: 'I have read and agree to the ',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: c.textSec),
                children: [
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: DarkColors.purpleBright,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' and ',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: c.textSec),
                  ),
                  TextSpan(
                    text: 'Privacy Policy.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: DarkColors.purpleBright,
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
