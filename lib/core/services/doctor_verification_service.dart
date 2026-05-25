import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorVerificationService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchMyVerification() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return await _client
        .from('doctor_verifications')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> submitVerification({
    required String bmdcNumber,
    required String specialty,
    required String hospital,
    required String nidPassport,
    required String degree,
    required String about,
    String? additionalInfo,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _client.from('doctor_verifications').upsert({
      'id': userId,
      'bmdc_number': bmdcNumber,
      'specialty': specialty,
      'hospital': hospital,
      'nid_passport': nidPassport,
      'degree': degree,
      'about': about,
      'additional_info': additionalInfo?.isEmpty == true ? null : additionalInfo,
      'status': 'pending',
      'rejection_reason': null,
      'submitted_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<List<Map<String, dynamic>>> fetchAllVerifications() async {
    final result = await _client
        .from('doctor_verifications')
        .select('*, profiles(full_name, email, phone)')
        .order('submitted_at', ascending: true);
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<void> approveVerification(String doctorId) async {
    await _client.from('doctor_verifications').update({
      'status': 'approved',
      'rejection_reason': null,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': _client.auth.currentUser?.id,
    }).eq('id', doctorId);
  }

  Future<void> rejectVerification(String doctorId, String reason) async {
    await _client.from('doctor_verifications').update({
      'status': 'rejected',
      'rejection_reason': reason,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': _client.auth.currentUser?.id,
    }).eq('id', doctorId);
  }

  // ── Edit flow (doctor submits changes, admin re-reviews) ──────────────────

  Future<void> submitEdit({
    required String bmdcNumber,
    required String specialty,
    required String hospital,
    required String nidPassport,
    required String degree,
    required String about,
    String? additionalInfo,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _client.from('doctor_verifications').update({
      'pending_bmdc':       bmdcNumber,
      'pending_specialty':  specialty,
      'pending_hospital':   hospital,
      'pending_nid_passport': nidPassport,
      'pending_degree':     degree,
      'pending_about':      about,
      'pending_additional': additionalInfo?.isEmpty == true ? null : additionalInfo,
      'edit_status':        'pending',
      'edit_rejection_reason': null,
      'edit_submitted_at':  DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<List<Map<String, dynamic>>> fetchPendingEdits() async {
    final result = await _client
        .from('doctor_verifications')
        .select('*, profiles(full_name, email, phone)')
        .eq('edit_status', 'pending')
        .order('edit_submitted_at', ascending: true);
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<void> approveEdit(String doctorId) async {
    await _client.rpc('approve_doctor_edit', params: {'p_doctor_id': doctorId});
  }

  Future<void> rejectEdit(String doctorId, String reason) async {
    await _client.from('doctor_verifications').update({
      'pending_bmdc':           null,
      'pending_specialty':      null,
      'pending_hospital':       null,
      'pending_nid_passport':   null,
      'pending_degree':         null,
      'pending_about':          null,
      'pending_additional':     null,
      'edit_status':            'rejected',
      'edit_rejection_reason':  reason,
      'reviewed_at':            DateTime.now().toIso8601String(),
      'reviewed_by':            _client.auth.currentUser?.id,
    }).eq('id', doctorId);
  }
}
