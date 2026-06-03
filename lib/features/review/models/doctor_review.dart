// doctor_review.dart — Pure Dart model. Reviews are anonymous: no patient
// identity is ever carried (the public RPC only returns rating/comment/date).

class DoctorReview {
  final int      rating; // 1..5
  final String?  comment;
  final DateTime createdAt;

  const DoctorReview({
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory DoctorReview.fromMap(Map<String, dynamic> m) => DoctorReview(
        rating:    (m['rating'] as num).toInt(),
        comment:   (m['comment'] as String?)?.trim().isEmpty == true
            ? null
            : m['comment'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
