// appointment_service.dart — Supabase CRUD for appointments table.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment.dart';

class AppointmentService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;
  String? get _doctorName =>
      _client.auth.currentUser?.userMetadata?['full_name'] as String?;

  Future<List<Appointment>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('appointments')
        .select()
        .eq('user_id', uid)
        .order('appointment_date', ascending: false);
    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> fetchForDoctor(String doctorId) async {
    final rows = await _client
        .from('appointments')
        .select()
        .eq('doctor_id', doctorId)
        .order('appointment_date', ascending: false);
    return rows.map(Appointment.fromMap).toList();
  }

  Future<Appointment?> fetchOne(String id) async {
    final row = await _client
        .from('appointments')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Appointment.fromMap(row);
  }

  Future<Appointment> create(Appointment appt) async {
    final inserted = await _client
        .from('appointments')
        .insert({...appt.toMap(), 'user_id': _uid})
        .select()
        .single();
    return Appointment.fromMap(inserted);
  }

  Future<void> update(Appointment appt) async {
    await _client.from('appointments').update(appt.toMap()).eq('id', appt.id);
  }

  Future<void> updateStatus(String id, AppointmentStatus status) async {
    await _client
        .from('appointments')
        .update({'status': status.value})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('appointments').delete().eq('id', id);
  }

  // ── Doctor: fetch appointments for a specific patient ────────────────────

  Future<List<Appointment>> fetchForPatient(String patientId) async {
    final rows = await _client
        .from('appointments')
        .select()
        .eq('user_id', patientId)
        .order('appointment_date', ascending: false);
    return rows.map(Appointment.fromMap).toList();
  }

  // ── Doctor: create appointment for a linked patient ───────────────────────

  Future<Appointment> createForPatient({
    required String patientId,
    required Appointment appt,
  }) async {
    final doctorUserId = _uid;
    if (doctorUserId == null) throw Exception('Not authenticated');

    try {
      final inserted = await _client
          .from('appointments')
          .insert({
            ...appt.toMap(),
            'user_id': patientId,
            'doctor_user_id': doctorUserId,
          })
          .select()
          .single();
      return Appointment.fromMap(inserted);
    } catch (_) {
      final inserted = await _client
          .from('appointments')
          .insert({...appt.toMap(), 'user_id': patientId})
          .select()
          .single();
      return Appointment.fromMap(inserted);
    }
  }

  Future<List<Appointment>> fetchForCurrentDoctor({DateTime? day}) async {
    final rows = await _fetchRowsForCurrentDoctor(columns: '*', day: day);
    return rows
        .map((row) => Appointment.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<int> countTodayForCurrentDoctor() async {
    final rows = await _fetchRowsForCurrentDoctor(
      columns: 'id',
      day: DateTime.now(),
    );
    return rows.length;
  }

  // Count upcoming appointments (scheduled + date >= today)
  Future<int> countUpcoming() async {
    final uid = _uid;
    if (uid == null) return 0;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await _client
        .from('appointments')
        .select('id')
        .eq('user_id', uid)
        .eq('status', 'scheduled')
        .gte('appointment_date', today);
    return rows.length;
  }

  Future<List<dynamic>> _fetchRowsForCurrentDoctor({
    required String columns,
    DateTime? day,
  }) async {
    final uid = _uid;
    if (uid == null) return [];
    final date = day == null ? null : _dateOnly(day);

    try {
      var query = _client
          .from('appointments')
          .select(columns)
          .eq('doctor_user_id', uid);
      if (date != null) query = query.eq('appointment_date', date);
      final rows = await query.order('created_at', ascending: false);
      return rows as List;
    } catch (_) {
      final doctorName = _doctorName;
      if (doctorName == null || doctorName.trim().isEmpty) return [];
      var query = _client
          .from('appointments')
          .select(columns)
          .eq('doctor_name_snapshot', doctorName.trim());
      if (date != null) query = query.eq('appointment_date', date);
      final rows = await query.order('created_at', ascending: false);
      return rows as List;
    }
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
