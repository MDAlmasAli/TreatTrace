// ─────────────────────────────────────────────────────────────────────────────
// main.dart
//
// Application entry point for TreatTrace.
//
// What happens here:
//   1. Flutter engine is initialised.
//   2. Supabase is initialised with our project URL and anon key.
//      (Edit lib/core/config/supabase_config.dart with your credentials.)
//   3. The app checks whether a session already exists on this device.
//   4. If logged in  → the Home screen is shown immediately.
//      If logged out → the Login screen is shown.
//   5. The app also listens for auth state changes in real time so that if
//      a session expires, the user is automatically sent back to Login.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';

// ── App entry ──────────────────────────────────────────────────────────────
Future<void> main() async {
  // Required before any async work in main().
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to portrait orientation — standard for healthcare apps.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialise Supabase — this must complete before the app starts so that
  // auth state is available immediately on the first frame.
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const TreatTraceApp());
}

// ── Root widget ────────────────────────────────────────────────────────────
class TreatTraceApp extends StatelessWidget {
  const TreatTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TreatTrace',
      debugShowCheckedModeBanner: false,

      // ── Global theme ────────────────────────────────────────────────────
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        // Apply Poppins globally so all default Text widgets use it.
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),

      // AuthGate checks whether a session exists and routes accordingly.
      home: const AuthGate(),
    );
  }
}

// ── AuthGate ───────────────────────────────────────────────────────────────
// Decides which screen to show based on the current Supabase session.
// It listens for real-time auth state changes (login / logout / token expiry).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // onAuthStateChange emits every time the user logs in, logs out,
      // or their token is refreshed automatically.
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // While waiting for the first event, show a branded splash screen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          // A valid session exists — show the Home dashboard.
          return const HomeScreen();
        } else {
          // No session — prompt the user to log in.
          return const LoginScreen();
        }
      },
    );
  }
}

// ── Splash / Loading screen ────────────────────────────────────────────────
// Shown briefly while Supabase checks for an existing session on device.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'TreatTrace',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your health, our priority.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withAlpha(200),
                ),
              ),
              const SizedBox(height: 40),
              // Small spinner while checking session
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
