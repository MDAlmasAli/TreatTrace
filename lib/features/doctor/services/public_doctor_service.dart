// public_doctor_service.dart — Reads public catalog + saves to personal list.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/public_doctor.dart';
import '../models/doctor.dart';

class PublicDoctorService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<List<PublicDoctor>> fetchAll() async {
    final rows = await _client
        .from('public_doctors')
        .select()
        .order('name', ascending: true);
    return rows.map(PublicDoctor.fromMap).toList();
  }

  // Returns the set of public_doctor source_ids the current user already saved.
  Future<Set<String>> fetchSavedSourceIds() async {
    final uid = _uid;
    if (uid == null) return {};
    final rows = await _client
        .from('doctors')
        .select('source_id')
        .eq('user_id', uid)
        .not('source_id', 'is', null);
    return {
      for (final r in rows)
        if (r['source_id'] != null) r['source_id'] as String,
    };
  }

  // Saves a public doctor into the user's personal doctors list.
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
