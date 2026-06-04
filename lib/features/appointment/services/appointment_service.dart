// appointment_service.dart — Supabase CRUD for appointments table.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment.dart';

/// Thrown when a patient tries to book a second active appointment with a
/// doctor they already have a scheduled appointment with.
class DuplicateActiveAppointmentException implements Exception {
  final String message;
  DuplicateActiveAppointmentException([
    this.message =
        'You already have an active appointment with this doctor. '
        'Complete or cancel it before booking a new one.',
  ]);
  @override
  String toString() => message;
}

/// Thrown when the requested date is full or not a visiting day. Carries the
/// next available date (if any) so the UI can offer it.
class NoSlotAvailableException implements Exception {
  final String    reason;        // 'full' | 'not_visiting_day' | 'on_hold'
  final DateTime? nextAvailable;
  NoSlotAvailableException({required this.reason, this.nextAvailable});
  @override
  String toString() => 'No slot available ($reason)';
}

class AppointmentService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;
  String? get _doctorName =>
      _client.auth.currentUser?.userMetadata?['full_name'] as String?;

  /// Auto-cancel the caller's scheduled appointments whose date has already
  /// passed (a daily DB cron does this too; this makes it immediate). Silent
  /// on the DB side — no cancel notification is sent for an auto-expiry.
  Future<void> expirePast() async {
    try {
      await _client.rpc('expire_past_appointments');
    } catch (_) {}
  }

  Future<List<Appointment>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];
    await expirePast();
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

  Future<Appointment> create(Appointment appt, {String? doctorUserId}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    // Free up any past scheduled appointments first so the one-active-per-doctor
    // check below doesn't block on an appointment whose date already passed.
    await expirePast();

    final payload = <String, dynamic>{...appt.toMap(), 'user_id': uid};
    final resolvedDoctorUserId = await _resolveDoctorUserId(
      doctorId: appt.doctorId,
      override: doctorUserId,
    );
    if (resolvedDoctorUserId != null && resolvedDoctorUserId.isNotEmpty) {
      payload['doctor_user_id'] = resolvedDoctorUserId;
    }

    // One active appointment per doctor: block if the patient already has a
    // scheduled one with the same doctor (DB trigger enforces this too).
    final hasActive = await _hasActiveAppointmentWithDoctor(
      patientId:          uid,
      doctorUserId:       resolvedDoctorUserId,
      doctorId:           appt.doctorId,
      doctorNameSnapshot: appt.doctorNameSnapshot,
    );
    if (hasActive) throw DuplicateActiveAppointmentException();

    // Slot availability (registered doctors only — they have a schedule).
    if (resolvedDoctorUserId != null && resolvedDoctorUserId.isNotEmpty) {
      final a = await _availability(resolvedDoctorUserId, appt.appointmentDate);
      if (!a.requestedOk) {
        throw NoSlotAvailableException(
            reason: a.reason, nextAvailable: a.nextAvailable);
      }
    }

    try {
      final inserted = await _client
          .from('appointments')
          .insert(payload)
          .select()
          .single();
      return Appointment.fromMap(inserted);
    } on PostgrestException catch (e) {
      // Race: the DB trigger rejected it after our pre-check. Re-probe so the
      // UI can offer the next available date.
      if (e.message.contains('DOCTOR_ON_HOLD')) {
        throw NoSlotAvailableException(reason: 'on_hold');
      }
      if (e.message.contains('NO_SLOT_AVAILABLE') ||
          e.message.contains('INVALID_VISITING_DAY')) {
        DateTime? next;
        if (resolvedDoctorUserId != null && resolvedDoctorUserId.isNotEmpty) {
          next = (await _availability(resolvedDoctorUserId, appt.appointmentDate))
              .nextAvailable;
        }
        throw NoSlotAvailableException(
            reason: e.message.contains('INVALID_VISITING_DAY')
                ? 'not_visiting_day'
                : 'full',
            nextAvailable: next);
      }
      rethrow;
    }
  }

  // Calls the availability RPC for a doctor + date.
  Future<({bool requestedOk, String reason, DateTime? nextAvailable})>
      _availability(String doctorUserId, DateTime date) async {
    final res = await _client.rpc('check_appointment_availability', params: {
      'p_doctor': doctorUserId,
      'p_date':   date.toIso8601String().substring(0, 10),
    });
    final m = (res as Map).cast<String, dynamic>();
    return (
      requestedOk:   m['requested_ok'] == true,
      reason:        (m['reason'] as String?) ?? 'ok',
      nextAvailable: m['next_available'] != null
          ? DateTime.parse(m['next_available'] as String)
          : null,
    );
  }

  // Doctor's start time + minutes-per-patient (for estimated-time display).
  Future<({String? startTime, int? minutesPerPatient})> fetchScheduleTimes(
      String doctorUserId) async {
    try {
      final row = await _client
          .from('doctor_verifications')
          .select('visiting_start_time, minutes_per_patient')
          .eq('id', doctorUserId)
          .maybeSingle();
      return (
        startTime:         row?['visiting_start_time'] as String?,
        minutesPerPatient: (row?['minutes_per_patient'] as num?)?.toInt(),
      );
    } catch (_) {
      return (startTime: null, minutesPerPatient: null);
    }
  }

  Future<void> update(Appointment appt) async {
    // `user_id` never changes on edit, and the edit form builds the draft with
    // an empty user_id (only `create` fills it). Sending '' to the uuid column
    // throws "invalid input syntax for type uuid". Strip immutable fields.
    final payload = appt.toMap()..remove('user_id');
    await _client.from('appointments').update(payload).eq('id', appt.id);
  }

  Future<void> updateStatus(String id, AppointmentStatus status) async {
    await _client
        .from('appointments')
        .update({'status': status.value})
        .eq('id', id);
  }

  // Doctor proposes a new date (pending patient confirmation). Stored in
  // proposed_date; the real appointment_date changes only on patient accept.
  // The DB trigger notifies the patient. (RLS: only the doctor_user_id may do this.)
  Future<void> proposeReschedule(String id, DateTime proposedDate) async {
    await _client.from('appointments').update({
      'proposed_date': proposedDate.toIso8601String().substring(0, 10),
    }).eq('id', id);
  }

  // Patient accepts the proposed reschedule: apply the new date, clear proposal.
  // The DB trigger re-checks the new day (capacity / visiting day) and moves the
  // appointment to the end of that day's queue, then notifies the doctor.
  Future<void> acceptReschedule(String id, DateTime proposedDate) async {
    try {
      await _client.from('appointments').update({
        'appointment_date': proposedDate.toIso8601String().substring(0, 10),
        'proposed_date':    null,
      }).eq('id', id);
    } on PostgrestException catch (e) {
      if (e.message.contains('NO_SLOT_AVAILABLE') ||
          e.message.contains('INVALID_VISITING_DAY')) {
        throw NoSlotAvailableException(
            reason: e.message.contains('INVALID_VISITING_DAY')
                ? 'not_visiting_day'
                : 'full');
      }
      rethrow;
    }
  }

  // Returns the appointment's live queue position for its doctor+day (how many
  // still-scheduled patients are ahead, + 1). Null if not scheduled.
  Future<int?> queuePosition(String appointmentId) async {
    try {
      final res = await _client
          .rpc('get_queue_position', params: {'p_appt_id': appointmentId});
      return (res as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> markNoShow(String id) =>
      updateStatus(id, AppointmentStatus.noShow);

  // Patient declines the proposal but keeps the appointment on its original date.
  Future<void> declineReschedule(String id) async {
    await _client.from('appointments').update({'proposed_date': null}).eq('id', id);
  }

  // ── Doctor: bulk actions on several appointments at once ──────────────────
  Future<void> cancelMany(Iterable<String> ids) async {
    for (final id in ids) {
      await updateStatus(id, AppointmentStatus.cancelled);
    }
  }

  Future<void> proposeRescheduleMany(
      Iterable<String> ids, DateTime proposedDate) async {
    for (final id in ids) {
      await proposeReschedule(id, proposedDate);
    }
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
    } catch (e) {
      // Doctor on hold (profile edit under review): don't fall back to an
      // unlinked insert — surface it so the UI can explain.
      if (e is PostgrestException && e.message.contains('DOCTOR_ON_HOLD')) {
        throw NoSlotAvailableException(reason: 'on_hold');
      }
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
      columns: 'id, status',
      day: DateTime.now(),
    );
    return rows
        .where((r) => (r as Map<String, dynamic>)['status'] == 'scheduled')
        .length;
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
    final merged = <String, Map<String, dynamic>>{};

    try {
      var query = _client
          .from('appointments')
          .select(columns)
          .eq('doctor_user_id', uid);
      if (date != null) query = query.eq('appointment_date', date);
      final rows = await query.order('created_at', ascending: false);
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final id = map['id']?.toString();
        if (id != null && id.isNotEmpty) merged[id] = map;
      }
    } catch (_) {}

    final doctorName = _doctorName?.trim();
    if (doctorName != null && doctorName.isNotEmpty) {
      for (final nameToken in _doctorNameTokens(doctorName)) {
        try {
          var query = _client
              .from('appointments')
              .select(columns)
              .ilike('doctor_name_snapshot', '%$nameToken%');
          if (date != null) query = query.eq('appointment_date', date);
          final rows = await query.order('created_at', ascending: false);
          for (final row in rows as List) {
            final map = row as Map<String, dynamic>;
            final id = map['id']?.toString();
            if (id != null && id.isNotEmpty) merged[id] = map;
          }
        } catch (_) {}
      }
    }

    return merged.values.toList();
  }

  // True if the patient already has a scheduled appointment with this doctor.
  // Matched by doctor_user_id, else doctor_id, else doctor name snapshot.
  Future<bool> _hasActiveAppointmentWithDoctor({
    required String  patientId,
    String?          doctorUserId,
    String?          doctorId,
    required String  doctorNameSnapshot,
  }) async {
    var query = _client
        .from('appointments')
        .select('id')
        .eq('user_id', patientId)
        .eq('status', 'scheduled');

    if (doctorUserId != null && doctorUserId.isNotEmpty) {
      query = query.eq('doctor_user_id', doctorUserId);
    } else if (doctorId != null && doctorId.isNotEmpty) {
      query = query.eq('doctor_id', doctorId);
    } else {
      query = query.ilike('doctor_name_snapshot', doctorNameSnapshot.trim());
    }

    final rows = await query.limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<String?> _resolveDoctorUserId({
    String? doctorId,
    String? override,
  }) async {
    final direct = override?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    if (doctorId == null || doctorId.isEmpty) return null;
    try {
      final row = await _client
          .from('doctors')
          .select('source_id')
          .eq('id', doctorId)
          .maybeSingle();
      return (row?['source_id'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  Set<String> _doctorNameTokens(String raw) {
    final trimmed = raw.trim();
    final normalized = trimmed
        .replaceFirst(RegExp(r'^\s*dr\.?\s*', caseSensitive: false), '')
        .trim();
    final tokens = <String>{};
    if (trimmed.isNotEmpty) tokens.add(trimmed);
    if (normalized.isNotEmpty) {
      tokens.add(normalized);
      tokens.add('Dr. $normalized');
      tokens.add('Dr $normalized');
    }
    return tokens.where((t) => t.length >= 2).toSet();
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
