// appointment_service.dart — Supabase CRUD for appointments table.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment.dart';

class AppointmentService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

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
    await _client
        .from('appointments')
        .update(appt.toMap())
        .eq('id', appt.id);
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
}
