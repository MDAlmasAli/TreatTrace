// lab_report_service.dart
// Supabase CRUD for lab_reports + image upload to the 'lab_reports' bucket.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lab_report.dart';

class LabReportService {
  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  // ── Fetch all reports for current user ───────────────────────────────────

  Future<List<LabReport>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _client
        .from('lab_reports')
        .select()
        .eq('user_id', uid)
        .order('test_date', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);

    return rows.map((r) => LabReport.fromMap(r)).toList();
  }

  // ── Fetch single report ───────────────────────────────────────────────────

  Future<LabReport?> fetchOne(String id) async {
    final row = await _client
        .from('lab_reports')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : LabReport.fromMap(row);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<LabReport> create(LabReport report) async {
    final inserted = await _client
        .from('lab_reports')
        .insert({...report.toMap(), 'user_id': _uid})
        .select()
        .single();
    return LabReport.fromMap(inserted);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> update(LabReport report) async {
    await _client
        .from('lab_reports')
        .update(report.toMap())
        .eq('id', report.id);
  }

  // ── Delete (also cleans up storage images) ───────────────────────────────

  Future<void> delete(String id) async {
    final row = await _client
        .from('lab_reports')
        .select('image_urls')
        .eq('id', id)
        .maybeSingle();
    final urls = (row?['image_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    for (final url in urls) {
      await _deleteImageByUrl(url);
    }
    await _client.from('lab_reports').delete().eq('id', id);
  }

  // ── Remove one image from image_urls ─────────────────────────────────────

  Future<void> removeImage(String reportId, String imageUrl) async {
    final row = await _client
        .from('lab_reports')
        .select('image_urls')
        .eq('id', reportId)
        .maybeSingle();
    final urls = (row?['image_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    final updated = urls.where((u) => u != imageUrl).toList();
    await _client
        .from('lab_reports')
        .update({'image_urls': updated})
        .eq('id', reportId);
    await _deleteImageByUrl(imageUrl);
  }

  // ── Upload image to lab_reports bucket ───────────────────────────────────

  Future<String?> uploadImage(XFile file) async {
    final uid = _uid;
    if (uid == null) return null;

    final ext  = file.path.split('.').last.toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await _client.storage
          .from('lab_reports')
          .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true));
    } else {
      await _client.storage
          .from('lab_reports')
          .upload(path, File(file.path), fileOptions: FileOptions(upsert: true));
    }

    return await _client.storage
        .from('lab_reports')
        .createSignedUrl(path, 315360000); // 10 years
  }

  // ── Doctor: fetch lab reports for a specific patient ─────────────────────

  Future<List<LabReport>> fetchForPatient(String patientId) async {
    final rows = await _client
        .from('lab_reports')
        .select()
        .eq('user_id', patientId)
        .order('test_date', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);
    return rows.map((r) => LabReport.fromMap(r)).toList();
  }

  // ── Doctor: create a lab report for a linked patient ─────────────────────

  Future<LabReport> createForPatient({
    required String   patientId,
    required LabReport report,
  }) async {
    final doctorId = _uid;
    if (doctorId == null) throw Exception('Not authenticated');
    final inserted = await _client.from('lab_reports').insert({
      ...report.toMap(),
      'user_id':              patientId,
      'ordered_by_doctor_id': doctorId,
    }).select().single();
    return LabReport.fromMap(inserted);
  }

  // ── Doctor: update a lab report they ordered ──────────────────────────────

  Future<void> updateForDoctor(LabReport report) async {
    final doctorId = _uid;
    if (doctorId == null) throw Exception('Not authenticated');
    await _client.from('lab_reports')
        .update(report.toMap())
        .eq('id', report.id)
        .eq('ordered_by_doctor_id', doctorId);
  }

  // ── Fetch all distinct categories used by this user ──────────────────────

  Future<List<String>> fetchCategories() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('lab_reports')
        .select('category')
        .eq('user_id', uid)
        .not('category', 'is', null);

    final seen  = <String>{};
    final cats  = <String>[];
    for (final r in rows) {
      final cat = r['category'] as String?;
      if (cat != null && cat.isNotEmpty && seen.add(cat)) {
        cats.add(cat);
      }
    }
    cats.sort();
    return cats;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _deleteImageByUrl(String url) async {
    try {
      for (final marker in [
        '/object/sign/lab_reports/',
        '/object/public/lab_reports/',
      ]) {
        final idx = url.indexOf(marker);
        if (idx != -1) {
          var path = url.substring(idx + marker.length);
          final qIdx = path.indexOf('?');
          if (qIdx != -1) path = path.substring(0, qIdx);
          await _client.storage.from('lab_reports').remove([path]);
          return;
        }
      }
    } catch (_) {}
  }
}
