// prescription_service.dart
// All Supabase CRUD for prescriptions + prescription_medicines.
// Also handles image upload to the 'prescriptions' storage bucket.

import 'dart:io';
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

    final ext  = file.path.split('.').last.toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await _client.storage
          .from('prescriptions')
          .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true));
    } else {
      await _client.storage
          .from('prescriptions')
          .upload(path, File(file.path), fileOptions: FileOptions(upsert: true));
    }

    // Private bucket → signed URL valid for 10 years
    return await _client.storage
        .from('prescriptions')
        .createSignedUrl(path, 315360000);
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
    required List<PrescriptionMedicine> medicines,
  }) async {
    final doctorId = _uid;
    if (doctorId == null) throw Exception('Not authenticated');

    await _client.from('prescriptions').update({
      'diagnosis':         diagnosis,
      'prescription_date': date.toIso8601String().substring(0, 10),
      'notes':             notes,
    })
        .eq('id', prescriptionId)
        .eq('written_by_doctor_id', doctorId); // safety: only own prescriptions

    await replaceMedicines(prescriptionId, medicines);
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
