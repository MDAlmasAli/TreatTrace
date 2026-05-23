// public_doctor.dart — Verified doctor from doctor_verifications + profiles.

class PublicDoctor {
  final String  id;          // doctor's user_id
  final String  name;
  final String? specialty;
  final String? hospital;
  final String? chamberAddress;
  final String? phone;
  final String? fee;
  final String? imageUrl;
  final DateTime createdAt;

  const PublicDoctor({
    required this.id,
    required this.name,
    this.specialty,
    this.hospital,
    this.chamberAddress,
    this.phone,
    this.fee,
    this.imageUrl,
    required this.createdAt,
  });

  factory PublicDoctor.fromMap(Map<String, dynamic> m) {
    final prof = m['profiles'] as Map<String, dynamic>? ?? {};
    final ts   = m['reviewed_at'] as String? ?? m['submitted_at'] as String?;
    return PublicDoctor(
      id:             m['id'] as String,
      name:           prof['full_name'] as String? ?? 'Unknown Doctor',
      specialty:      m['specialty']    as String?,
      hospital:       m['hospital']     as String?,
      chamberAddress: null,
      phone:          prof['phone']     as String?,
      fee:            null,
      imageUrl:       prof['avatar_url'] as String?,
      createdAt:      ts != null ? DateTime.parse(ts) : DateTime.now(),
    );
  }

  String get displayName => 'Dr. $name';
}
