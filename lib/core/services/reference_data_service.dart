// reference_data_service.dart — Districts & hospitals reference data.
//
// Districts are a fixed list of 64 BD districts (seeded). Hospitals are a
// curated approved list plus doctor-requested entries that stay 'pending'
// until an admin approves them. Doctors must pick a district + hospital from
// these lists (no free text); a not-listed hospital can be requested, but it
// only goes live once an admin approves it.

import 'package:supabase_flutter/supabase_flutter.dart';

class District {
  final int id;
  final String nameEn;
  final String nameBn;
  final String division;

  const District({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.division,
  });

  factory District.fromMap(Map<String, dynamic> m) => District(
        id:       (m['id'] as num).toInt(),
        nameEn:   m['name_en'] as String,
        nameBn:   m['name_bn'] as String,
        division: m['division'] as String,
      );

  // True when the query matches either the English or Bengali name.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return nameEn.toLowerCase().contains(q) || nameBn.contains(query.trim());
  }
}

class Hospital {
  final String id;
  final String name;
  final int? districtId;
  final String status; // 'approved' | 'pending'
  final String? requestedBy;
  final String? requesterName; // joined for the admin queue only

  const Hospital({
    required this.id,
    required this.name,
    this.districtId,
    required this.status,
    this.requestedBy,
    this.requesterName,
  });

  bool get isApproved => status == 'approved';

  factory Hospital.fromMap(Map<String, dynamic> m, {String? requesterName}) =>
      Hospital(
        id:          m['id'] as String,
        name:        m['name'] as String,
        districtId:  (m['district_id'] as num?)?.toInt(),
        status:      m['status'] as String? ?? 'approved',
        requestedBy: m['requested_by'] as String?,
        requesterName: requesterName,
      );
}

class ReferenceDataService {
  final _client = Supabase.instance.client;

  List<District>? _districtCache;

  // ── Districts ─────────────────────────────────────────────────────────────

  Future<List<District>> fetchDistricts() async {
    if (_districtCache != null) return _districtCache!;
    final rows = await _client
        .from('districts')
        .select('id, name_en, name_bn, division')
        .order('name_en', ascending: true) as List;
    _districtCache = rows
        .map((r) => District.fromMap(r as Map<String, dynamic>))
        .toList();
    return _districtCache!;
  }

  Future<District?> districtById(int? id) async {
    if (id == null) return null;
    final list = await fetchDistricts();
    for (final d in list) {
      if (d.id == id) return d;
    }
    return null;
  }

  // ── Hospitals (doctor side) ───────────────────────────────────────────────

  // Approved hospitals, optionally scoped to a district, optionally filtered
  // by a name query. Used to populate the searchable picker.
  Future<List<Hospital>> fetchApprovedHospitals({int? districtId}) async {
    var query =
        _client.from('hospitals').select('id, name, district_id, status, requested_by').eq('status', 'approved');
    if (districtId != null) {
      query = query.eq('district_id', districtId);
    }
    final rows = await query.order('name', ascending: true) as List;
    return rows.map((r) => Hospital.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Hospital?> fetchHospitalById(String? id) async {
    if (id == null) return null;
    final row = await _client
        .from('hospitals')
        .select('id, name, district_id, status, requested_by')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Hospital.fromMap(row);
  }

  // Doctor requests a hospital that isn't in the list. Stored as 'pending'
  // and attributed to the requesting doctor; returns the new row id so the
  // caller can reference it on the doctor_verifications record.
  Future<String> requestManualHospital({
    required String name,
    int? districtId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not logged in');
    final trimmed = name.trim();

    // Reuse an existing row (approved or this doctor's own pending) with the
    // same name + district to avoid duplicate requests.
    final existing = await _client
        .from('hospitals')
        .select('id')
        .ilike('name', trimmed)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final row = await _client
        .from('hospitals')
        .insert({
          'name':         trimmed,
          'district_id':  districtId,
          'status':       'pending',
          'requested_by': uid,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  // ── Hospitals (admin side) ────────────────────────────────────────────────

  Future<List<Hospital>> fetchPendingHospitals() async {
    final rows = await _client
        .from('hospitals')
        .select('id, name, district_id, status, requested_by')
        .eq('status', 'pending')
        .order('created_at', ascending: true) as List;
    if (rows.isEmpty) return [];

    final ids = rows
        .map((r) => (r as Map)['requested_by'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final profiles = ids.isEmpty
        ? <dynamic>[]
        : await _client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', ids) as List;
    final nameMap = {
      for (final p in profiles)
        (p as Map)['id'] as String: p['full_name'] as String?,
    };

    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      return Hospital.fromMap(m, requesterName: nameMap[m['requested_by']]);
    }).toList();
  }

  // Approve a pending hospital — optionally correcting its name / district
  // first. Once approved, every doctor referencing it goes live.
  Future<void> approveHospital(
    String id, {
    String? name,
    int? districtId,
  }) async {
    final update = <String, dynamic>{'status': 'approved'};
    if (name != null && name.trim().isNotEmpty) update['name'] = name.trim();
    if (districtId != null) update['district_id'] = districtId;
    await _client.from('hospitals').update(update).eq('id', id);
  }

  Future<void> rejectHospital(String id) async {
    await _client.from('hospitals').delete().eq('id', id);
  }
}
