import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'my_patients_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  final void Function(String) onThemeChanged;
  final void Function(String) onLocaleChanged;
  final String currentTheme;
  final String currentLocale;
  final String verificationStatus;

  const DoctorHomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.currentTheme,
    required this.currentLocale,
    this.verificationStatus = 'approved',
  });

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final _authService = AuthService();
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final profile = await _authService.fetchProfile();
    if (mounted) setState(() => _avatarUrl = profile?['avatar_url'] as String?);
  }

  String get _firstName {
    final meta = _authService.currentUser?.userMetadata;
    final full = meta?['full_name'] as String?;
    return full?.split(' ').first ?? 'Doctor';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _goMyPatients() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyPatientsScreen()),
    );
  }

  Future<void> _goToProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          onThemeChanged: widget.onThemeChanged,
          onLocaleChanged: widget.onLocaleChanged,
          currentTheme: widget.currentTheme,
          currentLocale: widget.currentLocale,
        ),
      ),
    );
    _loadAvatar();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Coming soon!',
            style: GoogleFonts.poppins(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Out',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.textPrimary)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log Out',
                style: GoogleFonts.poppins(
                    color: c.red, fontWeight: FontWeight.w700)),
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
          _DoctorHeader(
            greeting: _greeting,
            firstName: _firstName,
            onLogout: _confirmLogout,
            verificationStatus: widget.verificationStatus,
          ),
          Expanded(
            child: widget.verificationStatus == 'pending'
                ? _PendingBody()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatsRow().animate().fadeIn(delay: 100.ms),

                        const SizedBox(height: 28),

                        Text(
                          'Quick Actions',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ).animate().fadeIn(delay: 140.ms),

                        const SizedBox(height: 16),

                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _ActionCard(
                                  icon: Icons.calendar_today_rounded,
                                  label: "Today's Schedule",
                                  subtitle: 'View appointments',
                                  accentColor: c.accent,
                                  onTap: () => _showComingSoon("Today's Schedule"),
                                ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _ActionCard(
                                  icon: Icons.people_alt_rounded,
                                  label: 'My Patients',
                                  subtitle: 'Patient records',
                                  accentColor: c.green,
                                  onTap: _goMyPatients,
                                ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.08),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _ActionCard(
                                  icon: Icons.edit_document,
                                  label: 'Write Prescription',
                                  subtitle: 'Select a patient',
                                  accentColor: c.amber,
                                  onTap: _goMyPatients,
                                ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.08),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _ActionCard(
                                  icon: Icons.science_rounded,
                                  label: 'Test Reports',
                                  subtitle: 'Lab results',
                                  accentColor: c.red,
                                  onTap: () => _showComingSoon('Test Reports'),
                                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _DoctorBottomBar(
        onProfileTap: _goToProfile,
        avatarUrl: _avatarUrl,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DoctorHeader
// ══════════════════════════════════════════════════════════════════════════════
class _DoctorHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final VoidCallback onLogout;
  final String verificationStatus;

  const _DoctorHeader({
    required this.greeting,
    required this.firstName,
    required this.onLogout,
    required this.verificationStatus,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: topPad + 18,
        left: 24,
        right: 24,
        bottom: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: c.textSec,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dr. $firstName',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HeaderIcon(icon: Icons.notifications_outlined),
              const SizedBox(width: 10),
              _HeaderIcon(icon: Icons.logout_rounded, onTap: onLogout),
            ],
          ),
          const SizedBox(height: 20),
          // Verification status badge
          _VerificationBadge(status: verificationStatus),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.06, end: 0, duration: 500.ms);
  }
}

class _VerificationBadge extends StatelessWidget {
  final String status;
  const _VerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPending  = status == 'pending';
    final badgeColor = isPending ? c.amber : c.green;
    final icon       = isPending ? Icons.hourglass_top_rounded : Icons.verified_rounded;
    final label      = isPending ? 'Pending Verification' : 'Verified Healthcare Professional';
    final badge      = isPending ? 'Pending' : 'Doctor';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: badgeColor.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: badgeColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge,
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
          ),
        ],
      ),
    );
  }
}

class _PendingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: c.amber.withAlpha(15),
                shape: BoxShape.circle,
                border: Border.all(color: c.amber.withAlpha(50)),
              ),
              child: Icon(Icons.hourglass_top_rounded, color: c.amber, size: 38),
            ),
            const SizedBox(height: 24),
            Text('Verification Pending',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 10),
            Text(
              'Your medical credentials are under review by our admin team. '
              'You will get full access once approved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textSec, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Icon(icon, color: c.textSec, size: 21),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _StatsRow
// ══════════════════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            icon: Icons.event_available_rounded,
            label: "Today's\nAppointments",
            value: '0',
            color: context.colors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatPill(
            icon: Icons.people_alt_rounded,
            label: 'Total\nPatients',
            value: '0',
            color: context.colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatPill(
            icon: Icons.pending_actions_rounded,
            label: 'Pending\nTasks',
            value: '0',
            color: context.colors.amber,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: c.textSec,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ActionCard
// ══════════════════════════════════════════════════════════════════════════════
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        splashColor: accentColor.withAlpha(15),
        highlightColor: accentColor.withAlpha(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: accentColor.withAlpha(40), width: 1),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: c.textSec),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DoctorBottomBar
// ══════════════════════════════════════════════════════════════════════════════
class _DoctorBottomBar extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final String? avatarUrl;

  const _DoctorBottomBar({this.onProfileTap, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomPad + 14,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        border: Border(top: BorderSide(color: c.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Doctor badge
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_services_rounded,
                      color: c.green, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Doctor Portal',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Profile button
          GestureDetector(
            onTap: onProfileTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: avatarUrl != null
                          ? c.accent.withAlpha(120)
                          : c.border,
                      width: avatarUrl != null ? 1.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => Icon(
                              Icons.person_rounded,
                              color: c.accent,
                              size: 22,
                            ),
                          )
                        : Icon(Icons.person_rounded, color: c.accent, size: 22),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'My\nProfile',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: c.textSec,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.06);
  }
}
