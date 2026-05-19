// appointment.dart — Pure Dart model. No Flutter imports.

enum AppointmentStatus { scheduled, completed, cancelled }

extension AppointmentStatusX on AppointmentStatus {
  String get value {
    switch (this) {
      case AppointmentStatus.scheduled:  return 'scheduled';
      case AppointmentStatus.completed:  return 'completed';
      case AppointmentStatus.cancelled:  return 'cancelled';
    }
  }

  static AppointmentStatus fromString(String s) {
    switch (s) {
      case 'completed':  return AppointmentStatus.completed;
      case 'cancelled':  return AppointmentStatus.cancelled;
      default:           return AppointmentStatus.scheduled;
    }
  }
}

class Appointment {
  final String             id;
  final String             userId;
  final String?            doctorId;
  final String             doctorNameSnapshot;
  final DateTime           appointmentDate;
  final String?            appointmentTime;
  final String?            visitReason;
  final AppointmentStatus  status;
  final String?            notes;
  final String?            prescriptionId;
  final DateTime           createdAt;
  final DateTime           updatedAt;

  const Appointment({
    required this.id,
    required this.userId,
    this.doctorId,
    required this.doctorNameSnapshot,
    required this.appointmentDate,
    this.appointmentTime,
    this.visitReason,
    this.status       = AppointmentStatus.scheduled,
    this.notes,
    this.prescriptionId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUpcoming   => status == AppointmentStatus.scheduled &&
      appointmentDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  bool get isPast       => status == AppointmentStatus.completed ||
      (status == AppointmentStatus.scheduled &&
          appointmentDate.isBefore(DateTime.now().subtract(const Duration(days: 1))));
  bool get isCancelled  => status == AppointmentStatus.cancelled;

  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
        id:                  m['id']                   as String,
        userId:              m['user_id']               as String,
        doctorId:            m['doctor_id']             as String?,
        doctorNameSnapshot:  m['doctor_name_snapshot']  as String,
        appointmentDate: DateTime.parse(m['appointment_date'] as String),
        appointmentTime:     m['appointment_time']      as String?,
        visitReason:         m['visit_reason']          as String?,
        status: AppointmentStatusX.fromString(
            m['status'] as String? ?? 'scheduled'),
        notes:           m['notes']           as String?,
        prescriptionId:  m['prescription_id'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'user_id':              userId,
        'doctor_id':            doctorId,
        'doctor_name_snapshot': doctorNameSnapshot,
        'appointment_date':     appointmentDate.toIso8601String().substring(0, 10),
        'appointment_time':     appointmentTime,
        'visit_reason':         visitReason,
        'status':               status.value,
        'notes':                notes,
        'prescription_id':      prescriptionId,
      };

  Appointment copyWith({
    String?             id,
    String?             userId,
    String?             doctorId,
    bool                clearDoctorId = false,
    String?             doctorNameSnapshot,
    DateTime?           appointmentDate,
    String?             appointmentTime,
    String?             visitReason,
    AppointmentStatus?  status,
    String?             notes,
    String?             prescriptionId,
    bool                clearPrescriptionId = false,
    DateTime?           createdAt,
    DateTime?           updatedAt,
  }) =>
      Appointment(
        id:                 id                 ?? this.id,
        userId:             userId             ?? this.userId,
        doctorId:           clearDoctorId      ? null : (doctorId ?? this.doctorId),
        doctorNameSnapshot: doctorNameSnapshot ?? this.doctorNameSnapshot,
        appointmentDate:    appointmentDate    ?? this.appointmentDate,
        appointmentTime:    appointmentTime    ?? this.appointmentTime,
        visitReason:        visitReason        ?? this.visitReason,
        status:             status             ?? this.status,
        notes:              notes              ?? this.notes,
        prescriptionId:     clearPrescriptionId ? null
            : (prescriptionId ?? this.prescriptionId),
        createdAt:          createdAt          ?? this.createdAt,
        updatedAt:          updatedAt          ?? this.updatedAt,
      );
}
