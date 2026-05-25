import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_patient_link.dart';

class DoctorPatientLinkService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // ── Search patient by phone or user UUID (uses RPC) ───────────────────────

  Future<Map<String, dynamic>?> searchPatient(String query) async {
    final rows = await _client.rpc(
      'search_patient_by_query',
      params: {'query_text': query.trim()},
    ) as List;
    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }

  // ── Send link request (doctor → patient) ──────────────────────────────────

  Future<void> sendRequest(String patientId) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('doctor_patient_links').upsert(
      {
        'doctor_id':    uid,
        'patient_id':   patientId,
        'status':       'pending',
        'requested_at': DateTime.now().toIso8601String(),
        'accepted_at':  null,
      },
      onConflict: 'doctor_id,patient_id',
    );
  }

  // ── Get existing link status between current doctor and a patient ─────────

  Future<DoctorPatientLink?> getLinkStatus(String patientId) async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _client
        .from('doctor_patient_links')
        .select()
        .eq('doctor_id', uid)
        .eq('patient_id', patientId)
        .maybeSingle();
    return row == null ? null : DoctorPatientLink.fromMap(row);
  }

  // ── Doctor: fetch all accepted patients ───────────────────────────────────

  Future<List<DoctorPatientLink>> fetchLinkedPatients() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _client
        .from('doctor_patient_links')
        .select()
        .eq('doctor_id', uid)
        .eq('status', 'accepted')
        .order('accepted_at', ascending: false) as List;

    final links = rows
        .map((r) => DoctorPatientLink.fromMap(r as Map<String, dynamic>))
        .toList();

    return _attachPatientProfiles(links);
  }

  // ── Doctor: fetch all pending/sent requests ───────────────────────────────

  Future<List<DoctorPatientLink>> fetchOutgoingRequests() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _client
        .from('doctor_patient_links')
        .select()
        .eq('doctor_id', uid)
        .inFilter('status', ['pending', 'rejected'])
        .order('requested_at', ascending: false) as List;

    final links = rows
        .map((r) => DoctorPatientLink.fromMap(r as Map<String, dynamic>))
        .toList();

    return _attachPatientProfiles(links);
  }

  // ── Patient: fetch all incoming requests with doctor info ─────────────────

  Future<List<DoctorPatientLink>> fetchIncomingRequests() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _client
        .from('doctor_patient_links')
        .select()
        .eq('patient_id', uid)
        .inFilter('status', ['pending', 'accepted'])
        .order('requested_at', ascending: false) as List;

    final links = rows
        .map((r) => DoctorPatientLink.fromMap(r as Map<String, dynamic>))
        .toList();

    return _attachDoctorProfiles(links);
  }

  // ── Patient: count pending incoming requests (for badge) ──────────────────

  Future<int> countPendingIncoming() async {
    final uid = _uid;
    if (uid == null) return 0;
    final rows = await _client
        .from('doctor_patient_links')
        .select('id')
        .eq('patient_id', uid)
        .eq('status', 'pending') as List;
    return rows.length;
  }

  // ── Patient: accept / reject ──────────────────────────────────────────────

  Future<void> acceptRequest(String linkId) async {
    await _client.from('doctor_patient_links').update({
      'status':      'accepted',
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', linkId);
  }

  Future<void> rejectRequest(String linkId) async {
    await _client
        .from('doctor_patient_links')
        .update({'status': 'rejected'})
        .eq('id', linkId);
  }

  // ── Doctor: revoke link ───────────────────────────────────────────────────

  Future<void> revokeLink(String linkId) async {
    await _client
        .from('doctor_patient_links')
        .update({'status': 'revoked'})
        .eq('id', linkId);
  }

  // ── Patient: remove link entirely ────────────────────────────────────────

  Future<void> removeLink(String linkId) async {
    await _client.from('doctor_patient_links').delete().eq('id', linkId);
  }

  // ── Patient: fetch all approved doctors in the system ────────────────────

  Future<List<Map<String, dynamic>>> fetchApprovedDoctors() async {
    final profiles = await _client
        .from('profiles')
        .select('id, full_name, avatar_url')
        .eq('role', 'doctor') as List;

    if (profiles.isEmpty) return [];

    final ids = profiles.map((p) => p['id'] as String).toList();
    final verifs = await _client
        .from('doctor_verifications')
        .select('id, hospital')
        .eq('status', 'approved')
        .inFilter('id', ids) as List;

    final approvedMap = {for (final v in verifs) v['id'] as String: v};

    return profiles
        .where((p) => approvedMap.containsKey(p['id'] as String))
        .map((p) => {
              'id':         p['id'],
              'full_name':  p['full_name'],
              'avatar_url': p['avatar_url'],
              'hospital':   approvedMap[p['id'] as String]?['hospital'],
            })
        .toList();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<List<DoctorPatientLink>> _attachPatientProfiles(
      List<DoctorPatientLink> links) async {
    if (links.isEmpty) return links;
    final ids = links.map((l) => l.patientId).toList();
    final profiles = await _client
        .from('profiles')
        .select('id, full_name, phone, avatar_url')
        .inFilter('id', ids) as List;

    final map = {for (final p in profiles) p['id'] as String: p};
    return links.map((l) {
      final prof = map[l.patientId] as Map<String, dynamic>?;
      return l.copyWith(
        patientName:     prof?['full_name'] as String?,
        patientPhone:    prof?['phone']     as String?,
        patientAvatarUrl: prof?['avatar_url'] as String?,
      );
    }).toList();
  }

  Future<List<DoctorPatientLink>> _attachDoctorProfiles(
      List<DoctorPatientLink> links) async {
    if (links.isEmpty) return links;
    final ids = links.map((l) => l.doctorId).toList();

    final profiles = await _client
        .from('profiles')
        .select('id, full_name, phone, avatar_url')
        .inFilter('id', ids) as List;

    final verifs = await _client
        .from('doctor_verifications')
        .select('id, hospital')
        .eq('status', 'approved')
        .inFilter('id', ids) as List;

    final profMap  = {for (final p in profiles) p['id'] as String: p};
    final verifMap = {for (final v in verifs)   v['id'] as String: v};

    return links.map((l) {
      final prof  = profMap[l.doctorId]  as Map<String, dynamic>?;
      final verif = verifMap[l.doctorId] as Map<String, dynamic>?;
      return l.copyWith(
        doctorName:     prof?['full_name']  as String?,
        doctorAvatarUrl: prof?['avatar_url'] as String?,
        doctorHospital: verif?['hospital']  as String?,
      );
    }).toList();
  }
}
