// review_service.dart — Supabase access for the doctor review system.
//
// Reviews are anonymous to everyone but their author: the public list comes
// from the `get_doctor_reviews` RPC (which never returns patient_id), while a
// patient reads/edits only their own row directly.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_review_model.dart';

class ReviewNotAllowedException implements Exception {
  final String message;
  ReviewNotAllowedException([
    this.message = 'You can review a doctor only after a completed appointment.',
  ]);
  @override
  String toString() => message;
}

class ReviewService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // Anonymous public list for a doctor (rating + comment + date only).
  Future<List<DoctorReview>> fetchForDoctor(String doctorId) async {
    final rows = await _client
        .rpc('get_doctor_reviews', params: {'p_doctor': doctorId}) as List;
    return rows
        .map((r) => DoctorReview.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  // The current user's own review for this doctor (null if none).
  Future<({int rating, String? comment})?> myReview(String doctorId) async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _client
        .from('doctor_reviews')
        .select('rating, comment')
        .eq('doctor_user_id', doctorId)
        .eq('patient_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return (
      rating:  (row['rating'] as num).toInt(),
      comment: row['comment'] as String?,
    );
  }

  // Whether the user is eligible to review (has a completed appointment).
  Future<bool> canReview(String doctorId) async {
    try {
      final res =
          await _client.rpc('can_review_doctor', params: {'p_doctor': doctorId});
      return res == true;
    } catch (_) {
      return false;
    }
  }

  // Create or update the user's review. The DB trigger enforces eligibility.
  Future<void> upsertReview(
      String doctorId, int rating, String? comment) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    try {
      await _client.from('doctor_reviews').upsert({
        'doctor_user_id': doctorId,
        'patient_id':     uid,
        'rating':         rating,
        'comment':        (comment?.trim().isEmpty ?? true) ? null : comment!.trim(),
      }, onConflict: 'doctor_user_id,patient_id');
    } on PostgrestException catch (e) {
      if (e.message.contains('REVIEW_NOT_ALLOWED')) {
        throw ReviewNotAllowedException();
      }
      rethrow;
    }
  }

  Future<void> deleteReview(String doctorId) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('doctor_reviews')
        .delete()
        .eq('doctor_user_id', doctorId)
        .eq('patient_id', uid);
  }

  // The most recent completed appointment (with a registered doctor) that the
  // patient hasn't been prompted to review yet. Null if none.
  Future<({String appointmentId, String doctorId, String doctorName})?>
      fetchPendingReviewAppointment() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('appointments')
          .select('id, doctor_user_id, doctor_name_snapshot')
          .eq('user_id', uid)
          .eq('status', 'completed')
          .eq('review_prompted', false)
          .not('doctor_user_id', 'is', null)
          .order('appointment_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return (
        appointmentId: row['id'] as String,
        doctorId:      row['doctor_user_id'] as String,
        doctorName:    (row['doctor_name_snapshot'] as String?)?.trim().isNotEmpty == true
            ? row['doctor_name_snapshot'] as String
            : 'your doctor',
      );
    } catch (_) {
      return null;
    }
  }

  // Mark an appointment as already prompted (after submit or skip).
  Future<void> markPrompted(String appointmentId) async {
    try {
      await _client
          .from('appointments')
          .update({'review_prompted': true})
          .eq('id', appointmentId);
    } catch (_) {}
  }

  // Aggregate for a doctor (used by the doctor's own portal).
  Future<({double avg, int count})> rating(String doctorId) async {
    try {
      final row = await _client
          .from('doctor_verifications')
          .select('rating_avg, rating_count')
          .eq('id', doctorId)
          .maybeSingle();
      return (
        avg:   (row?['rating_avg'] as num?)?.toDouble() ?? 0.0,
        count: (row?['rating_count'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return (avg: 0.0, count: 0);
    }
  }
}
