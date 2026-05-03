// ─────────────────────────────────────────────────────────────────────────────
// profile_screen.dart — Dark futuristic profile screen for TreatTrace.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/profile_service.dart';
import '../../auth/screens/login_screen.dart';
import '../models/health_profile.dart';
import 'edit_profile_screen.dart';

// ── BMI color helper ──────────────────────────────────────────────────────────
Color _bmiColor(double bmi) {
  if (bmi < 18.5) return DarkColors.cyan;
  if (bmi < 25.0) return DarkColors.green;
  if (bmi < 30.0) return DarkColors.amber;
  return DarkColors.red;
}

// ══════════════════════════════════════════════════════════════════════════════
// ProfileScreen
// ══════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  final void Function(String) onThemeChanged;
  final void Function(String) onLocaleChanged;
  final String currentTheme;
  final String currentLocale;

  const ProfileScreen({
    super.key,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.currentTheme,
    required this.currentLocale,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService    = AuthService();
  final _profileService = ProfileService();
  final _accountService = AccountService();
  final _imagePicker    = ImagePicker();

  bool            _isLoading     = true;
  HealthProfile?  _health;
  Map<String, dynamic>? _account;
  String?         _avatarUrl;
  bool            _uploadingAvatar = false;

  String get _displayName {
    final fromAccount = _account?['full_name'] as String?;
    if (fromAccount != null && fromAccount.isNotEmpty) return fromAccount;
    final meta = _authService.currentUser?.userMetadata;
    return (meta?['full_name'] as String?) ?? 'Your Name';
  }

  String get _email =>
      _authService.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _profileService.fetchHealthProfile(),
        _accountService.fetchProfile(),
      ]);
      _health   = results[0] as HealthProfile?;
      _account  = results[1] as Map<String, dynamic>?;
      _avatarUrl = _account?['avatar_url'] as String?;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToEdit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          existing:       _health,
          accountData:    _account,
        ),
      ),
    );
    if (saved == true) _loadAll();
  }

  // ── Avatar picker ─────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final url = await _accountService.uploadAvatar(picked);
      setState(() => _avatarUrl = url);
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload photo. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Choose photo source',
            style: GoogleFonts.poppins(
                color: DarkColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo_library_rounded,
                color: DarkColors.purpleBright),
            label: Text('Gallery',
                style: GoogleFonts.poppins(color: DarkColors.purpleBright)),
            onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          TextButton.icon(
            icon: const Icon(Icons.camera_alt_rounded,
                color: DarkColors.cyan),
            label: Text('Camera',
                style: GoogleFonts.poppins(color: DarkColors.cyan)),
            onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
        ],
      ),
    );
  }

  // ── Account dialogs ───────────────────────────────────────────────────────
  Future<void> _showChangePasswordDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Password',
            style: GoogleFonts.poppins(
                color: DarkColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextFormField(
          controller: ctrl,
          obscureText: true,
          style: GoogleFonts.poppins(color: DarkColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'New password (min 8 chars)',
            hintStyle: GoogleFonts.poppins(color: DarkColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: DarkColors.textSec))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Update',
                  style: GoogleFonts.poppins(
                      color: DarkColors.purpleBright,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().length >= 8) {
      try {
        await _accountService.updatePassword(ctrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Password updated successfully.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')));
        }
      }
    }
    ctrl.dispose();
  }

  Future<void> _showChangeEmailDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Email',
            style: GoogleFonts.poppins(
                color: DarkColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.poppins(color: DarkColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'New email address',
                hintStyle: GoogleFonts.poppins(color: DarkColors.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A confirmation email will be sent to the new address.',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: DarkColors.textSec),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: DarkColors.textSec))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Send',
                  style: GoogleFonts.poppins(
                      color: DarkColors.purpleBright,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await _accountService.updateEmail(ctrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Confirmation email sent. Check your new inbox.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
    ctrl.dispose();
  }

  Future<void> _showChangePhoneDialog() async {
    final ctrl = TextEditingController(
        text: _account?['phone'] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Phone Number',
            style: GoogleFonts.poppins(
                color: DarkColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.poppins(color: DarkColors.textPrimary),
          decoration: InputDecoration(
            hintText: '+880 1XXX-XXXXXX',
            hintStyle: GoogleFonts.poppins(color: DarkColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: DarkColors.textSec))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Save',
                  style: GoogleFonts.poppins(
                      color: DarkColors.purpleBright,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _accountService.updatePhone(ctrl.text.trim());
        setState(() {
          _account = {...?_account, 'phone': ctrl.text.trim()};
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone number updated.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
    ctrl.dispose();
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Out',
            style: GoogleFonts.poppins(
                color: DarkColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.poppins(
                fontSize: 13, color: DarkColors.textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: DarkColors.textSec))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Log Out',
                  style: GoogleFonts.poppins(
                      color: DarkColors.red,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final s = S.of(context);

    return Scaffold(
      backgroundColor: DarkColors.bg,
      body: Column(
        children: [
          _buildHeader(MediaQuery.of(context).padding.top),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: DarkColors.purpleBright))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Medical Identity
                        _SectionLabel(text: s.medicalIdentity),
                        const SizedBox(height: 12),
                        _MedicalIdentityCard(
                          profile:  _health,
                          onAddTap: _goToEdit,
                        ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.06),

                        const SizedBox(height: 24),

                        // 2. Health Records
                        _SectionLabel(text: s.healthRecords),
                        const SizedBox(height: 12),
                        _HealthRecordsCard(
                          profile:   _health,
                          onEditTap: _goToEdit,
                        ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.06),

                        const SizedBox(height: 24),

                        // 3. Emergency Contact
                        _SectionLabel(text: s.emergencyContact),
                        const SizedBox(height: 12),
                        _EmergencyContactCard(
                          profile:  _health,
                          onAddTap: _goToEdit,
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06),

                        const SizedBox(height: 24),

                        // 4. Account Settings (NEW)
                        _SectionLabel(text: s.accountSettings),
                        const SizedBox(height: 12),
                        _AccountSettingsCard(
                          onChangePassword: _showChangePasswordDialog,
                          onChangeEmail:    _showChangeEmailDialog,
                          onChangePhone:    _showChangePhoneDialog,
                        ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.06),

                        const SizedBox(height: 24),

                        // 5. App Settings
                        _SectionLabel(text: s.settings),
                        const SizedBox(height: 12),
                        _AppSettingsCard(
                          currentTheme:    widget.currentTheme,
                          currentLocale:   widget.currentLocale,
                          onThemeChanged:  widget.onThemeChanged,
                          onLocaleChanged: widget.onLocaleChanged,
                          onLogout:        _confirmLogout,
                        ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.06),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Dark profile header ───────────────────────────────────────────────────
  Widget _buildHeader(double topPad) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DarkColors.card, DarkColors.surface],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        border: Border(
          bottom: BorderSide(color: DarkColors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        top:    topPad + 14,
        left:   24,
        right:  24,
        bottom: 32,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: _HeaderIconBtn(icon: Icons.arrow_back_rounded),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _goToEdit,
                child: _HeaderIconBtn(icon: Icons.edit_rounded),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Avatar with gradient ring + camera badge
          Stack(
            children: [
              // Gradient ring around avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: DarkColors.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: DarkColors.purpleBright.withAlpha(60),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: _uploadingAvatar
                      ? Container(
                          color: DarkColors.card,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: DarkColors.purpleBright,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, s) => _defaultAvatar(),
                            )
                          : _defaultAvatar(),
                ),
              ),

              // Camera badge
              Positioned(
                bottom: 0,
                right:  0,
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: DarkColors.accentGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: DarkColors.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            _displayName,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: DarkColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            _email,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: DarkColors.textSec,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05);
  }

  Widget _defaultAvatar() {
    return Container(
      color: DarkColors.card,
      child: const Icon(Icons.person_rounded,
          size: 54, color: DarkColors.textMuted),
    );
  }
}

// ── Header icon button ────────────────────────────────────────────────────────
class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  const _HeaderIconBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: DarkColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DarkColors.border, width: 1),
      ),
      child: Icon(icon, color: DarkColors.textSec, size: 20),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: DarkColors.textPrimary,
        ),
      );
}

// ── Dark card shell ───────────────────────────────────────────────────────────
// Uses ClipRRect + IntrinsicHeight so the left accent bar always stretches to
// full card height without mixing non-uniform Border with borderRadius (which
// Flutter does not support and causes children to paint as blank blocks).
class _DarkCard extends StatelessWidget {
  final Widget child;
  final Color  accentColor;
  final EdgeInsetsGeometry? padding;

  const _DarkCard({
    required this.child,
    required this.accentColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DarkColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DarkColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar — stretches to full card height.
              Container(width: 4, color: accentColor),
              // Card content.
              Expanded(
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty banner ──────────────────────────────────────────────────────────────
class _EmptyBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onTap;

  const _EmptyBanner({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: DarkColors.borderLight,
            width: 1.5,
            // dashed border via CustomPainter would be ideal but Border works fine
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: DarkColors.purpleBright, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: DarkColors.textSec),
              ),
            ),
            Text(
              S.of(context).addInfo,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: DarkColors.purpleBright,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _MedicalIdentityCard
// ══════════════════════════════════════════════════════════════════════════════
class _MedicalIdentityCard extends StatelessWidget {
  final HealthProfile? profile;
  final VoidCallback   onAddTap;

  const _MedicalIdentityCard({required this.profile, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    final hasData = profile != null && profile!.hasVitals;

    return _DarkCard(
      accentColor: DarkColors.cyan,
      child: Column(
        children: [
          if (!hasData)
            _EmptyBanner(
              message: 'No medical information yet. Tap to add your vitals.',
              onTap: onAddTap,
            )
          else ...[
            Row(
              children: [
                Expanded(child: _InfoBlock(
                  icon: Icons.bloodtype_rounded,
                  iconColor: DarkColors.red,
                  label: 'Blood Group',
                  value: profile!.bloodGroup ?? '—',
                )),
                const SizedBox(width: 12),
                Expanded(child: _InfoBlock(
                  icon: Icons.cake_rounded,
                  iconColor: DarkColors.purpleBright,
                  label: 'Age',
                  value: profile!.ageDisplay,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _InfoBlock(
                  icon: Icons.height_rounded,
                  iconColor: DarkColors.cyan,
                  label: 'Height',
                  value: profile!.heightDisplay,
                )),
                const SizedBox(width: 12),
                Expanded(child: _InfoBlock(
                  icon: Icons.monitor_weight_rounded,
                  iconColor: DarkColors.green,
                  label: 'Weight',
                  value: profile!.weightDisplay,
                )),
              ],
            ),
            if (profile!.bmi != null) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: DarkColors.border, thickness: 1),
              const SizedBox(height: 16),
              _BmiRow(bmi: profile!.bmi!, label: profile!.bmiLabel),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;

  const _InfoBlock({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DarkColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DarkColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: DarkColors.textMuted)),
                const SizedBox(height: 1),
                Text(value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DarkColors.textPrimary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiRow extends StatelessWidget {
  final double bmi;
  final String label;

  const _BmiRow({required this.bmi, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _bmiColor(bmi);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.analytics_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Body Mass Index (BMI)',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: DarkColors.textMuted)),
            const SizedBox(height: 2),
            Text(bmi.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: DarkColors.textPrimary,
                )),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Text(label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              )),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HealthRecordsCard
// ══════════════════════════════════════════════════════════════════════════════
class _HealthRecordsCard extends StatelessWidget {
  final HealthProfile? profile;
  final VoidCallback   onEditTap;

  const _HealthRecordsCard({required this.profile, required this.onEditTap});

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      accentColor: DarkColors.amber,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _RecordTile(
            icon:      Icons.warning_amber_rounded,
            iconColor: DarkColors.amber,
            title:     'Allergies & Conditions',
            subtitle:  profile?.allergies?.isNotEmpty == true
                ? profile!.allergies!
                : 'Not added — tap edit to update',
            isFirst:   true,
            onTap:     onEditTap,
          ),
          Divider(height: 1, indent: 20, endIndent: 20,
              color: DarkColors.border, thickness: 1),
          _RecordTile(
            icon:      Icons.medication_rounded,
            iconColor: DarkColors.green,
            title:     'Ongoing Treatment',
            subtitle:  profile?.ongoingTreatment?.isNotEmpty == true
                ? profile!.ongoingTreatment!
                : 'Not added — tap edit to update',
            isLast:    true,
            onTap:     onEditTap,
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;
  final bool         isFirst;
  final bool         isLast;

  const _RecordTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFirst = false,
    this.isLast  = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top:    isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast  ? const Radius.circular(20) : Radius.zero,
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: DarkColors.textPrimary,
                        )),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: subtitle.contains('Not added')
                              ? DarkColors.textMuted
                              : DarkColors.textSec,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: DarkColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _EmergencyContactCard
// ══════════════════════════════════════════════════════════════════════════════
class _EmergencyContactCard extends StatelessWidget {
  final HealthProfile? profile;
  final VoidCallback   onAddTap;

  const _EmergencyContactCard(
      {required this.profile, required this.onAddTap});

  bool get _hasContact => profile != null && profile!.hasEmergencyContact;

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      accentColor: DarkColors.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: DarkColors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emergency_rounded,
                    color: DarkColors.red, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Emergency Contact',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DarkColors.red,
                      )),
                  Text('In Case of Emergency (ICE)',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: DarkColors.red.withAlpha(180))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_hasContact)
            _EmptyBanner(
              message: 'No emergency contact set. Tap to add one.',
              onTap: onAddTap,
            )
          else ...[
            _ContactRow(
                icon: Icons.person_rounded,
                label: 'Contact Name',
                value: profile!.emergencyName ?? '—'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ContactRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone Number',
                      value: profile!.emergencyPhone ?? '—'),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: DarkColors.green,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.call_rounded,
                      color: Colors.white, size: 22),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _ContactRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DarkColors.red),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: DarkColors.red.withAlpha(180))),
            Text(value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DarkColors.textPrimary,
                )),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AccountSettingsCard — change password / email / phone
// ══════════════════════════════════════════════════════════════════════════════
class _AccountSettingsCard extends StatelessWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onChangeEmail;
  final VoidCallback onChangePhone;

  const _AccountSettingsCard({
    required this.onChangePassword,
    required this.onChangeEmail,
    required this.onChangePhone,
  });

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      accentColor: DarkColors.green,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingsTile(
            icon:      Icons.lock_reset_rounded,
            iconColor: DarkColors.green,
            title:     'Change Password',
            onTap:     onChangePassword,
            isFirst:   true,
          ),
          Divider(height: 1, indent: 16, endIndent: 16,
              color: DarkColors.border, thickness: 1),
          _SettingsTile(
            icon:      Icons.email_rounded,
            iconColor: DarkColors.cyan,
            title:     'Change Email',
            onTap:     onChangeEmail,
          ),
          Divider(height: 1, indent: 16, endIndent: 16,
              color: DarkColors.border, thickness: 1),
          _SettingsTile(
            icon:      Icons.phone_rounded,
            iconColor: DarkColors.amber,
            title:     'Change Phone Number',
            onTap:     onChangePhone,
            isLast:    true,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AppSettingsCard — theme selector, language, logout
// ══════════════════════════════════════════════════════════════════════════════
class _AppSettingsCard extends StatelessWidget {
  final String currentTheme;
  final String currentLocale;
  final void Function(String) onThemeChanged;
  final void Function(String) onLocaleChanged;
  final VoidCallback onLogout;

  const _AppSettingsCard({
    required this.currentTheme,
    required this.currentLocale,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      accentColor: DarkColors.purpleBright,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Theme selector ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: DarkColors.purpleBright.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dark_mode_rounded,
                      color: DarkColors.purpleBright, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: DarkColors.textPrimary,
                          )),
                      Text('System / Light / Dark',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: DarkColors.textMuted)),
                    ],
                  ),
                ),
                // 3-way theme selector
                _ThemeSelector(
                  current:   currentTheme,
                  onChanged: onThemeChanged,
                ),
              ],
            ),
          ),

          Divider(height: 1, indent: 16, endIndent: 16,
              color: DarkColors.border, thickness: 1),

          // ── Language picker ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: DarkColors.cyan.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language_rounded,
                      color: DarkColors.cyan, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Language',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: DarkColors.textPrimary,
                          )),
                      Text('English / বাংলা',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: DarkColors.textMuted)),
                    ],
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentLocale,
                    dropdownColor: DarkColors.card,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: DarkColors.purpleBright,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: DarkColors.purpleBright, size: 18),
                    borderRadius: BorderRadius.circular(12),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                    ],
                    onChanged: (v) {
                      if (v != null) onLocaleChanged(v);
                    },
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, indent: 16, endIndent: 16,
              color: DarkColors.border, thickness: 1),

          // ── Logout ─────────────────────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              onTap: onLogout,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: DarkColors.red.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: DarkColors.red, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text('Log Out',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: DarkColors.red,
                        )),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: DarkColors.red, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3-way theme selector chip row ─────────────────────────────────────────────
class _ThemeSelector extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;

  const _ThemeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeChip(
          label: 'Auto',
          icon: Icons.brightness_auto_rounded,
          selected: current == 'system',
          onTap: () => onChanged('system'),
        ),
        const SizedBox(width: 6),
        _ThemeChip(
          label: 'Light',
          icon: Icons.light_mode_rounded,
          selected: current == 'light',
          onTap: () => onChanged('light'),
        ),
        const SizedBox(width: 6),
        _ThemeChip(
          label: 'Dark',
          icon: Icons.dark_mode_rounded,
          selected: current == 'dark',
          onTap: () => onChanged('dark'),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? DarkColors.purpleBright.withAlpha(30)
              : DarkColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? DarkColors.purpleBright : DarkColors.border,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected ? DarkColors.purpleBright : DarkColors.textMuted,
        ),
      ),
    );
  }
}

// ── Generic settings tile ─────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       title;
  final VoidCallback onTap;
  final bool         isFirst;
  final bool         isLast;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.isFirst = false,
    this.isLast  = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top:    isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast  ? const Radius.circular(20) : Radius.zero,
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DarkColors.textPrimary,
                    )),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: DarkColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
