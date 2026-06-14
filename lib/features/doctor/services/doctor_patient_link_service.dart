import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_patient_link_model.dart';

class DoctorPatientLinkService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

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
        .select('id, specialty, hospital, full_address, district_id, '
            'districts!district_id(name_en, name_bn), visiting_fee, degree, '
            'visiting_days, visiting_start_time, visiting_end_time, '
            'edit_status, rating_avg, rating_count')
        .eq('status', 'approved')
        .inFilter('id', ids) as List;

    final approvedMap = {for (final v in verifs) v['id'] as String: v};

    return profiles
        // Hide doctors whose profile edit is awaiting approval (on hold).
        .where((p) =>
            approvedMap.containsKey(p['id'] as String) &&
            approvedMap[p['id'] as String]?['edit_status'] != 'pending')
        .map((p) {
          final v = approvedMap[p['id'] as String];
          final dist = v?['districts'] as Map<String, dynamic>?;
          return {
            'id':                  p['id'],
            'full_name':           p['full_name'],
            'avatar_url':          p['avatar_url'],
            'specialty':           v?['specialty'],
            'hospital':            v?['hospital'],
            'full_address':        v?['full_address'],
            'district_id':         v?['district_id'],
            'district':            dist?['name_en'],
            'district_bn':         dist?['name_bn'],
            'visiting_fee':        v?['visiting_fee'],
            'degree':              v?['degree'],
            'visiting_days':       v?['visiting_days'],
            'visiting_start_time': v?['visiting_start_time'],
            'visiting_end_time':   v?['visiting_end_time'],
            'rating_avg':          v?['rating_avg'],
            'rating_count':        v?['rating_count'],
          };
        })
        .toList();
  }

  // ── Auto-link patient after prescription (appointment flow) ──────────────

  Future<void> autoLinkPatient(String patientId) async {
    await _client.rpc(
      'auto_link_appointment_patient',
      params: {'p_patient_id': patientId},
    );
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
          .select('specialty, hospital, degree, visiting_fee, visiting_hours, '
              'full_address, district_id, districts!district_id(name_en, name_bn), '
              'about, edit_status, rating_avg, rating_count')
          .eq('id', doctorId)
          .eq('status', 'approved')
          .maybeSingle(),
    ]);

    final profile = results[0];
    final verif   = results[1];

    if (profile == null) return null;

    final dist = verif?['districts'] as Map<String, dynamic>?;
    return {
      'id':           doctorId,
      'full_name':    profile['full_name'],
      'avatar_url':   profile['avatar_url'],
      'email':        profile['email'],
      'specialty':    verif?['specialty'],
      'hospital':     verif?['hospital'],
      'degree':       verif?['degree'],
      'visiting_fee':   verif?['visiting_fee'],
      'visiting_hours': verif?['visiting_hours'],
      'full_address':   verif?['full_address'],
      'district_id':    verif?['district_id'],
      'district':       dist?['name_en'],
      'district_bn':    dist?['name_bn'],
      'about':          verif?['about'],
      'edit_status':    verif?['edit_status'],   // 'pending' = on hold
      'rating_avg':     verif?['rating_avg'],
      'rating_count':   verif?['rating_count'],
    };
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<List<DoctorPatientLink>> _attachPatientProfiles(
      List<DoctorPatientLink> links) async {
    if (links.isEmpty) return links;
    final ids = links.map((l) => l.patientId).toList();
    final profiles = await _client
        .from('profiles')
        .select('id, full_name, username, phone, avatar_url')
        .inFilter('id', ids) as List;

    final map = {for (final p in profiles) p['id'] as String: p};
    return links.map((l) {
      final prof = map[l.patientId] as Map<String, dynamic>?;
      return l.copyWith(
        patientName:      prof?['full_name']  as String?,
        patientUsername:  prof?['username']   as String?,
        patientPhone:     prof?['phone']      as String?,
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
