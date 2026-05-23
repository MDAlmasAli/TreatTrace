// public_doctor_service.dart — Reads verified doctors + saves to personal list.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/public_doctor.dart';
import '../models/doctor.dart';

class PublicDoctorService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// All approved doctors (doctor_verifications joined with profiles).
  Future<List<PublicDoctor>> fetchAll() async {
    final rows = await _client
        .from('doctor_verifications')
        .select('id, specialty, hospital, reviewed_at, submitted_at, '
                'profiles(full_name, phone, avatar_url)')
        .eq('status', 'approved')
        .order('reviewed_at', ascending: false);
    return (rows as List)
        .map((r) => PublicDoctor.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// IDs of verified doctors the current user already added to My Doctors.
  Future<Set<String>> fetchSavedSourceIds() async {
    final uid = _uid;
    if (uid == null) return {};
    final rows = await _client
        .from('doctors')
        .select('source_id')
        .eq('user_id', uid)
        .not('source_id', 'is', null);
    return {
      for (final r in rows as List)
        if (r['source_id'] != null) r['source_id'] as String,
    };
  }

  /// Saves a verified doctor into the user's personal doctors list.
  Future<Doctor> saveToMyDoctors(PublicDoctor pd) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    final inserted = await _client.from('doctors').insert({
      'user_id':         uid,
      'name':            pd.name,
      'specialty':       pd.specialty,
      'hospital':        pd.hospital,
      'chamber_address': pd.chamberAddress,
      'phone':           pd.phone,
      'fee':             pd.fee,
      'image_url':       pd.imageUrl,
      'source_id':       pd.id,
      'is_favorite':     false,
    }).select().single();
    return Doctor.fromMap(inserted);
  }
}
