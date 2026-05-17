// ─────────────────────────────────────────────────────────────────────────────
// edit_profile_screen.dart
//
// Full edit form for the user's health profile + basic account fields.
// Pre-populates from existing HealthProfile + account data when editing.
// Returns true via Navigator.pop() on a successful save.
//
// Sections:
//   0. Account Info     — full name, phone (saved via AccountService)
//   1. Medical Identity — blood group, age, height, weight
//   2. Health Records   — allergies & conditions, ongoing treatment
//   3. Emergency Contact— ICE name + phone
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/profile_service.dart';
import '../models/health_profile.dart';

const List<String> _bloodGroupOptions = [
  'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
];

Color _bmiColor(double bmi) {
  if (bmi < 18.5) return DarkColors.cyan;
  if (bmi < 25.0) return DarkColors.green;
  if (bmi < 30.0) return DarkColors.amber;
  return DarkColors.red;
}

String _bmiLabel(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25.0) return 'Normal Weight';
  if (bmi < 30.0) return 'Overweight';
  return 'Obese';
}

// ══════════════════════════════════════════════════════════════════════════════
// EditProfileScreen
// ══════════════════════════════════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  final HealthProfile?          existing;
  final Map<String, dynamic>?   accountData;

  const EditProfileScreen({
    super.key,
    this.existing,
    this.accountData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _profileService  = ProfileService();
  final _authService     = AuthService();
  final _accountService  = AccountService();

  // ── Account controllers ───────────────────────────────────────────────────
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  // ── Health controllers ────────────────────────────────────────────────────
  final _ageCtrl     = TextEditingController();
  final _feetCtrl    = TextEditingController();
  final _inchesCtrl  = TextEditingController();
  final _weightCtrl  = TextEditingController();
  final _allergyCtrl = TextEditingController();
  final _treatCtrl   = TextEditingController();
  final _icNameCtrl  = TextEditingController();
  final _icPhoneCtrl = TextEditingController();

  String? _bloodGroup;
  bool    _isSaving   = false;
  double? _bmiPreview;

  @override
  void initState() {
    super.initState();
    _prefill();
    for (final c in [_feetCtrl, _inchesCtrl, _weightCtrl]) {
      c.addListener(_recomputeBmi);
    }
  }

  void _prefill() {
    // Account fields
    final acct = widget.accountData;
    if (acct != null) {
      _fullNameCtrl.text = (acct['full_name'] as String?) ?? '';
      _phoneCtrl.text    = (acct['phone']     as String?) ?? '';
    }

    // Health fields
    final p = widget.existing;
    if (p == null) return;

    _bloodGroup = p.bloodGroup;
    if (p.ageYears != null) _ageCtrl.text = '${p.ageYears}';

    if (p.heightCm != null) {
      final totalIn  = p.heightCm! / 2.54;
      _feetCtrl.text   = (totalIn ~/ 12).toString();
      _inchesCtrl.text = ((totalIn % 12).round()).toString();
    }

    if (p.weightKg != null) _weightCtrl.text = p.weightKg!.toStringAsFixed(1);
    if (p.allergies        != null) _allergyCtrl.text = p.allergies!;
    if (p.ongoingTreatment != null) _treatCtrl.text   = p.ongoingTreatment!;
    if (p.emergencyName    != null) _icNameCtrl.text  = p.emergencyName!;
    if (p.emergencyPhone   != null) _icPhoneCtrl.text = p.emergencyPhone!;

    _recomputeBmi();
  }

  void _recomputeBmi() {
    final feet   = int.tryParse(_feetCtrl.text)   ?? 0;
    final inches = int.tryParse(_inchesCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text);
    final cm = (feet * 12 + inches) * 2.54;

    if (cm > 0 && weight != null && weight > 0) {
      final hM = cm / 100.0;
      setState(() => _bmiPreview = weight / (hM * hM));
    } else {
      setState(() => _bmiPreview = null);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _fullNameCtrl, _phoneCtrl,
      _ageCtrl, _feetCtrl, _inchesCtrl, _weightCtrl,
      _allergyCtrl, _treatCtrl, _icNameCtrl, _icPhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // 1. Save account fields (full name + phone) via AccountService
      final newName  = _fullNameCtrl.text.trim();
      final newPhone = _phoneCtrl.text.trim();
      if (newName.isNotEmpty) {
        await _accountService.updateFullName(newName);
      }
      if (newPhone.isNotEmpty) {
        await _accountService.updatePhone(newPhone);
      }

      // 2. Save health profile via ProfileService
      final feet   = int.tryParse(_feetCtrl.text)   ?? 0;
      final inches = int.tryParse(_inchesCtrl.text) ?? 0;
      final cm     = (feet * 12 + inches) * 2.54;

      await _profileService.saveHealthProfile(HealthProfile(
        userId:           _authService.currentUser!.id,
        bloodGroup:       _bloodGroup,
        ageYears:         int.tryParse(_ageCtrl.text),
        heightCm:         cm > 0 ? cm : null,
        weightKg:         double.tryParse(_weightCtrl.text),
        allergies:        _nullIfBlank(_allergyCtrl.text),
        ongoingTreatment: _nullIfBlank(_treatCtrl.text),
        emergencyName:    _nullIfBlank(_icNameCtrl.text),
        emergencyPhone:   _nullIfBlank(_icPhoneCtrl.text),
      ));

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: DarkColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _nullIfBlank(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  // ── Credential helpers ────────────────────────────────────────────────────
  String _friendlyAuthError(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('password')) return 'Incorrect password. Please try again.';
      if (msg.contains('email'))    return 'That email is already in use.';
      if (msg.contains('network'))  return 'No internet connection. Check your network.';
      return e.message;
    }
    return 'An unexpected error occurred.';
  }

  void _showChangeEmailDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text('Change Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your new email. A confirmation link will be sent to it.',
                  style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textSec),
                ),
                const SizedBox(height: 16),
                _DialogTextField(
                  controller:   ctrl,
                  hint:         'new@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofocus:    true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: DarkColors.purpleBright, strokeWidth: 2),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    final email = ctrl.text.trim();
                    if (email.isEmpty || !email.contains('@')) return;
                    setS(() => loading = true);
                    try {
                      await _authService.updateEmail(email);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Confirmation email sent. Click the link to confirm.'),
                        ));
                      }
                    } catch (e) {
                      setS(() => loading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(_friendlyAuthError(e)),
                          backgroundColor: DarkColors.red,
                        ));
                      }
                    }
                  },
                  child: const Text('Send Link'),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        bool loading    = false;
        bool obscureNew = true;
        bool obscureConf = true;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogPasswordField(
                  controller: newCtrl,
                  hint:       'New password (min 6 chars)',
                  obscure:    obscureNew,
                  onToggle:   () => setS(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _DialogPasswordField(
                  controller: confCtrl,
                  hint:       'Confirm new password',
                  obscure:    obscureConf,
                  onToggle:   () => setS(() => obscureConf = !obscureConf),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: DarkColors.purpleBright, strokeWidth: 2),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    final np = newCtrl.text;
                    final cp = confCtrl.text;
                    if (np.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Password must be at least 6 characters.'),
                        backgroundColor: DarkColors.red,
                      ));
                      return;
                    }
                    if (np != cp) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Passwords do not match.'),
                        backgroundColor: DarkColors.red,
                      ));
                      return;
                    }
                    setS(() => loading = true);
                    try {
                      await _authService.updatePassword(np);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Password updated successfully.'),
                        ));
                      }
                    } catch (e) {
                      setS(() => loading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(_friendlyAuthError(e)),
                          backgroundColor: DarkColors.red,
                        ));
                      }
                    }
                  },
                  child: const Text('Update'),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(MediaQuery.of(context).padding.top),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountSection(),
                    const SizedBox(height: 24),
                    _buildMedicalSection(),
                    const SizedBox(height: 24),
                    _buildHealthSection(),
                    const SizedBox(height: 24),
                    _buildEmergencySection(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(double topPad) {
    final c = context.colors;
    return Container(
      color: c.card,
      padding: EdgeInsets.only(
          top: topPad + 14, left: 20, right: 20, bottom: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  color: c.textSec, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Edit Profile',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const Spacer(),
          if (_isSaving)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: DarkColors.purpleBright, strokeWidth: 2.5),
            ),
        ],
      ),
    );
  }

  // ── Account section ───────────────────────────────────────────────────────
  Widget _buildAccountSection() {
    return _FormSection(
      title: 'Account Info',
      accentColor: DarkColors.purpleBright,
      children: [
        _FormInput(
          icon:         Icons.person_rounded,
          label:        'Full Name',
          controller:   _fullNameCtrl,
          hint:         'e.g. John Smith',
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 16),
        _FormInput(
          icon:         Icons.phone_rounded,
          label:        'Phone Number',
          controller:   _phoneCtrl,
          hint:         '+880 1XXX-XXXXXX',
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            if (v.replaceAll(RegExp(r'\D'), '').length < 7) {
              return 'Enter a valid phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        Divider(color: context.colors.border, height: 1),
        const SizedBox(height: 16),
        Text(
          'Credentials',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.textSec,
          ),
        ),
        const SizedBox(height: 10),
        _CredentialButton(
          icon:  Icons.email_rounded,
          label: 'Change Email',
          onTap: _showChangeEmailDialog,
        ),
        const SizedBox(height: 8),
        _CredentialButton(
          icon:  Icons.lock_rounded,
          label: 'Change Password',
          onTap: _showChangePasswordDialog,
        ),
      ],
    );
  }

  // ── Medical section ───────────────────────────────────────────────────────
  Widget _buildMedicalSection() {
    return _FormSection(
      title: 'Medical Identity',
      accentColor: DarkColors.cyan,
      children: [
        _DropdownField(
          icon:      Icons.bloodtype_rounded,
          label:     'Blood Group',
          value:     _bloodGroup,
          items:     _bloodGroupOptions,
          onChanged: (v) => setState(() => _bloodGroup = v),
        ),
        const SizedBox(height: 16),
        _FormInput(
          icon:       Icons.cake_rounded,
          label:      'Age (years)',
          controller: _ageCtrl,
          hint:       'e.g. 22',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final n = int.tryParse(v);
            if (n == null || n <= 0 || n > 120) return 'Enter a valid age (1–120)';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FormInput(
                icon:       Icons.height_rounded,
                label:      'Height — Feet',
                controller: _feetCtrl,
                hint:       'e.g. 5',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null || n < 0 || n > 9) return '0 – 9 ft';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormInput(
                icon:       Icons.straighten_rounded,
                label:      'Inches',
                controller: _inchesCtrl,
                hint:       'e.g. 8',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null || n < 0 || n > 11) return '0 – 11 in';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FormInput(
          icon:       Icons.monitor_weight_rounded,
          label:      'Weight (kg)',
          controller: _weightCtrl,
          hint:       'e.g. 70.5',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
          ],
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final n = double.tryParse(v);
            if (n == null || n <= 0 || n > 500) return 'Enter a valid weight';
            return null;
          },
        ),
        if (_bmiPreview != null) ...[
          const SizedBox(height: 16),
          _BmiPreviewBanner(bmi: _bmiPreview!),
        ],
      ],
    );
  }

  // ── Health section ────────────────────────────────────────────────────────
  Widget _buildHealthSection() {
    return _FormSection(
      title: 'Health Records',
      accentColor: DarkColors.amber,
      children: [
        _FormInput(
          icon:     Icons.warning_amber_rounded,
          label:    'Allergies & Conditions',
          controller: _allergyCtrl,
          hint:     'e.g. Penicillin, Peanuts, Dust…',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _FormInput(
          icon:     Icons.medication_rounded,
          label:    'Ongoing Treatment',
          controller: _treatCtrl,
          hint:     'e.g. Metformin 500mg twice daily…',
          maxLines: 3,
        ),
      ],
    );
  }

  // ── Emergency section ─────────────────────────────────────────────────────
  Widget _buildEmergencySection() {
    return _FormSection(
      title: 'Emergency Contact (ICE)',
      accentColor: DarkColors.red,
      children: [
        _FormInput(
          icon:       Icons.person_rounded,
          label:      'Contact Name',
          controller: _icNameCtrl,
          hint:       'Guardian or relative name',
        ),
        const SizedBox(height: 16),
        _FormInput(
          icon:         Icons.phone_rounded,
          label:        'Phone Number',
          controller:   _icPhoneCtrl,
          hint:         '+880 1XXX-XXXXXX',
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            if (v.replaceAll(RegExp(r'\D'), '').length < 10) {
              return 'Enter a valid phone number (min 10 digits)';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: DarkColors.accentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: DarkColors.purpleBright.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isSaving ? null : _save,
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      'Save Changes',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
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

// ══════════════════════════════════════════════════════════════════════════════
// _FormSection
// ══════════════════════════════════════════════════════════════════════════════
class _FormSection extends StatelessWidget {
  final String       title;
  final Color        accentColor;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            )),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: accentColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
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

// ══════════════════════════════════════════════════════════════════════════════
// _FormInput
// ══════════════════════════════════════════════════════════════════════════════
class _FormInput extends StatelessWidget {
  final IconData                   icon;
  final String                     label;
  final TextEditingController      controller;
  final TextInputType?             keyboardType;
  final String?                    hint;
  final int                        maxLines;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>?  inputFormatters;

  const _FormInput({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.hint,
    this.maxLines       = 1,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: DarkColors.purpleBright),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSec,
                )),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:        controller,
          keyboardType:      keyboardType,
          maxLines:          maxLines,
          inputFormatters:   inputFormatters,
          validator:         validator,
          textAlignVertical: maxLines > 1
              ? TextAlignVertical.top
              : TextAlignVertical.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: c.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: GoogleFonts.poppins(
                fontSize: 13, color: c.textMuted),
            filled:    true,
            fillColor: c.surface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical:   maxLines > 1 ? 12 : 14,
            ),
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

// ══════════════════════════════════════════════════════════════════════════════
// _DropdownField
// ══════════════════════════════════════════════════════════════════════════════
class _DropdownField extends StatelessWidget {
  final IconData             icon;
  final String               label;
  final String?              value;
  final List<String>         items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: DarkColors.purpleBright),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSec,
                )),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded:   true,
          dropdownColor: c.card,
          hint: Text('Select blood group',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: c.textMuted)),
          style: GoogleFonts.poppins(
              fontSize: 14,
              color: c.textPrimary,
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled:    true,
            fillColor: c.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          ),
          borderRadius: BorderRadius.circular(12),
          items: items
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: c.textPrimary)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _BmiPreviewBanner
// ══════════════════════════════════════════════════════════════════════════════
class _BmiPreviewBanner extends StatelessWidget {
  final double bmi;
  const _BmiPreviewBanner({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final color = _bmiColor(bmi);
    final label = _bmiLabel(bmi);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Text('BMI Preview: ',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: context.colors.textSec)),
          Text(bmi.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              )),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        color.withAlpha(22),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: color.withAlpha(60)),
            ),
            child: Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _CredentialButton
// ══════════════════════════════════════════════════════════════════════════════
class _CredentialButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _CredentialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: DarkColors.purpleBright),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  )),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DialogTextField
// ══════════════════════════════════════════════════════════════════════════════
class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String                hint;
  final TextInputType?        keyboardType;
  final bool                  autofocus;

  const _DialogTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller:   controller,
      keyboardType: keyboardType,
      autofocus:    autofocus,
      style: GoogleFonts.poppins(fontSize: 14, color: c.textPrimary),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
        filled:    true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: DarkColors.purpleBright, width: 1.5),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DialogPasswordField
// ══════════════════════════════════════════════════════════════════════════════
class _DialogPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String                hint;
  final bool                  obscure;
  final VoidCallback          onToggle;

  const _DialogPasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller:  controller,
      obscureText: obscure,
      style: GoogleFonts.poppins(fontSize: 14, color: c.textPrimary),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
        filled:    true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size:  18,
            color: c.textMuted,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: DarkColors.purpleBright, width: 1.5),
        ),
      ),
    );
  }
}
