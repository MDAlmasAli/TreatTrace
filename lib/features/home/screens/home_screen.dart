// ─────────────────────────────────────────────────────────────────────────────
// home_screen.dart
//
// Main dashboard for TreatTrace.
//
// Design spec:
//   • Deep Blue header  : #2563EB
//   • Page background   : #EEF2FF
//   • Headings font     : DM Serif Display
//   • Body / UI font    : DM Sans
//   • Card corners      : 20–24 px radius
//
// Layout:
//   ┌─────────────────────────────────┐
//   │  Blue header (greeting + icons) │
//   ├─────────────────────────────────┤
//   │  "Quick Actions" section title  │
//   │  ┌────────────┐ ┌────────────┐  │
//   │  │Prescription│ │Test Report │  │
//   │  │[Man] [File]│ │ [File]     │  │
//   │  └────────────┘ └────────────┘  │
//   │  ┌────────────┐ ┌────────────┐  │
//   │  │  Ongoing   │ │  My Health │  │
//   │  │ Treatment  │ │            │  │
//   │  └────────────┘ └────────────┘  │
//   ├─────────────────────────────────┤
//   │[LastPrescribed] [🔍 Search] [👤]│  ← Custom bottom bar
//   └─────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/profile_screen.dart';

// ── Shared design tokens ─────────────────────────────────────────────────────
const Color _deepBlue    = Color(0xFF2563EB);
const Color _blueBg      = Color(0xFFEEF2FF);
const Color _blueBorder  = Color(0xFFBFD7FF);
const Color _textDark    = Color(0xFF1E293B);
const Color _textMid     = Color(0xFF475569);
const Color _textLight   = Color(0xFF94A3B8);

// ══════════════════════════════════════════════════════════════════════════════
// HomeScreen
// ══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService    = AuthService();
  final _searchCtrl     = TextEditingController();

  // ── Computed properties ───────────────────────────────────────────────────

  /// First name extracted from the user's profile metadata.
  String get _firstName {
    final meta = _authService.currentUser?.userMetadata;
    final full = meta?['full_name'] as String?;
    return full?.split(' ').first ?? 'User';
  }

  /// Time-aware greeting — updates every build (accurate for screen rebuilds).
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Profile navigation ────────────────────────────────────────────────────
  void _goToProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Log Out',
            style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: _textDark)),
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
    // Make the status bar icons white so they're visible on the blue header.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _blueBg,
      body: Column(
        children: [
          // Blue header section — extends behind the status bar.
          _HomeHeader(
            greeting: _greeting,
            firstName: _firstName,
            onLogout: _confirmLogout,
          ),

          // Scrollable page body.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section heading
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.dmSerifDisplay(
                        fontSize: 21, color: _textDark),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 16),

                  // ── Row 1: Prescription  +  Test Report ───────────────────
                  // IntrinsicHeight makes both cards in the same row equally
                  // tall, even when one has more content than the other.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _PrescriptionCard()
                              .animate()
                              .fadeIn(delay: 150.ms)
                              .slideY(begin: 0.08),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TestReportCard()
                              .animate()
                              .fadeIn(delay: 200.ms)
                              .slideY(begin: 0.08),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Row 2: Ongoing Treatment  +  My Health ────────────────
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.medication_rounded,
                            iconBg: const Color(0xFFD1FAE5),
                            iconColor: const Color(0xFF059669),
                            title: 'Ongoing\nTreatment',
                            animDelay: 250,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.monitor_heart_rounded,
                            iconBg: const Color(0xFFFCE7F3),
                            iconColor: const Color(0xFFDB2777),
                            title: 'My Health',
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

      // Fixed custom bottom action bar.
      bottomNavigationBar: _BottomBar(
        searchCtrl:    _searchCtrl,
        onProfileTap:  _goToProfile,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HomeHeader — blue gradient header with greeting and action icons.
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
    // topPad keeps content below the device's status bar.
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        color: _deepBlue,
        // Rounded corners only at the bottom to create a "card" effect.
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
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
          // ── Top row: greeting text + icon buttons ────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: Colors.white.withAlpha(195),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome, $firstName!',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 28,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Notification icon
              _HeaderIcon(icon: Icons.notifications_outlined),
              const SizedBox(width: 10),
              // Logout icon (using person → opens profile/logout flow)
              _HeaderIcon(icon: Icons.logout_rounded, onTap: onLogout),
            ],
          ),

          const SizedBox(height: 22),

          // ── Daily tip banner ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(45), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tips_and_updates_rounded,
                      color: Colors.amber, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stay on track with your health today!',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.white.withAlpha(215),
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

// Small icon button used in the header.
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
          color: Colors.white.withAlpha(28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(45), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PrescriptionCard — card with two sub-option chips: Manual + File Upload.
// ══════════════════════════════════════════════════════════════════════════════
class _PrescriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon block
          _CardIcon(
            icon: Icons.upload_file_rounded,
            bg: const Color(0xFFDBEAFE),
            color: _deepBlue,
          ),
          const SizedBox(height: 14),

          // Card title
          Text(
            'Prescription',
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 16, color: _textDark, height: 1.25),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload your prescription',
            style: GoogleFonts.dmSans(fontSize: 11, color: _textLight),
          ),

          const SizedBox(height: 14),

          // Two sub-option chips side by side
          Row(
            children: [
              Expanded(
                child: _SubChip(
                  icon: Icons.edit_note_rounded,
                  label: 'Manual',
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _SubChip(
                  icon: Icons.attach_file_rounded,
                  label: 'File',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TestReportCard — card with single File Upload sub-option chip.
// ══════════════════════════════════════════════════════════════════════════════
class _TestReportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(
            icon: Icons.science_rounded,
            bg: const Color(0xFFEDE9FE),
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 14),

          Text(
            'Test Report',
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 16, color: _textDark, height: 1.25),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload your test results',
            style: GoogleFonts.dmSans(fontSize: 11, color: _textLight),
          ),

          const SizedBox(height: 14),

          // Single full-width chip
          SizedBox(
            width: double.infinity,
            child: _SubChip(
              icon: Icons.attach_file_rounded,
              label: 'File Upload',
              fullWidth: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ActionCard — generic card for Ongoing Treatment and My Health.
// ══════════════════════════════════════════════════════════════════════════════
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final int animDelay;

  const _ActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: icon, bg: iconBg, color: iconColor),
          const SizedBox(height: 14),

          Text(
            title,
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 16, color: _textDark, height: 1.3),
          ),

          const Spacer(),

          // Arrow button — visual affordance showing the card is tappable.
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _blueBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  size: 16, color: _deepBlue),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: animDelay))
        .slideY(begin: 0.08);
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────
class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        splashColor: _deepBlue.withAlpha(15),
        highlightColor: _deepBlue.withAlpha(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EFFF), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: _deepBlue.withAlpha(14),
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

// ── Shared icon block ─────────────────────────────────────────────────────────
class _CardIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;

  const _CardIcon({required this.icon, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

// ── Sub-option chip ───────────────────────────────────────────────────────────
// Small labelled button shown inside the Prescription and Test Report cards.
class _SubChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool fullWidth;

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
        color: _blueBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _blueBorder, width: 1.1),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: _deepBlue),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _deepBlue,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _BottomBar — the horizontal bar at the bottom of the screen.
//
// Layout:  [Last Prescribed]   [🔍 Search bar …]   [My Profile]
// ══════════════════════════════════════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final VoidCallback? onProfileTap;

  const _BottomBar({required this.searchCtrl, this.onProfileTap});

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
        color: Colors.white,
        // Rounded top corners only — blends with the page content above.
        borderRadius: const BorderRadius.only(
          topLeft:  Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: _deepBlue.withAlpha(22),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Left: Last Prescribed ────────────────────────────────────────
          _BarButton(
            icon: Icons.receipt_long_rounded,
            label: 'Last\nPrescribed',
          ),

          const SizedBox(width: 12),

          // ── Center: Search bar (takes all remaining width) ────────────────
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: _blueBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _blueBorder, width: 1.1),
              ),
              child: TextField(
                controller: searchCtrl,
                style: GoogleFonts.dmSans(fontSize: 13, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Search doctors, medicines…',
                  hintStyle: GoogleFonts.dmSans(
                      fontSize: 12, color: _textLight),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _deepBlue, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Right: My Profile ─────────────────────────────────────────────
          _BarButton(
            icon:  Icons.person_rounded,
            label: 'My\nProfile',
            onTap: onProfileTap,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.06);
  }
}

// Icon + label button used on both sides of the bottom bar.
class _BarButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback? onTap;

  const _BarButton({required this.icon, required this.label, this.onTap});

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
            color: _blueBg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _blueBorder, width: 1.1),
          ),
          child: Icon(icon, color: _deepBlue, size: 22),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _deepBlue,
            height: 1.2,
          ),
        ),
      ],
      ),
    );
  }
}
