// ─────────────────────────────────────────────────────────────────────────────
// profile_service.dart
//
// All Supabase CRUD for the `health_profiles` table.
//   fetchHealthProfile() → returns null for new users (no row yet)
//   saveHealthProfile()  → upsert (create or overwrite)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/profile/models/health_profile.dart';

class ProfileService {
  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  /// Fetches the current user's health profile.
  /// Returns null if the user has never saved any health data.
  Future<HealthProfile?> fetchHealthProfile() async {
    final uid = _uid;
    if (uid == null) return null;

    final data = await _client
        .from('health_profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    return data == null ? null : HealthProfile.fromMap(data);
  }

  /// Doctor: fetches a specific patient's health profile by their user ID.
  Future<HealthProfile?> fetchForPatient(String patientId) async {
    final data = await _client
        .from('health_profiles')
        .select()
        .eq('id', patientId)
        .maybeSingle();
    return data == null ? null : HealthProfile.fromMap(data);
  }

  /// Saves (create or update) the health profile.
  /// Uses upsert so it is safe to call for both new and returning users.
  Future<void> saveHealthProfile(HealthProfile profile) async {
    await _client
        .from('health_profiles')
        .upsert(profile.toMap(), onConflict: 'id');
  }
}
