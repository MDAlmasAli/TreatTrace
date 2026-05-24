class DoctorPatientLink {
  final String    id;
  final String    doctorId;
  final String    patientId;
  final String    status; // pending | accepted | rejected | revoked
  final DateTime  requestedAt;
  final DateTime? acceptedAt;

  // Joined from profiles (populated separately by the service)
  final String? patientName;
  final String? patientPhone;
  final String? patientAvatarUrl;
  final String? doctorName;
  final String? doctorAvatarUrl;
  final String? doctorHospital;

  const DoctorPatientLink({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.status,
    required this.requestedAt,
    this.acceptedAt,
    this.patientName,
    this.patientPhone,
    this.patientAvatarUrl,
    this.doctorName,
    this.doctorAvatarUrl,
    this.doctorHospital,
  });

  bool get isPending  => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isRevoked  => status == 'revoked';

  factory DoctorPatientLink.fromMap(Map<String, dynamic> m) => DoctorPatientLink(
        id:          m['id']           as String,
        doctorId:    m['doctor_id']    as String,
        patientId:   m['patient_id']   as String,
        status:      m['status']       as String,
        requestedAt: DateTime.parse(m['requested_at'] as String),
        acceptedAt:  m['accepted_at'] != null
            ? DateTime.parse(m['accepted_at'] as String)
            : null,
      );

  DoctorPatientLink copyWith({
    String? patientName,
    String? patientPhone,
    String? patientAvatarUrl,
    String? doctorName,
    String? doctorAvatarUrl,
    String? doctorHospital,
  }) =>
      DoctorPatientLink(
        id:              id,
        doctorId:        doctorId,
        patientId:       patientId,
        status:          status,
        requestedAt:     requestedAt,
        acceptedAt:      acceptedAt,
        patientName:     patientName     ?? this.patientName,
        patientPhone:    patientPhone    ?? this.patientPhone,
        patientAvatarUrl: patientAvatarUrl ?? this.patientAvatarUrl,
        doctorName:      doctorName      ?? this.doctorName,
        doctorAvatarUrl: doctorAvatarUrl ?? this.doctorAvatarUrl,
        doctorHospital:  doctorHospital  ?? this.doctorHospital,
      );
}
