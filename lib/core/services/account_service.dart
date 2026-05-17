// ─────────────────────────────────────────────────────────────────────────────
// account_service.dart
//
// Handles CRUD for the `profiles` table (not health_profiles).
// Also delegates email / password updates to Supabase Auth.
//
// Table columns managed:
//   profiles.full_name, profiles.email, profiles.avatar_url, profiles.phone
// ─────────────────────────────────────────────────────────────────────────────

import 'package:image_picker/image_picker.dart';
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
    await _client.from('profiles').upsert(
      {'id': uid, 'full_name': name.trim()},
      onConflict: 'id',
    );
    await _client.auth
        .updateUser(UserAttributes(data: {'full_name': name.trim()}));
  }

  // ── Update phone ──────────────────────────────────────────────────────────

  /// Updates `profiles.phone`.
  Future<void> updatePhone(String phone) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('profiles').upsert(
      {'id': uid, 'phone': phone.trim()},
      onConflict: 'id',
    );
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

  /// Uploads an avatar using raw bytes — works on Flutter Web and mobile.
  /// Reads bytes from [file] (XFile from image_picker), uploads to
  /// `avatars/<uid>/avatar.<ext>`, and updates `profiles.avatar_url`.
  /// Returns the public URL (with a cache-bust query param).
  Future<String> uploadAvatar(XFile file) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final bytes = await file.readAsBytes();
    final ext   = file.name.split('.').last.toLowerCase();
    final mime  = ext == 'png'  ? 'image/png'
                : ext == 'webp' ? 'image/webp'
                : 'image/jpeg';

    // Fixed path + upsert so we never accumulate stale files.
    final storagePath = '$uid/avatar.$ext';

    await _client.storage.from('avatars').uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: true),
    );

    // Cache-bust query param so browsers re-fetch after an update.
    final ts  = DateTime.now().millisecondsSinceEpoch;
    final url =
        '${_client.storage.from('avatars').getPublicUrl(storagePath)}?v=$ts';

    await _client.from('profiles').upsert(
      {'id': uid, 'avatar_url': url},
      onConflict: 'id',
    );

    return url;
  }
}
