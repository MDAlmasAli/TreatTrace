// ─────────────────────────────────────────────────────────────────────────────
// home_screen.dart — Dark futuristic dashboard for TreatTrace.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/profile_screen.dart';

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
  final _searchCtrl   = TextEditingController();
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Out',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: DarkColors.textPrimary)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.poppins(
                fontSize: 13, color: DarkColors.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: DarkColors.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log Out',
                style: GoogleFonts.poppins(
                    color: DarkColors.red, fontWeight: FontWeight.w700)),
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final s = S.of(context);

    return Scaffold(
      backgroundColor: DarkColors.bg,
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
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        DarkColors.accentGradient.createShader(bounds),
                    child: Text(
                      s.quickActions,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 16),

                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _PrescriptionCard(label: s.prescription)
                              .animate()
                              .fadeIn(delay: 150.ms)
                              .slideY(begin: 0.08),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TestReportCard(label: s.testReport)
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
                          child: _ActionCard(
                            icon:       Icons.medication_rounded,
                            accentColor:DarkColors.green,
                            title:      s.ongoingTreatment,
                            animDelay:  250,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ActionCard(
                            icon:       Icons.monitor_heart_rounded,
                            accentColor:DarkColors.purpleBright,
                            title:      s.medicalIdentity,
                            animDelay:  300,
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
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        color: DarkColors.card,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: const Border(
          bottom: BorderSide(color: DarkColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: DarkColors.purpleBright.withAlpha(20),
            blurRadius: 24,
            offset: const Offset(0, 4),
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
                        color: DarkColors.textSec,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome, $firstName!',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: DarkColors.textPrimary,
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
              color: DarkColors.purpleBright.withAlpha(15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: DarkColors.purpleBright.withAlpha(60), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DarkColors.amber.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tips_and_updates_rounded,
                      color: DarkColors.amber, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stay on track with your health today!',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: DarkColors.textSec,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: DarkColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DarkColors.border, width: 1),
        ),
        child: Icon(icon, color: DarkColors.textSec, size: 21),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PrescriptionCard
// ══════════════════════════════════════════════════════════════════════════════
class _PrescriptionCard extends StatelessWidget {
  final String label;
  const _PrescriptionCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: DarkColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: Icons.upload_file_rounded, color: DarkColors.cyan),
          const SizedBox(height: 14),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: DarkColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Upload your prescription',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: DarkColors.textSec)),
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
  final String label;
  const _TestReportCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: DarkColors.purpleBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: Icons.science_rounded, color: DarkColors.purpleBright),
          const SizedBox(height: 14),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: DarkColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Upload your test results',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: DarkColors.textSec)),
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
// _ActionCard
// ══════════════════════════════════════════════════════════════════════════════
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color    accentColor;
  final String   title;
  final int      animDelay;

  const _ActionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: icon, color: accentColor),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: DarkColors.textPrimary,
                  height: 1.3)),
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
    ).animate().fadeIn(delay: Duration(milliseconds: animDelay)).slideY(begin: 0.08);
  }
}

// ── Shared dark card shell ────────────────────────────────────────────────────
class _CardShell extends StatelessWidget {
  final Widget child;
  final Color  accentColor;

  const _CardShell({required this.child, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DarkColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        splashColor: accentColor.withAlpha(15),
        highlightColor: accentColor.withAlpha(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DarkColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(12),
                blurRadius: 14,
                offset: const Offset(0, 4),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: DarkColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DarkColors.borderLight, width: 1),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: DarkColors.purpleBright),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: DarkColors.textSec,
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
  final VoidCallback? onProfileTap;
  final String?       avatarUrl;

  const _BottomBar({required this.searchCtrl, this.onProfileTap, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left:   16,
        right:  16,
        top:    14,
        bottom: bottomPad + 14,
      ),
      decoration: BoxDecoration(
        color: DarkColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft:  Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        border: const Border(
          top: BorderSide(color: DarkColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 28,
            offset: const Offset(0, -6),
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
                color: DarkColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DarkColors.border, width: 1),
              ),
              child: TextField(
                controller: searchCtrl,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: DarkColors.textPrimary),
                decoration: InputDecoration(
                  hintText:  'Search doctors, medicines…',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 12, color: DarkColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: DarkColors.purpleBright, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
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
    return GestureDetector(
      onTap: null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: DarkColors.card,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: DarkColors.border, width: 1),
            ),
            child: Icon(icon, color: DarkColors.purpleBright, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: DarkColors.textSec,
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: DarkColors.card,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: avatarUrl != null
                    ? DarkColors.purpleBright.withAlpha(120)
                    : DarkColors.border,
                width: avatarUrl != null ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        color: DarkColors.purpleBright,
                        size: 22,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: DarkColors.purpleBright,
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
              color: DarkColors.textSec,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
