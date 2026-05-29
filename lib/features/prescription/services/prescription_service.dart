// prescription_service.dart
// All Supabase CRUD for prescriptions + prescription_medicines.
// Also handles image upload to the 'prescriptions' storage bucket.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prescription.dart';
import '../models/prescription_medicine.dart';

class PrescriptionService {
  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  // ── Fetch all prescriptions (with medicines) ──────────────────────────────

  Future<List<Prescription>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _client
        .from('prescriptions')
        .select('*, prescription_medicines(*)')
        .eq('user_id', uid)
        .order('prescription_date', ascending: false);

    return rows.map((row) {
      final medRows = (row['prescription_medicines'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final meds = medRows.map(PrescriptionMedicine.fromMap).toList();
      return Prescription.fromMap(row, medicines: meds);
    }).toList();
  }

  // ── Fetch single prescription (with medicines) ────────────────────────────

  Future<Prescription?> fetchOne(String id) async {
    final row = await _client
        .from('prescriptions')
        .select('*, prescription_medicines(*)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final meds = (row['prescription_medicines'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(PrescriptionMedicine.fromMap)
        .toList();
    return Prescription.fromMap(row, medicines: meds);
  }

  // ── Create prescription + medicines (in a single round-trip sequence) ─────

  Future<Prescription> create({
    required Prescription prescription,
    required List<PrescriptionMedicine> medicines,
  }) async {
    final inserted = await _client
        .from('prescriptions')
        .insert({...prescription.toMap(), 'user_id': _uid})
        .select()
        .single();

    final newId = inserted['id'] as String;

    List<PrescriptionMedicine> savedMeds = [];
    if (medicines.isNotEmpty) {
      final medRows = medicines
          .map((m) => {...m.toMap(), 'prescription_id': newId})
          .toList();
      final insertedMeds = await _client
          .from('prescription_medicines')
          .insert(medRows)
          .select();
      savedMeds =
          insertedMeds.map((r) => PrescriptionMedicine.fromMap(r)).toList();
    }

    return Prescription.fromMap(inserted, medicines: savedMeds);
  }

  // ── Update prescription header ────────────────────────────────────────────

  Future<void> updateHeader(Prescription prescription) async {
    await _client
        .from('prescriptions')
        .update(prescription.toMap())
        .eq('id', prescription.id);
  }

  // ── Replace medicines for a prescription (delete all then re-insert) ──────

  Future<void> replaceMedicines(
      String prescriptionId, List<PrescriptionMedicine> medicines) async {
    await _client
        .from('prescription_medicines')
        .delete()
        .eq('prescription_id', prescriptionId);

    if (medicines.isNotEmpty) {
      final rows = medicines
          .map((m) => {...m.toMap(), 'prescription_id': prescriptionId})
          .toList();
      await _client.from('prescription_medicines').insert(rows);
    }
  }

  // ── Delete prescription (medicines cascade via FK) ────────────────────────

  Future<void> delete(String id) async {
    final row = await _client
        .from('prescriptions')
        .select('image_urls')
        .eq('id', id)
        .maybeSingle();
    final urls = (row?['image_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    for (final url in urls) {
      await _deleteImageByUrl(url);
    }
    await _client.from('prescriptions').delete().eq('id', id);
  }

  // ── Remove one image from a prescription's image_urls array ───────────────

  Future<void> removeImage(String prescriptionId, String imageUrl) async {
    final row = await _client
        .from('prescriptions')
        .select('image_urls')
        .eq('id', prescriptionId)
        .maybeSingle();
    final urls = (row?['image_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    final updated = urls.where((u) => u != imageUrl).toList();
    await _client
        .from('prescriptions')
        .update({'image_urls': updated})
        .eq('id', prescriptionId);
    await _deleteImageByUrl(imageUrl);
  }

  // ── Upload prescription image ─────────────────────────────────────────────

  Future<String?> uploadImage(XFile file) async {
    final uid = _uid;
    if (uid == null) return null;

    final ext         = file.path.split('.').last.toLowerCase();
    final contentType = _mimeFromExt(ext);
    final path        = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final opts        = FileOptions(upsert: true, contentType: contentType);

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await _client.storage.from('prescriptions').uploadBinary(path, bytes, fileOptions: opts);
    } else {
      await _client.storage.from('prescriptions').upload(path, File(file.path), fileOptions: opts);
    }

    return await _client.storage.from('prescriptions').createSignedUrl(path, 315360000);
  }

  // ── Upload document (PDF, DOC, etc.) to prescriptions bucket ─────────────────

  Future<String?> uploadDocument(PlatformFile file) async {
    final uid = _uid;
    if (uid == null) return null;

    final ext  = (file.extension ?? 'pdf').toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final opts = FileOptions(upsert: true, contentType: _mimeFromDocExt(ext));

    if (file.bytes != null) {
      await _client.storage.from('prescriptions').uploadBinary(path, file.bytes!, fileOptions: opts);
    } else if (file.path != null) {
      await _client.storage.from('prescriptions').upload(path, File(file.path!), fileOptions: opts);
    } else {
      return null;
    }

    return await _client.storage.from('prescriptions').createSignedUrl(path, 315360000);
  }

  static String _mimeFromDocExt(String ext) {
    switch (ext) {
      case 'pdf':  return 'application/pdf';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:     return 'application/octet-stream';
    }
  }

  static String _mimeFromExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      case 'heic':
      case 'heif': return 'image/heif';
      default:     return 'image/jpeg';
    }
  }

  Future<void> _deleteImageByUrl(String url) async {
    try {
      // Signed URL path: extract the object path after /object/sign/prescriptions/
      // or /object/public/prescriptions/
      for (final marker in [
        '/object/sign/prescriptions/',
        '/object/public/prescriptions/',
      ]) {
        final idx = url.indexOf(marker);
        if (idx != -1) {
          // Strip query params (token=...)
          var path = url.substring(idx + marker.length);
          final qIdx = path.indexOf('?');
          if (qIdx != -1) path = path.substring(0, qIdx);
          await _client.storage.from('prescriptions').remove([path]);
          return;
        }
      }
    } catch (_) {}
  }

  // ── Doctor: fetch all prescriptions for a specific patient ───────────────

  Future<List<Prescription>> fetchForPatient(String patientId) async {
    final rows = await _client
        .from('prescriptions')
        .select('*, prescription_medicines(*)')
        .eq('user_id', patientId)
        .order('prescription_date', ascending: false);

    return rows.map((row) {
      final medRows = (row['prescription_medicines'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      return Prescription.fromMap(row, medicines: medRows.map(PrescriptionMedicine.fromMap).toList());
    }).toList();
  }

  // ── Doctor: create prescription for a linked patient ─────────────────────

  Future<Prescription> createForPatient({
    required String patientId,
    required Prescription prescription,
    required List<PrescriptionMedicine> medicines,
  }) async {
    final doctorId = _uid;
    if (doctorId == null) throw Exception('Not authenticated');

    final inserted = await _client
        .from('prescriptions')
        .insert({
          ...prescription.toMap(),
          'user_id':              patientId,
          'written_by_doctor_id': doctorId,
        })
        .select()
        .single();

    final newId = inserted['id'] as String;
    List<PrescriptionMedicine> savedMeds = [];
    if (medicines.isNotEmpty) {
      final medRows = medicines
          .map((m) => {...m.toMap(), 'prescription_id': newId})
          .toList();
      final insertedMeds = await _client
          .from('prescription_medicines')
          .insert(medRows)
          .select();
      savedMeds = insertedMeds.map((r) => PrescriptionMedicine.fromMap(r)).toList();
    }
    return Prescription.fromMap(inserted, medicines: savedMeds);
  }

  // ── Doctor: update own prescription + replace medicines ──────────────────

  Future<void> updateForDoctor({
    required String prescriptionId,
    required String? diagnosis,
    required DateTime date,
    required String? notes,
    required List<String> imageUrls,
    required List<PrescriptionMedicine> medicines,
  }) async {
    final doctorId = _uid;
    if (doctorId == null) throw Exception('Not authenticated');

    await _client.from('prescriptions').update({
      'diagnosis':         diagnosis,
      'prescription_date': date.toIso8601String().substring(0, 10),
      'notes':             notes,
      'image_urls':        imageUrls,
    })
        .eq('id', prescriptionId)
        .eq('written_by_doctor_id', doctorId); // safety: only own prescriptions

    await replaceMedicines(prescriptionId, medicines);
  }

  // ── Edit log (one row per prescription per day) ───────────────────────────

  Future<void> logEdit(String prescriptionId, {String action = 'edited'}) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('prescription_edit_logs').upsert(
        {
          'prescription_id': prescriptionId,
          'doctor_id':       uid,
          'action_date':     DateTime.now().toIso8601String().substring(0, 10),
          'action':          action,
        },
        onConflict:       'prescription_id,action_date',
        ignoreDuplicates: true,
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> fetchEditLogs(String prescriptionId) async {
    final rows = await _client
        .from('prescription_edit_logs')
        .select()
        .eq('prescription_id', prescriptionId)
        .order('action_date', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }

  // ── Allergy cross-check ───────────────────────────────────────────────────
  // Returns a list of medicine names that appear in the user's allergy string.

  List<String> checkAllergyConflicts(
      List<PrescriptionMedicine> medicines, String? allergies) {
    if (allergies == null || allergies.trim().isEmpty) return [];
    final allergyLower = allergies.toLowerCase();
    return medicines
        .where((m) => allergyLower.contains(m.medicineName.toLowerCase()))
        .map((m) => m.medicineName)
        .toList();
  }
}
