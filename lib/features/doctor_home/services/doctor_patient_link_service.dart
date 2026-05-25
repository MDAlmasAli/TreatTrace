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
        .select('id, specialty, hospital, visiting_fee, degree')
        .eq('status', 'approved')
        .inFilter('id', ids) as List;

    final approvedMap = {for (final v in verifs) v['id'] as String: v};

    return profiles
        .where((p) => approvedMap.containsKey(p['id'] as String))
        .map((p) => {
              'id':           p['id'],
              'full_name':    p['full_name'],
              'avatar_url':   p['avatar_url'],
              'specialty':    approvedMap[p['id'] as String]?['specialty'],
              'hospital':     approvedMap[p['id'] as String]?['hospital'],
              'visiting_fee': approvedMap[p['id'] as String]?['visiting_fee'],
              'degree':       approvedMap[p['id'] as String]?['degree'],
            })
        .toList();
  }

  // ── Doctor: patients who booked appointments but aren't linked yet ────────
  // Returns each patient with their current link status:
  //   link_status == null    → no request sent yet → show "Send Request"
  //   link_status == 'pending'  → request sent, waiting → show "Pending"
  //   link_status == 'rejected' → patient rejected → show "Resend"

  Future<List<Map<String, dynamic>>> fetchPatientRequests() async {
    final uid = _uid;
    if (uid == null) return [];

    // 1. All patients who booked appointments with this doctor
    final apptRows = await _client
        .from('appointments')
        .select('user_id')
        .eq('doctor_user_id', uid) as List;

    final patientIds = apptRows
        .map((r) => r['user_id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (patientIds.isEmpty) return [];

    // 2. Existing link statuses for those patients
    final linkRows = await _client
        .from('doctor_patient_links')
        .select('patient_id, status, id')
        .eq('doctor_id', uid)
        .inFilter('patient_id', patientIds) as List;

    final linkMap = <String, Map<String, dynamic>>{
      for (final l in linkRows)
        l['patient_id'] as String: l as Map<String, dynamic>,
    };

    // 3. Exclude already-accepted patients
    final visibleIds = patientIds
        .where((id) => (linkMap[id]?['status'] as String?) != 'accepted')
        .toList();

    if (visibleIds.isEmpty) return [];

    // 4. Fetch profiles
    final profiles = await _client
        .from('profiles')
        .select('id, full_name, phone, avatar_url')
        .inFilter('id', visibleIds) as List;

    return profiles.map((p) {
      final id = p['id'] as String;
      final link = linkMap[id];
      return {
        'id':          id,
        'full_name':   p['full_name'],
        'phone':       p['phone'],
        'avatar_url':  p['avatar_url'],
        'link_id':     link?['id'],
        'link_status': link?['status'], // null | 'pending' | 'rejected'
      };
    }).toList();
  }

  // ── Fetch a single doctor's full public profile ───────────────────────────

  Future<Map<String, dynamic>?> fetchDoctorPublicProfile(String doctorId) async {
    final results = await Future.wait([
      _client
          .from('profiles')
          .select('id, full_name, avatar_url, email')
          .eq('id', doctorId)
          .maybeSingle(),
      _client
          .from('doctor_verifications')
          .select('specialty, hospital, degree, visiting_fee, about')
          .eq('id', doctorId)
          .eq('status', 'approved')
          .maybeSingle(),
    ]);

    final profile = results[0];
    final verif   = results[1];

    if (profile == null) return null;

    return {
      'id':           doctorId,
      'full_name':    profile['full_name'],
      'avatar_url':   profile['avatar_url'],
      'email':        profile['email'],
      'specialty':    verif?['specialty'],
      'hospital':     verif?['hospital'],
      'degree':       verif?['degree'],
      'visiting_fee': verif?['visiting_fee'],
      'about':        verif?['about'],
    };
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
