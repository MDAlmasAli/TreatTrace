// prescription.dart — Pure Dart model. No Flutter imports.

import 'prescription_medicine.dart';

class Prescription {
  final String   id;
  final String   userId;
  final String?  doctorName;
  final String?  doctorSpecialty;
  final String?  doctorHospital;
  final String?  doctorPhone;
  final String?  diagnosis;
  final DateTime prescriptionDate;
  final List<String> imageUrls;
  final String?  notes;
  final DateTime createdAt;
  final List<PrescriptionMedicine> medicines;
  final List<String> allergyConflicts;

  const Prescription({
    required this.id,
    required this.userId,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorHospital,
    this.doctorPhone,
    this.diagnosis,
    required this.prescriptionDate,
    this.imageUrls        = const [],
    this.notes,
    required this.createdAt,
    this.medicines        = const [],
    this.allergyConflicts = const [],
  });

  // ── Computed ──────────────────────────────────────────────────────────────

  bool get isActive {
    if (medicines.isEmpty) return true;
    return medicines.any((m) => m.isActive);
  }

  bool get needsRefillSoon => medicines.any((m) => m.needsRefillSoon);
  bool get hasAllergyConflict => allergyConflicts.isNotEmpty;
  bool get hasImages => imageUrls.isNotEmpty;

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory Prescription.fromMap(
    Map<String, dynamic> m, {
    List<PrescriptionMedicine> medicines = const [],
  }) =>
      Prescription(
        id:               m['id']               as String,
        userId:           m['user_id']          as String,
        doctorName:       m['doctor_name']      as String?,
        doctorSpecialty:  m['doctor_specialty'] as String?,
        doctorHospital:   m['doctor_hospital']  as String?,
        doctorPhone:      m['doctor_phone']     as String?,
        diagnosis:        m['diagnosis']        as String?,
        prescriptionDate: DateTime.parse(m['prescription_date'] as String),
        imageUrls: (m['image_urls'] as List<dynamic>?)
                ?.cast<String>() ??
            [],
        notes:     m['notes']    as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        medicines: medicines,
      );

  Map<String, dynamic> toMap() => {
        'user_id':           userId,
        'doctor_name':       doctorName,
        'doctor_specialty':  doctorSpecialty,
        'doctor_hospital':   doctorHospital,
        'doctor_phone':      doctorPhone,
        'diagnosis':         diagnosis,
        'prescription_date': prescriptionDate.toIso8601String().substring(0, 10),
        'image_urls':        imageUrls,
        'notes':             notes,
      };

  Prescription copyWith({
    String?   id,
    String?   userId,
    String?   doctorName,
    String?   doctorSpecialty,
    String?   doctorHospital,
    String?   doctorPhone,
    String?   diagnosis,
    DateTime? prescriptionDate,
    List<String>? imageUrls,
    String?   notes,
    DateTime? createdAt,
    List<PrescriptionMedicine>? medicines,
    List<String>? allergyConflicts,
  }) =>
      Prescription(
        id:               id               ?? this.id,
        userId:           userId           ?? this.userId,
        doctorName:       doctorName       ?? this.doctorName,
        doctorSpecialty:  doctorSpecialty  ?? this.doctorSpecialty,
        doctorHospital:   doctorHospital   ?? this.doctorHospital,
        doctorPhone:      doctorPhone      ?? this.doctorPhone,
        diagnosis:        diagnosis        ?? this.diagnosis,
        prescriptionDate: prescriptionDate ?? this.prescriptionDate,
        imageUrls:        imageUrls        ?? this.imageUrls,
        notes:            notes            ?? this.notes,
        createdAt:        createdAt        ?? this.createdAt,
        medicines:        medicines        ?? this.medicines,
        allergyConflicts: allergyConflicts ?? this.allergyConflicts,
      );
}
