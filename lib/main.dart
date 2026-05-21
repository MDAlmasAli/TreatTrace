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
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';

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
    // After the first frame, check if we need to force a sign-out because
    // the user had keep-me-logged-in set to false.
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
    // Show splash while the post-frame callback hasn't fired yet.
    if (!_didStartFresh) return const _SplashScreen();

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return HomeScreen(
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
// _SplashScreen — dark branded loading screen shown while Supabase initializes.
// ══════════════════════════════════════════════════════════════════════════════
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  static const _blue = Color(0xFF136AFB);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF0F4F8),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.all(Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A136AFB),
                    blurRadius: 24,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SizedBox(
                width: 84,
                height: 84,
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),

            SizedBox(height: 24),

            Text(
              'TreatTrace',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Your health, our priority.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),

            SizedBox(height: 48),

            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: _blue,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
