// ─────────────────────────────────────────────────────────────────────────────
// main.dart
//
// Application entry point for TreatTrace.
//
// Boot sequence:
//   1. Flutter engine initialized.
//   2. AppPreferences (SharedPreferences) initialized.
//   3. Supabase initialized with project credentials.
//   4. TreatTraceApp (StatefulWidget) renders — holds ThemeMode + locale state.
//   5. AuthGate checks keep-me-logged-in preference:
//        • If keepLoggedIn=false AND a session exists → sign out first.
//        • Otherwise → stream-based auth routing (home vs login).
//   6. _SplashScreen shows for at least 2 500 ms (full animation) regardless
//      of how fast the session check resolves.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/services/reminder_service.dart';
import 'core/l10n/app_strings.dart';
import 'core/preferences/app_preferences.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'core/services/doctor_verification_service.dart';
import 'features/admin/screens/admin_home_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/doctor/screens/doctor_verification_submit_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/doctor_home/screens/doctor_home_screen.dart';

// ── App entry ──────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize persistent preferences before anything else reads them.
  await AppPreferences.init();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await ReminderService().init();

  runApp(const TreatTraceApp());
}

// ══════════════════════════════════════════════════════════════════════════════
// TreatTraceApp — root StatefulWidget holding theme + locale state.
// ══════════════════════════════════════════════════════════════════════════════
class TreatTraceApp extends StatefulWidget {
  const TreatTraceApp({super.key});

  @override
  State<TreatTraceApp> createState() => _TreatTraceAppState();
}

class _TreatTraceAppState extends State<TreatTraceApp> {
  late ThemeMode _themeMode;
  late String    _locale;

  @override
  void initState() {
    super.initState();
    _themeMode = _parseThemeMode(AppPreferences.themeMode);
    _locale    = AppPreferences.locale;
  }

  void updateTheme(String mode) {
    AppPreferences.setThemeMode(mode);
    setState(() => _themeMode = _parseThemeMode(mode));
  }

  void updateLocale(String locale) {
    AppPreferences.setLocale(locale);
    setState(() => _locale = locale);
  }

  static ThemeMode _parseThemeMode(String s) {
    if (s == 'dark')  return ThemeMode.dark;
    if (s == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  @override
  Widget build(BuildContext context) {
    return AppLocale(
      locale: _locale,
      child: MaterialApp(
        title: 'TreatTrace',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const _AppScrollBehavior(),
        theme:      AppTheme.light(),
        darkTheme:  AppTheme.dark(),
        themeMode:  _themeMode,
        home: AuthGate(
          onThemeChanged:  updateTheme,
          onLocaleChanged: updateLocale,
          currentTheme:    AppPreferences.themeMode,
          currentLocale:   _locale,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AuthGate — decides which screen to show based on session + keep-me-logged-in.
// Guarantees the splash is visible for at least _kMinSplash so the full
// animation always plays even when the session check resolves instantly.
// ══════════════════════════════════════════════════════════════════════════════
class AuthGate extends StatefulWidget {
  final void Function(String) onThemeChanged;
  final void Function(String) onLocaleChanged;
  final String currentTheme;
  final String currentLocale;

  const AuthGate({
    super.key,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.currentTheme,
    required this.currentLocale,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _kMinSplash = Duration(milliseconds: 2500);

  final _authService = AuthService();
  bool _didStartFresh = false;
  bool _minDelayPassed = false;

  @override
  void initState() {
    super.initState();

    // Ensure full animation always completes.
    Future.delayed(_kMinSplash, () {
      if (mounted) setState(() => _minDelayPassed = true);
    });

    // Check keep-me-logged-in preference and sign out if needed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!AppPreferences.keepLoggedIn &&
          Supabase.instance.client.auth.currentSession != null) {
        await _authService.signOut();
      }
      if (mounted) setState(() => _didStartFresh = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hold splash until BOTH the auth pre-check AND the minimum display time pass.
    if (!_didStartFresh || !_minDelayPassed) return const _SplashScreen();

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return _RoleAwareRouter(
            onThemeChanged:  widget.onThemeChanged,
            onLocaleChanged: widget.onLocaleChanged,
            currentTheme:    widget.currentTheme,
            currentLocale:   widget.currentLocale,
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _RoleAwareRouter — fetches the user's role and routes to the right home screen.
// ══════════════════════════════════════════════════════════════════════════════
class _RoleAwareRouter extends StatefulWidget {
  final void Function(String) onThemeChanged;
  final void Function(String) onLocaleChanged;
  final String currentTheme;
  final String currentLocale;

  const _RoleAwareRouter({
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.currentTheme,
    required this.currentLocale,
  });

  @override
  State<_RoleAwareRouter> createState() => _RoleAwareRouterState();
}

class _RoleAwareRouterState extends State<_RoleAwareRouter> {
  final _authService    = AuthService();
  final _verifyService  = DoctorVerificationService();

  String?               _role;
  Map<String, dynamic>? _verification;
  bool                  _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    setState(() => _loading = true);
    try {
      final profile = await _authService.fetchProfile();
      final role    = profile?['role'] as String?;

      Map<String, dynamic>? verification;
      if (role == 'doctor') {
        verification = await _verifyService.fetchMyVerification();
      }

      if (mounted) {
        setState(() {
          _role         = role;
          _verification = verification;
          _loading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFF136AFB),
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    if (_role == null) {
      return RoleSelectionScreen(onRoleSelected: _loadRole);
    }

    if (_role == 'admin') {
      return const AdminHomeScreen();
    }

    if (_role == 'doctor') {
      final status = _verification?['status'] as String?;
      // No submission yet, or previously rejected → show submit form
      if (status == null || status == 'rejected') {
        return DoctorVerificationSubmitScreen(
          onSubmitted:     _loadRole,
          rejectionReason: _verification?['rejection_reason'] as String?,
        );
      }
      return DoctorHomeScreen(
        verificationStatus: status,
        onThemeChanged:     widget.onThemeChanged,
        onLocaleChanged:    widget.onLocaleChanged,
        currentTheme:       widget.currentTheme,
        currentLocale:      widget.currentLocale,
      );
    }

    return HomeScreen(
      onThemeChanged:  widget.onThemeChanged,
      onLocaleChanged: widget.onLocaleChanged,
      currentTheme:    widget.currentTheme,
      currentLocale:   widget.currentLocale,
    );
  }
}

// Enables mouse-drag scrolling on Flutter Web (in addition to touch/wheel).
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// _SplashScreen — "Clarity reveal" animated branded splash.
//
// Sequence (single AnimationController, 2 200 ms total):
//   0 ms – 600 ms  : location-pin scales in 0.6 → 1.0 (easeOutBack)
//   450 ms – 1150 ms: heartbeat line draws itself L→R inside the pin
//   1100 ms – 1850 ms: "TreatTrace" wordmark wiped L→R by expanding ClipRect
//   1850 ms – 2100 ms: tagline fades in
//   (always visible) : loading spinner at bottom
// ══════════════════════════════════════════════════════════════════════════════
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pinScale;
  late final Animation<double> _heartbeat;
  late final Animation<double> _wipe;
  late final Animation<double> _tagline;

  static const _kTotal = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kTotal)..forward();

    _pinScale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.000, 0.273, curve: Curves.easeOutBack),
    );
    _heartbeat = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.205, 0.523, curve: Curves.easeOut),
    );
    _wipe = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.500, 0.841, curve: Curves.easeOut),
    );
    _tagline = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.841, 0.955, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // ── Location pin with animated heartbeat ──
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => Transform.scale(
                scale: 0.6 + _pinScale.value * 0.4,
                child: SizedBox(
                  width: 96,
                  height: 116,
                  child: CustomPaint(
                    painter: _PinPainter(heartbeatProgress: _heartbeat.value),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── TreatTrace wordmark — left-to-right wipe reveal ──
            AnimatedBuilder(
              animation: _wipe,
              builder: (_, child) => ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _wipe.value.clamp(0.0001, 1.0),
                  child: child,
                ),
              ),
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Treat',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF136AFB),
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Trace',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B3D8C),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Tagline — soft fade in ──
            AnimatedBuilder(
              animation: _tagline,
              builder: (_, child) => Opacity(
                opacity: _tagline.value,
                child: child,
              ),
              child: const Text(
                'Your health, traced.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                ),
              ),
            ),

            const Spacer(),

            // ── Loading spinner ──
            const Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF136AFB),
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PinPainter — draws a location pin filled with brand blue, with a white
// ECG/heartbeat stroke that animates from left to right.
// ══════════════════════════════════════════════════════════════════════════════
class _PinPainter extends CustomPainter {
  final double heartbeatProgress; // 0.0 → 1.0

  const _PinPainter({required this.heartbeatProgress});

  static const _kBrand = Color(0xFF136AFB);

  @override
  void paint(Canvas canvas, Size size) {
    final pin = _pinPath(size);

    // Filled pin body.
    canvas.drawPath(pin, Paint()..color = _kBrand);

    // Animated heartbeat stroke clipped inside the pin.
    if (heartbeatProgress > 0.001) {
      canvas
        ..save()
        ..clipPath(pin);
      _drawHeartbeat(canvas, size);
      canvas.restore();
    }
  }

  // Teardrop pin: circle top tapering to a point at the bottom.
  Path _pinPath(Size size) {
    final cx = size.width / 2;
    final r  = size.width / 2;
    final cy = r;
    final tipY = size.height;

    return Path()
      ..moveTo(cx, tipY)
      ..cubicTo(
        cx - r * 0.12, tipY - r * 0.45,
        cx - r,        cy   + r * 0.72,
        cx - r,        cy,
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi,  // start: left of circle
        -math.pi, // sweep counterclockwise → up and over
        false,
      )
      ..cubicTo(
        cx + r,        cy   + r * 0.72,
        cx + r * 0.12, tipY - r * 0.45,
        cx,            tipY,
      )
      ..close();
  }

  void _drawHeartbeat(Canvas canvas, Size size) {
    final cx    = size.width / 2;
    final r     = size.width / 2;
    final cy    = r; // heartbeat y-centre = circle centre
    final scale = r / 48.0; // normalise to a 96-px-wide pin

    final xL    = cx - r * 0.60;
    final xR    = cx + r * 0.60;
    final range = xR - xL;

    double px(double t)  => xL + range * t;
    double py(double dy) => cy + dy * scale;

    // Full ECG path: flat → P wave → baseline → QRS spike → T wave → flat.
    final full = Path()
      ..moveTo(px(0.00), py(0))
      ..lineTo(px(0.22), py(0))
      ..lineTo(px(0.30), py(-3.5))
      ..lineTo(px(0.35), py(0))
      ..lineTo(px(0.41), py(-1.5))
      ..lineTo(px(0.47), py(-14))   // R wave peak
      ..lineTo(px(0.53), py(10))    // S wave nadir
      ..lineTo(px(0.58), py(0))
      ..lineTo(px(0.65), py(-5))    // T wave
      ..lineTo(px(0.71), py(0))
      ..lineTo(px(1.00), py(0));

    final metrics = full.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric  = metrics.first;
    final partial = metric.extractPath(0, metric.length * heartbeatProgress);

    canvas.drawPath(
      partial,
      Paint()
        ..color      = Colors.white
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale
        ..strokeCap  = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.heartbeatProgress != heartbeatProgress;
}
