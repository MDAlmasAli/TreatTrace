// test_report_service.dart
// Supabase CRUD for test_reports + image upload to the 'test_reports' bucket.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/test_report.dart';

class TestReportService {
  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  // ── Fetch all reports for current user ───────────────────────────────────

  Future<List<TestReport>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _client
        .from('test_reports')
        .select()
        .eq('user_id', uid)
        .order('test_date', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);

    return rows.map((r) => TestReport.fromMap(r)).toList();
  }

  // ── Fetch single report ───────────────────────────────────────────────────

  Future<TestReport?> fetchOne(String id) async {
    final row = await _client
        .from('test_reports')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : TestReport.fromMap(row);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<TestReport> create(TestReport report) async {
    final inserted = await _client
        .from('test_reports')
        .insert({...report.toMap(), 'user_id': _uid})
        .select()
        .single();
    return TestReport.fromMap(inserted);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> update(TestReport report) async {
    final payload = Map<String, dynamic>.from(report.toMap())
      ..remove('user_id');
    await _client
        .from('test_reports')
        .update(payload)
        .eq('id', report.id);
  }

  // ── Delete (also cleans up storage images) ───────────────────────────────

  Future<void> delete(String id) async {
    final row = await _client
        .from('test_reports')
        .select('image_urls')
        .eq('id', id)
        .maybeSingle();
    final urls = (row?['image_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    for (final url in urls) {
      await _deleteImageByUrl(url);
    }
    await _client.from('test_reports').delete().eq('id', id);
  }

  // ── Remove one image from image_urls ─────────────────────────────────────

  Future<void> removeImage(String reportId, String imageUrl) async {
    final row = await _client
        .from('test_reports')
        .select('image_urls')
        .eq('id', reportId)
        .maybeSingle();
    final urls = (row?['image_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    final updated = urls.where((u) => u != imageUrl).toList();
    await _client
        .from('test_reports')
        .update({'image_urls': updated})
        .eq('id', reportId);
    await _deleteImageByUrl(imageUrl);
  }

  // ── Upload image to test_reports bucket ───────────────────────────────────

  Future<String?> uploadImage(XFile file) async {
    final uid = _uid;
    if (uid == null) return null;

    final ext         = file.path.split('.').last.toLowerCase();
    final contentType = _mimeFromExt(ext);
    final path        = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final opts        = FileOptions(upsert: true, contentType: contentType);

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await _client.storage.from('test_reports').uploadBinary(path, bytes, fileOptions: opts);
    } else {
      await _client.storage.from('test_reports').upload(path, File(file.path), fileOptions: opts);
    }

    return await _client.storage.from('test_reports').createSignedUrl(path, 315360000);
  }

  // ── Upload document (PDF, DOC, etc.) to test_reports bucket ──────────────────

  Future<String?> uploadDocument(PlatformFile file) async {
    final uid = _uid;
    if (uid == null) return null;

    final ext  = (file.extension ?? 'pdf').toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final opts = FileOptions(upsert: true, contentType: _mimeFromDocExt(ext));

    if (file.bytes != null) {
      await _client.storage.from('test_reports').uploadBinary(path, file.bytes!, fileOptions: opts);
    } else if (file.path != null) {
      await _client.storage.from('test_reports').upload(path, File(file.path!), fileOptions: opts);
    } else {
      return null;
    }

    return await _client.storage.from('test_reports').createSignedUrl(path, 315360000);
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

  // ── Doctor: fetch test reports for a specific patient ─────────────────────

  Future<List<TestReport>> fetchForPatient(String patientId) async {
    final rows = await _client
        .from('test_reports')
        .select()
        .eq('user_id', patientId)
        .order('test_date', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);
    return rows.map((r) => TestReport.fromMap(r)).toList();
  }

  // ── Doctor: create a test report for a linked patient ─────────────────────

  Future<TestReport> createForPatient({
    required String   patientId,
    required TestReport report,
  }) async {
    final doctorId = _uid;
    if (doctorId == null) throw Exception('Not authenticated');
    final inserted = await _client.from('test_reports').insert({
      ...report.toMap(),
      'user_id':              patientId,
      'ordered_by_doctor_id': doctorId,
    }).select().single();
    return TestReport.fromMap(inserted);
  }

  // ── Doctor: update a test report they ordered ──────────────────────────────

  Future<void> updateForDoctor(TestReport report) async {
    final doctorId = _uid;
    if (doctorId == null) throw Exception('Not authenticated');
    await _client.from('test_reports')
        .update(report.toMap())
        .eq('id', report.id)
        .eq('ordered_by_doctor_id', doctorId);
  }

  // ── Fetch all distinct categories used by this user ──────────────────────

  Future<List<String>> fetchCategories() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('test_reports')
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
      // Check both buckets: new uploads use test_reports, legacy files use lab_reports.
      for (final bucket in ['test_reports', 'lab_reports']) {
        for (final prefix in ['/object/sign/$bucket/', '/object/public/$bucket/']) {
          final idx = url.indexOf(prefix);
          if (idx != -1) {
            var path = url.substring(idx + prefix.length);
            final qIdx = path.indexOf('?');
            if (qIdx != -1) path = path.substring(0, qIdx);
            await _client.storage.from(bucket).remove([path]);
            return;
          }
        }
      }
    } catch (_) {}
  }
}
