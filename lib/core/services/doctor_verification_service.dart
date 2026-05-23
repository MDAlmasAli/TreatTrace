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
}
