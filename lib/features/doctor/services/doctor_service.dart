// doctor_service.dart — Supabase CRUD for doctors table.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor.dart';

class DoctorService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<List<Doctor>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('doctors')
        .select()
        .eq('user_id', uid)
        .order('is_favorite', ascending: false)
        .order('name', ascending: true);
    return rows.map(Doctor.fromMap).toList();
  }

  Future<Doctor?> fetchOne(String id) async {
    final row = await _client
        .from('doctors')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Doctor.fromMap(row);
  }

  Future<Doctor> create(Doctor doctor) async {
    final inserted = await _client
        .from('doctors')
        .insert({...doctor.toMap(), 'user_id': _uid})
        .select()
        .single();
    return Doctor.fromMap(inserted);
  }

  Future<void> update(Doctor doctor) async {
    await _client
        .from('doctors')
        .update(doctor.toMap())
        .eq('id', doctor.id);
  }

  Future<void> toggleFavorite(Doctor doctor) async {
    await _client
        .from('doctors')
        .update({'is_favorite': !doctor.isFavorite})
        .eq('id', doctor.id);
  }

  Future<void> delete(String id) async {
    await _client.from('doctors').delete().eq('id', id);
  }

  // Returns distinct specialties the user has saved
  Future<List<String>> fetchSpecialties() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('doctors')
        .select('specialty')
        .eq('user_id', uid)
        .not('specialty', 'is', null);
    final seen = <String>{};
    final list = <String>[];
    for (final r in rows) {
      final s = r['specialty'] as String?;
      if (s != null && s.isNotEmpty && seen.add(s)) list.add(s);
    }
    list.sort();
    return list;
  }
}
