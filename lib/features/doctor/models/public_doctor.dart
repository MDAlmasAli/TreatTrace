// public_doctor.dart — Global doctor catalog. No Flutter imports.

class PublicDoctor {
  final String  id;
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

  factory PublicDoctor.fromMap(Map<String, dynamic> m) => PublicDoctor(
        id:             m['id']              as String,
        name:           m['name']            as String,
        specialty:      m['specialty']       as String?,
        hospital:       m['hospital']        as String?,
        chamberAddress: m['chamber_address'] as String?,
        phone:          m['phone']           as String?,
        fee:            m['fee']             as String?,
        imageUrl:       m['image_url']       as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  String get displayName => 'Dr. $name';
}
