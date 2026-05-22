// ─────────────────────────────────────────────────────────────────────────────
// home_screen.dart — Dark futuristic dashboard for TreatTrace.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../prescription/screens/prescriptions_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../test_report/screens/lab_reports_screen.dart';
import '../../appointment/screens/appointments_screen.dart';
import '../../search/screens/global_search_screen.dart';
import '../../doctor_home/services/doctor_patient_link_service.dart';
import '../../doctor_home/screens/linked_doctors_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HomeScreen
// ══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final void Function(String) onThemeChanged;
  final void Function(String) onLocaleChanged;
  final String currentTheme;
  final String currentLocale;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.currentTheme,
    required this.currentLocale,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService  = AuthService();
  final _linkSvc      = DoctorPatientLinkService();
  final _searchCtrl   = TextEditingController();
  String? _avatarUrl;
  int     _pendingDoctorRequests = 0;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadPendingCount();
  }

  Future<void> _loadAvatar() async {
    final profile = await _authService.fetchProfile();
    if (mounted) setState(() => _avatarUrl = profile?['avatar_url'] as String?);
  }

  Future<void> _loadPendingCount() async {
    final count = await _linkSvc.countPendingIncoming();
    if (mounted) setState(() => _pendingDoctorRequests = count);
  }

  String get _firstName {
    final meta = _authService.currentUser?.userMetadata;
    final full = meta?['full_name'] as String?;
    return full?.split(' ').first ?? 'User';
  }

  String get _greeting {
    final s = S.of(context);
    final h = DateTime.now().hour;
    if (h < 12) return s.goodMorning;
    if (h < 17) return s.goodAfternoon;
    return s.goodEvening;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToPrescriptions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrescriptionsScreen()),
    );
  }

  Future<void> _goToTestReports() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LabReportsScreen()),
    );
  }

  Future<void> _goToDoctors() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LinkedDoctorsScreen()),
    );
    _loadPendingCount();
  }

  Future<void> _goToSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
    );
  }

  Future<void> _goToAppointments() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
    );
  }

  Future<void> _goToProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          onThemeChanged:  widget.onThemeChanged,
          onLocaleChanged: widget.onLocaleChanged,
          currentTheme:    widget.currentTheme,
          currentLocale:   widget.currentLocale,
        ),
      ),
    );
    _loadAvatar();
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
            style: GoogleFonts.poppins(
                fontSize: 13, color: c.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: c.textSec)),
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

    final s = S.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _HomeHeader(
            greeting:  _greeting,
            firstName: _firstName,
            onLogout:  _confirmLogout,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section heading
                  Text(
                    s.quickActions,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 16),

                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _PrescriptionCard(
                            label: s.prescription,
                            onTap: _goToPrescriptions,
                          )
                              .animate()
                              .fadeIn(delay: 150.ms)
                              .slideY(begin: 0.08),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TestReportCard(
                            label: s.testReport,
                            onTap: _goToTestReports,
                          )
                              .animate()
                              .fadeIn(delay: 200.ms)
                              .slideY(begin: 0.08),
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
                          child: _DoctorsCard(
                            label:        s.myDoctors,
                            onTap:        _goToDoctors,
                            animDelay:    250,
                            pendingCount: _pendingDoctorRequests,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _AppointmentsCard(
                            label:    s.appointments,
                            onTap:    _goToAppointments,
                            animDelay: 300,
                          ),
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
      bottomNavigationBar: _BottomBar(
        searchCtrl:   _searchCtrl,
        onSearchTap:  _goToSearch,
        onProfileTap: _goToProfile,
        avatarUrl:    _avatarUrl,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HomeHeader
// ══════════════════════════════════════════════════════════════════════════════
class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final VoidCallback onLogout;

  const _HomeHeader({
    required this.greeting,
    required this.firstName,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(
          bottom: BorderSide(color: c.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top:    topPad + 18,
        left:   24,
        right:  24,
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
                      'Welcome, $firstName!',
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

          // Daily tip banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.accent.withAlpha(12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.accent.withAlpha(50), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.amber.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.tips_and_updates_rounded,
                      color: c.amber, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stay on track with your health today!',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: c.textSec,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.06, end: 0, duration: 500.ms);
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
// _PrescriptionCard
// ══════════════════════════════════════════════════════════════════════════════
class _PrescriptionCard extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _PrescriptionCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return _CardShell(
      accentColor: accent,
      onTap:       onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: Icons.upload_file_rounded, color: accent),
          const SizedBox(height: 14),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary)),
          const SizedBox(height: 4),
          Text('Upload your prescription',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: context.colors.textSec)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _SubChip(icon: Icons.edit_note_rounded, label: 'Manual')),
              const SizedBox(width: 7),
              Expanded(child: _SubChip(icon: Icons.attach_file_rounded, label: 'File')),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TestReportCard
// ══════════════════════════════════════════════════════════════════════════════
class _TestReportCard extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _TestReportCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return _CardShell(
      onTap:       onTap,
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: Icons.science_rounded, color: accent),
          const SizedBox(height: 14),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary)),
          const SizedBox(height: 4),
          Text('Upload your test results',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: context.colors.textSec)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _SubChip(
                icon: Icons.attach_file_rounded,
                label: 'File Upload',
                fullWidth: true),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DoctorsCard
// ══════════════════════════════════════════════════════════════════════════════
class _DoctorsCard extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  final int          animDelay;
  final int          pendingCount;

  const _DoctorsCard({
    required this.label,
    required this.onTap,
    required this.animDelay,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final accent = c.accent;
    return _CardShell(
      accentColor: accent,
      onTap:       onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardIcon(icon: Icons.link_rounded, color: accent),
              if (pendingCount > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        c.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pendingCount new',
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('Linked doctors',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: c.textSec)),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color:        accent.withAlpha(20),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 16, color: accent),
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: animDelay))
        .slideY(begin: 0.08);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AppointmentsCard
// ══════════════════════════════════════════════════════════════════════════════
class _AppointmentsCard extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  final int          animDelay;

  const _AppointmentsCard({
    required this.label,
    required this.onTap,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return _CardShell(
      accentColor: accent,
      onTap:       onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: Icons.event_rounded, color: accent),
          const SizedBox(height: 14),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary)),
          const SizedBox(height: 4),
          Text('Track your visits',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: context.colors.textSec)),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color:        accent.withAlpha(20),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 16, color: accent),
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: animDelay))
        .slideY(begin: 0.08);
  }
}

// ── Shared dark card shell ────────────────────────────────────────────────────
class _CardShell extends StatelessWidget {
  final Widget        child;
  final Color         accentColor;
  final VoidCallback? onTap;

  const _CardShell({
    required this.child,
    required this.accentColor,
    this.onTap,
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
          child: child,
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  final IconData icon;
  final Color    color;

  const _CardIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40), width: 1),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

class _SubChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     fullWidth;

  const _SubChip({
    required this.icon,
    required this.label,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderLight, width: 1),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: c.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSec,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _BottomBar
// ══════════════════════════════════════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final VoidCallback?         onSearchTap;
  final VoidCallback?         onProfileTap;
  final String?               avatarUrl;

  const _BottomBar({
    required this.searchCtrl,
    this.onSearchTap,
    this.onProfileTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left:   16,
        right:  16,
        top:    14,
        bottom: bottomPad + 14,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.only(
          topLeft:  Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        border: Border(
          top: BorderSide(color: c.border, width: 1),
        ),
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
          _BarButton(
            icon:  Icons.receipt_long_rounded,
            label: 'Last\nPrescribed',
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border, width: 1),
              ),
              child: GestureDetector(
                onTap: onSearchTap,
                child: AbsorbPointer(
                  child: TextField(
                    controller: searchCtrl,
                    readOnly:   true,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText:  'Search doctors, medicines…',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 12, color: c.textMuted),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: c.accent, size: 20),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          _ProfileBarButton(
            label:     'My\nProfile',
            onTap:     onProfileTap,
            avatarUrl: avatarUrl,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.06);
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String   label;

  const _BarButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.border, width: 1),
            ),
            child: Icon(icon, color: c.accent, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
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
    );
  }
}

class _ProfileBarButton extends StatelessWidget {
  final String        label;
  final VoidCallback? onTap;
  final String?       avatarUrl;

  const _ProfileBarButton({required this.label, this.onTap, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
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
                  : Icon(
                      Icons.person_rounded,
                      color: c.accent,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
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
    );
  }
}
