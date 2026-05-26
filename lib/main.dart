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
  final _authService = AuthService();
  bool _didStartFresh = false;

  @override
  void initState() {
    super.initState();
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
    if (!_didStartFresh) return const _SplashScreen();

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
        try {
          verification = await _verifyService.fetchMyVerification();
        } catch (_) {
          // Verification fetch failed — still route to doctor screen.
          // The doctor home screen itself will retry or show pending state.
        }
      }

      if (mounted) {
        setState(() {
          _role         = role;
          _verification = verification;
          _loading      = false;
        });
      }
    } catch (e) {
      debugPrint('_loadRole error: $e');
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
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
}
