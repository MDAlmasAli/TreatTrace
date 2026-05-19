// doctor.dart — Pure Dart model. No Flutter imports.

class Doctor {
  final String  id;
  final String  userId;
  final String  name;
  final String? specialty;
  final String? hospital;
  final String? chamberAddress;
  final String? phone;
  final String? fee;
  final String? notes;
  final bool    isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Doctor({
    required this.id,
    required this.userId,
    required this.name,
    this.specialty,
    this.hospital,
    this.chamberAddress,
    this.phone,
    this.fee,
    this.notes,
    this.isFavorite  = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Doctor.fromMap(Map<String, dynamic> m) => Doctor(
        id:             m['id']              as String,
        userId:         m['user_id']         as String,
        name:           m['name']            as String,
        specialty:      m['specialty']       as String?,
        hospital:       m['hospital']        as String?,
        chamberAddress: m['chamber_address'] as String?,
        phone:          m['phone']           as String?,
        fee:            m['fee']             as String?,
        notes:          m['notes']           as String?,
        isFavorite:     (m['is_favorite'] as bool?) ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'user_id':         userId,
        'name':            name,
        'specialty':       specialty,
        'hospital':        hospital,
        'chamber_address': chamberAddress,
        'phone':           phone,
        'fee':             fee,
        'notes':           notes,
        'is_favorite':     isFavorite,
      };

  Doctor copyWith({
    String?   id,
    String?   userId,
    String?   name,
    String?   specialty,
    String?   hospital,
    String?   chamberAddress,
    String?   phone,
    String?   fee,
    String?   notes,
    bool?     isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Doctor(
        id:             id             ?? this.id,
        userId:         userId         ?? this.userId,
        name:           name           ?? this.name,
        specialty:      specialty      ?? this.specialty,
        hospital:       hospital       ?? this.hospital,
        chamberAddress: chamberAddress ?? this.chamberAddress,
        phone:          phone          ?? this.phone,
        fee:            fee            ?? this.fee,
        notes:          notes          ?? this.notes,
        isFavorite:     isFavorite     ?? this.isFavorite,
        createdAt:      createdAt      ?? this.createdAt,
        updatedAt:      updatedAt      ?? this.updatedAt,
      );

  String get displayName => 'Dr. $name';
}
