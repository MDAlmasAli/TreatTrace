// ─────────────────────────────────────────────────────────────────────────────
// profile_screen.dart
//
// User profile screen for TreatTrace.
//
// Data flow:
//   initState → ProfileService.fetchHealthProfile()
//     ├─ null    → new user, no row exists yet   → show empty states
//     └─ profile → existing data                 → show real values
//
//   Edit button → EditProfileScreen (pre-filled)
//     └─ returns true on save → reload profile
//
// Sections:
//   1. Header              — avatar, name, profession, edit button
//   2. Medical Identity    — vitals grid + auto BMI
//   3. Health Records      — allergies, ongoing treatment
//   4. Emergency Contact   — ICE card (red tint)
//   5. Settings            — dark mode toggle, language, logout
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/profile_service.dart';
import '../../auth/screens/login_screen.dart';
import '../models/health_profile.dart';
import 'edit_profile_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _deepBlue  = Color(0xFF2563EB);
const Color _blueBg    = Color(0xFFEEF2FF);
const Color _blueBorder = Color(0xFFBFD7FF);
const Color _textDark  = Color(0xFF1E293B);
const Color _textMid   = Color(0xFF475569);
const Color _textLight = Color(0xFF94A3B8);

Color _bmiColor(double bmi) {
  if (bmi < 18.5) return const Color(0xFF3B82F6);
  if (bmi < 25.0) return const Color(0xFF22C55E);
  if (bmi < 30.0) return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}

// ══════════════════════════════════════════════════════════════════════════════
// ProfileScreen
// ══════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService    = AuthService();
  final _profileService = ProfileService();

  // ── State ─────────────────────────────────────────────────────────────────
  bool           _isLoading = true;
  HealthProfile? _profile;
  bool           _darkMode  = false;
  String         _language  = 'English';

  // ── Getters ───────────────────────────────────────────────────────────────
  String get _displayName {
    final meta = _authService.currentUser?.userMetadata;
    return (meta?['full_name'] as String?) ?? 'Your Name';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      _profile = await _profileService.fetchHealthProfile();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  Future<void> _goToEdit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(existing: _profile),
      ),
    );
    if (saved == true) _loadProfile();
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Log Out',
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 20, color: _textDark)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.dmSans(fontSize: 13, color: _textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: _textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log Out',
                style: GoogleFonts.dmSans(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          _buildProfileHeader(MediaQuery.of(context).padding.top),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _deepBlue),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Medical Identity
                        const _SectionLabel(text: 'Medical Identity'),
                        const SizedBox(height: 12),
                        _MedicalIdentityCard(
                          profile:  _profile,
                          onAddTap: _goToEdit,
                        ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.06),

                        const SizedBox(height: 24),

                        // 2. Health Records
                        const _SectionLabel(text: 'Health Records'),
                        const SizedBox(height: 12),
                        _HealthRecordsCard(
                          profile:  _profile,
                          onEditTap: _goToEdit,
                        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.06),

                        const SizedBox(height: 24),

                        // 3. Emergency Contact
                        const _SectionLabel(text: 'Emergency Contact (ICE)'),
                        const SizedBox(height: 12),
                        _EmergencyContactCard(
                          profile:  _profile,
                          onAddTap: _goToEdit,
                        ).animate().fadeIn(delay: 210.ms).slideY(begin: 0.06),

                        const SizedBox(height: 24),

                        // 4. Settings
                        const _SectionLabel(text: 'Settings & Preferences'),
                        const SizedBox(height: 12),
                        _SettingsCard(
                          darkMode:          _darkMode,
                          onDarkModeToggle:  (v) => setState(() => _darkMode = v),
                          language:          _language,
                          onLanguageChanged: (v) =>
                              setState(() => _language = v ?? _language),
                          onLogout: _confirmLogout,
                        ).animate().fadeIn(delay: 270.ms).slideY(begin: 0.06),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Blue profile header ───────────────────────────────────────────────────
  Widget _buildProfileHeader(double topPad) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top:    topPad + 14,
        left:   24,
        right:  24,
        bottom: 32,
      ),
      decoration: const BoxDecoration(
        color: _deepBlue,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Top row: back (left) + edit (right)
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

          // Circular avatar with camera badge
          Stack(
            children: [
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(30),
                  border: Border.all(
                      color: Colors.white.withAlpha(100), width: 3),
                ),
                child: const Icon(Icons.person_rounded,
                    size: 54, color: Colors.white),
              ),
              Positioned(
                bottom: 0,
                right:  0,
                child: GestureDetector(
                  onTap: _goToEdit,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF60A5FA),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            _displayName,
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 24, color: Colors.white),
          ),

          const SizedBox(height: 5),

          Text(
            'General Patient',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white.withAlpha(210),
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color:  Colors.white.withAlpha(22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: Text(
              'TreatTrace Member',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.white.withAlpha(220),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05);
  }
}

// Small icon button used in the blue header.
class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  const _HeaderIconBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(45)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SectionLabel
// ══════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.dmSerifDisplay(fontSize: 18, color: _textDark),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// _ProfileCard — shared white card shell.
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileCard extends StatelessWidget {
  final Widget             child;
  final EdgeInsetsGeometry? padding;

  const _ProfileCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFE8EFFF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _deepBlue.withAlpha(14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _EmptyBanner — shown inside a card when a section has no data yet.
// ══════════════════════════════════════════════════════════════════════════════
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
          color: _blueBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _blueBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline_rounded,
                color: _deepBlue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: _textMid),
              ),
            ),
            Text(
              'Add Info',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _deepBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _MedicalIdentityCard — 2×2 vitals grid + auto-calculated BMI row.
// ══════════════════════════════════════════════════════════════════════════════
class _MedicalIdentityCard extends StatelessWidget {
  final HealthProfile? profile;
  final VoidCallback   onAddTap;

  const _MedicalIdentityCard({
    required this.profile,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = profile != null && profile!.hasVitals;

    return _ProfileCard(
      child: Column(
        children: [
          if (!hasData)
            _EmptyBanner(
              message:
                  'No medical information yet. Tap to add your health details.',
              onTap: onAddTap,
            )
          else ...[
            // Row 1
            Row(
              children: [
                Expanded(
                  child: _InfoBlock(
                    icon:      Icons.bloodtype_rounded,
                    iconColor: const Color(0xFFEF4444),
                    iconBg:    const Color(0xFFFEE2E2),
                    label:     'Blood Group',
                    value:     profile!.bloodGroup ?? '—',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoBlock(
                    icon:      Icons.cake_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    iconBg:    const Color(0xFFEDE9FE),
                    label:     'Age',
                    value:     profile!.ageDisplay,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2
            Row(
              children: [
                Expanded(
                  child: _InfoBlock(
                    icon:      Icons.height_rounded,
                    iconColor: const Color(0xFF0EA5E9),
                    iconBg:    const Color(0xFFE0F2FE),
                    label:     'Height',
                    value:     profile!.heightDisplay,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoBlock(
                    icon:      Icons.monitor_weight_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg:    const Color(0xFFD1FAE5),
                    label:     'Weight',
                    value:     profile!.weightDisplay,
                  ),
                ),
              ],
            ),

            // BMI row — only when both height and weight are available
            if (profile!.bmi != null) ...[
              const SizedBox(height: 16),
              const Divider(
                  height: 1,
                  color: Color(0xFFEEF2FF),
                  thickness: 1.5),
              const SizedBox(height: 16),
              _BmiRow(
                bmi:   profile!.bmi!,
                label: profile!.bmiLabel,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// Single stat block used inside the medical identity grid.
class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   label;
  final String   value;

  const _InfoBlock({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blueBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
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
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: _textLight)),
                const SizedBox(height: 1),
                Text(value,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// BMI summary row inside the medical identity card.
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
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.analytics_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Body Mass Index (BMI)',
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: _textLight)),
            const SizedBox(height: 2),
            Text(bmi.toStringAsFixed(1),
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 22, color: _textDark)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:  color.withAlpha(22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HealthRecordsCard — allergies + ongoing treatment tiles.
// ══════════════════════════════════════════════════════════════════════════════
class _HealthRecordsCard extends StatelessWidget {
  final HealthProfile? profile;
  final VoidCallback   onEditTap;

  const _HealthRecordsCard({
    required this.profile,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _RecordTile(
            icon:      Icons.warning_amber_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBg:    const Color(0xFFFEF3C7),
            title:     'Allergies & Conditions',
            subtitle:  profile?.allergies?.isNotEmpty == true
                ? profile!.allergies!
                : 'Not added — tap edit to update',
            isFirst:   true,
            onTap:     onEditTap,
          ),
          const Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: Color(0xFFEEF2FF),
              thickness: 1),
          _RecordTile(
            icon:      Icons.medication_rounded,
            iconColor: const Color(0xFF059669),
            iconBg:    const Color(0xFFD1FAE5),
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
  final Color        iconBg;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;
  final bool         isFirst;
  final bool         isLast;

  const _RecordTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
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
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
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
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        )),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: subtitle.contains('Not added')
                            ? _textLight
                            : _textMid,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: _textLight, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _EmergencyContactCard — light red ICE card.
// ══════════════════════════════════════════════════════════════════════════════
class _EmergencyContactCard extends StatelessWidget {
  final HealthProfile? profile;
  final VoidCallback   onAddTap;

  const _EmergencyContactCard({
    required this.profile,
    required this.onAddTap,
  });

  bool get _hasContact =>
      profile != null && profile!.hasEmergencyContact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFFCDD2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withAlpha(20),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCDD2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emergency_rounded,
                    color: Color(0xFFEF4444), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Emergency Contact',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB91C1C),
                      )),
                  Text('In Case of Emergency (ICE)',
                      style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFFEF4444))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Content: empty state OR actual contact
          if (!_hasContact)
            _EmptyBanner(
              message:
                  'No emergency contact set. Tap to add one.',
              onTap: onAddTap,
            )
          else ...[
            _ContactRow(
              icon:  Icons.person_rounded,
              label: 'Contact Name',
              value: profile!.emergencyName ?? '—',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ContactRow(
                    icon:  Icons.phone_rounded,
                    label: 'Phone Number',
                    value: profile!.emergencyPhone ?? '—',
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
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

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: const Color(0xFFEF4444))),
            Text(value,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB91C1C),
                )),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SettingsCard — dark mode, language picker, logout.
// ══════════════════════════════════════════════════════════════════════════════
class _SettingsCard extends StatelessWidget {
  final bool                  darkMode;
  final ValueChanged<bool>    onDarkModeToggle;
  final String                language;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback          onLogout;

  const _SettingsCard({
    required this.darkMode,
    required this.onDarkModeToggle,
    required this.language,
    required this.onLanguageChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Dark mode toggle
          SwitchListTile.adaptive(
            value:            darkMode,
            onChanged:        onDarkModeToggle,
            activeThumbColor: _deepBlue,
            activeTrackColor: _deepBlue.withAlpha(80),
            title: Text('Dark Mode',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                )),
            subtitle: Text('Toggle dark theme',
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: _textLight)),
            secondary: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withAlpha(12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dark_mode_rounded,
                  color: Color(0xFF1E293B), size: 20),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft:  Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
          ),

          const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Color(0xFFEEF2FF),
              thickness: 1),

          // Language selector
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language_rounded,
                      color: Color(0xFF0EA5E9), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Language',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          )),
                      Text('Choose your preferred language',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: _textLight)),
                    ],
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: language,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: _deepBlue,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _deepBlue,
                        size: 18),
                    borderRadius: BorderRadius.circular(12),
                    items: const [
                      DropdownMenuItem(
                          value: 'English',
                          child: Text('English')),
                      DropdownMenuItem(
                          value: 'Bangla',
                          child: Text('বাংলা')),
                    ],
                    onChanged: onLanguageChanged,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Color(0xFFEEF2FF),
              thickness: 1),

          // Logout row
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              onTap: onLogout,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Color(0xFFEF4444), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text('Logout',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        )),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFEF4444), size: 22),
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
