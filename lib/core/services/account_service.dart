// ─────────────────────────────────────────────────────────────────────────────
// account_service.dart
//
// Handles CRUD for the `profiles` table (not health_profiles).
// Also delegates email / password updates to Supabase Auth.
//
// Table columns managed:
//   profiles.full_name, profiles.email, profiles.avatar_url, profiles.phone
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class AccountService {
  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  // ── Fetch ─────────────────────────────────────────────────────────────────

  /// Fetches the `profiles` row for the current user.
  /// Returns null if the row does not exist yet.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = _uid;
    if (uid == null) return null;

    final data = await _client
        .from('profiles')
        .select('full_name, email, avatar_url, phone')
        .eq('id', uid)
        .maybeSingle();

    return data;
  }

  // ── Update full name ──────────────────────────────────────────────────────

  /// Updates `profiles.full_name` and also syncs Supabase auth user metadata.
  Future<void> updateFullName(String name) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('profiles')
        .update({'full_name': name.trim()})
        .eq('id', uid);
    await _client.auth
        .updateUser(UserAttributes(data: {'full_name': name.trim()}));
  }

  // ── Update phone ──────────────────────────────────────────────────────────

  /// Updates `profiles.phone`.
  Future<void> updatePhone(String phone) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('profiles')
        .update({'phone': phone.trim()})
        .eq('id', uid);
  }

  // ── Update email (auth) ───────────────────────────────────────────────────

  /// Initiates an email change via Supabase Auth.
  /// Supabase sends a confirmation email to the new address.
  Future<void> updateEmail(String email) async {
    await _client.auth.updateUser(UserAttributes(email: email.trim()));
  }

  // ── Update password (auth) ────────────────────────────────────────────────

  /// Updates the user's password via Supabase Auth.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ── Upload avatar ─────────────────────────────────────────────────────────

  /// Uploads an image file to Supabase Storage (`avatars/<uid>/avatar.<ext>`),
  /// then updates `profiles.avatar_url` with the public URL.
  ///
  /// Returns the public URL of the uploaded avatar.
  Future<String> uploadAvatar(String filePath) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final ext = filePath.split('.').last.toLowerCase();
    final storagePath = '$uid/avatar.$ext';

    await _client.storage.from('avatars').upload(
      storagePath,
      File(filePath),
      fileOptions: const FileOptions(upsert: true),
    );

    final url = _client.storage.from('avatars').getPublicUrl(storagePath);

    await _client
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', uid);

    return url;
  }
}
