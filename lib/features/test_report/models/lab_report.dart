// lab_report.dart — Pure Dart model. No Flutter imports.

class LabReport {
  final String       id;
  final String       userId;
  final String       testName;
  final String?      category;
  final DateTime?    testDate;
  final String?      doctorName;
  final String?      hospital;
  final List<String> imageUrls;
  final String?      notes;
  final String?      prescriptionId;
  final String?      orderedByDoctorId;
  final DateTime     createdAt;
  final DateTime     updatedAt;

  // Display label fetched alongside the report (not stored in DB).
  final String? prescriptionDisplay;

  const LabReport({
    required this.id,
    required this.userId,
    required this.testName,
    this.category,
    this.testDate,
    this.doctorName,
    this.hospital,
    this.imageUrls        = const [],
    this.notes,
    this.prescriptionId,
    this.orderedByDoctorId,
    required this.createdAt,
    required this.updatedAt,
    this.prescriptionDisplay,
  });

  bool get hasImages => imageUrls.isNotEmpty;

  factory LabReport.fromMap(Map<String, dynamic> m,
      {String? prescriptionDisplay}) =>
      LabReport(
        id:                m['id']                     as String,
        userId:            m['user_id']                as String,
        testName:          m['test_name']              as String,
        category:          m['category']               as String?,
        testDate:          m['test_date'] != null
            ? DateTime.parse(m['test_date'] as String)
            : null,
        doctorName:        m['doctor_name']            as String?,
        hospital:          m['hospital']               as String?,
        imageUrls: (m['image_urls'] as List<dynamic>?)?.cast<String>() ?? [],
        notes:             m['notes']                  as String?,
        prescriptionId:    m['prescription_id']        as String?,
        orderedByDoctorId: m['ordered_by_doctor_id']   as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        prescriptionDisplay: prescriptionDisplay,
      );

  Map<String, dynamic> toMap() => {
        'user_id':               userId,
        'test_name':             testName,
        'category':              category,
        'test_date':             testDate?.toIso8601String().substring(0, 10),
        'doctor_name':           doctorName,
        'hospital':              hospital,
        'image_urls':            imageUrls,
        'notes':                 notes,
        'prescription_id':       prescriptionId,
        'ordered_by_doctor_id':  orderedByDoctorId,
      };

  LabReport copyWith({
    String?       id,
    String?       userId,
    String?       testName,
    String?       category,
    DateTime?     testDate,
    bool          clearTestDate = false,
    String?       doctorName,
    String?       hospital,
    List<String>? imageUrls,
    String?       notes,
    String?       prescriptionId,
    bool          clearPrescriptionId = false,
    String?       orderedByDoctorId,
    DateTime?     createdAt,
    DateTime?     updatedAt,
    String?       prescriptionDisplay,
  }) =>
      LabReport(
        id:                  id                  ?? this.id,
        userId:              userId              ?? this.userId,
        testName:            testName            ?? this.testName,
        category:            category            ?? this.category,
        testDate:            clearTestDate       ? null : (testDate ?? this.testDate),
        doctorName:          doctorName          ?? this.doctorName,
        hospital:            hospital            ?? this.hospital,
        imageUrls:           imageUrls           ?? this.imageUrls,
        notes:               notes               ?? this.notes,
        prescriptionId:      clearPrescriptionId ? null : (prescriptionId ?? this.prescriptionId),
        orderedByDoctorId:   orderedByDoctorId   ?? this.orderedByDoctorId,
        createdAt:           createdAt           ?? this.createdAt,
        updatedAt:           updatedAt           ?? this.updatedAt,
        prescriptionDisplay: prescriptionDisplay ?? this.prescriptionDisplay,
      );
}
