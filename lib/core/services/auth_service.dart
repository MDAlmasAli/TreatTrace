// ─────────────────────────────────────────────────────────────────────────────
// auth_service.dart
//
// This file handles ALL authentication logic with Supabase.
// It is a single class that the rest of the app calls for:
//   • Signing up new users
//   • Logging in existing users
//   • Logging out
//   • Sending a password reset email
//   • Accessing the current session / user
//
// Why a separate service?
//   Keeping auth logic here means our UI screens stay simple — they just
//   call these methods and show results to the user.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // ── Supabase client singleton ─────────────────────────────────────────────
  // Supabase.instance.client gives us the globally initialised Supabase client.
  // We store it in a short variable for convenience.
  final SupabaseClient _client = Supabase.instance.client;

  // ── Getters ───────────────────────────────────────────────────────────────

  /// Returns the currently logged-in Supabase user, or null if not logged in.
  User? get currentUser => _client.auth.currentUser;

  /// Returns the current session (contains access token, etc.), or null.
  Session? get currentSession => _client.auth.currentSession;

  /// True if a user is currently logged in.
  bool get isLoggedIn => _client.auth.currentUser != null;

  /// Stream of auth state changes — useful for reacting to login/logout events.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Sign Up ───────────────────────────────────────────────────────────────

  /// Registers a new user with email, password, and full name.
  ///
  /// On success: Supabase automatically creates an auth.users record.
  /// We also insert a matching row into our custom `profiles` table via
  /// a database trigger (see SQL setup instructions).
  ///
  /// Returns an [AuthResponse] on success.
  /// Throws an [AuthException] if something goes wrong (e.g. email taken).
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        // phone is picked up by the handle_new_user() DB trigger and saved
        // to the profiles table automatically on sign-up.
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    return response;
  }

  // ── Sign In ───────────────────────────────────────────────────────────────

  /// Logs in an existing user with their email and password.
  ///
  /// Supabase returns a session that is stored on device automatically —
  /// the user stays logged in even if they close the app.
  ///
  /// Returns an [AuthResponse] on success.
  /// Throws an [AuthException] on failure (wrong password, user not found, etc.)
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return response;
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  /// Logs the current user out and clears the local session.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Password Reset ────────────────────────────────────────────────────────

  /// Sends a password reset email to the given address.
  ///
  /// The user receives a link that opens your app and lets them set a new
  /// password. Make sure you configure the redirect URL in your Supabase
  /// dashboard under: Authentication → URL Configuration → Redirect URLs.
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  // ── Profile Fetch ─────────────────────────────────────────────────────────

  /// Retrieves the current user's profile row from the `profiles` table.
  /// Returns null if the profile doesn't exist yet.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  }

  // ── Update Email ──────────────────────────────────────────────────────────

  /// Initiates an email address change for the current user.
  /// Supabase sends a confirmation email to the new address.
  Future<void> updateEmail(String newEmail) async {
    await _client.auth.updateUser(UserAttributes(email: newEmail.trim()));
  }

  // ── Update Password ───────────────────────────────────────────────────────

  /// Updates the current user's password directly via Supabase Auth.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
