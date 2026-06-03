// appointment.dart — Pure Dart model. No Flutter imports.

enum AppointmentStatus { scheduled, completed, cancelled, noShow }

extension AppointmentStatusX on AppointmentStatus {
  String get value {
    switch (this) {
      case AppointmentStatus.scheduled:  return 'scheduled';
      case AppointmentStatus.completed:  return 'completed';
      case AppointmentStatus.cancelled:  return 'cancelled';
      case AppointmentStatus.noShow:     return 'no_show';
    }
  }

  static AppointmentStatus fromString(String s) {
    switch (s) {
      case 'completed':  return AppointmentStatus.completed;
      case 'cancelled':  return AppointmentStatus.cancelled;
      case 'no_show':    return AppointmentStatus.noShow;
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
  final List<String>       prescriptionIds;
  final List<String>       testReportIds;
  final DateTime?          proposedDate; // doctor-proposed reschedule (pending patient action)
  final String?            doctorUserId; // the doctor's account id (if registered)
  final int?               ticketNo;     // per-doctor, per-day serial
  final DateTime           createdAt;
  final DateTime           updatedAt;

  // True when a doctor has proposed a new date awaiting patient confirmation.
  bool get hasPendingReschedule => proposedDate != null;

  // Backward-compat getter — first linked prescription id or null.
  String? get prescriptionId =>
      prescriptionIds.isNotEmpty ? prescriptionIds.first : null;

  const Appointment({
    required this.id,
    required this.userId,
    this.doctorId,
    required this.doctorNameSnapshot,
    required this.appointmentDate,
    this.appointmentTime,
    this.visitReason,
    this.status          = AppointmentStatus.scheduled,
    this.notes,
    this.prescriptionIds = const [],
    this.testReportIds   = const [],
    this.proposedDate,
    this.doctorUserId,
    this.ticketNo,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUpcoming  => status == AppointmentStatus.scheduled &&
      appointmentDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  bool get isPast      => status == AppointmentStatus.completed ||
      status == AppointmentStatus.noShow ||
      (status == AppointmentStatus.scheduled &&
          appointmentDate.isBefore(DateTime.now().subtract(const Duration(days: 1))));
  bool get isCancelled => status == AppointmentStatus.cancelled;
  bool get isNoShow    => status == AppointmentStatus.noShow;

  factory Appointment.fromMap(Map<String, dynamic> m) {
    // Read new array column; fall back to old single-id column.
    final rawPresc = (m['prescription_ids'] as List<dynamic>?)?.cast<String>() ?? [];
    final prescIds = rawPresc.isNotEmpty
        ? rawPresc
        : (m['prescription_id'] != null
            ? [m['prescription_id'] as String]
            : <String>[]);

    return Appointment(
      id:                 m['id']                   as String,
      userId:             m['user_id']              as String,
      doctorId:           m['doctor_id']            as String?,
      doctorNameSnapshot: m['doctor_name_snapshot'] as String,
      appointmentDate:    DateTime.parse(m['appointment_date'] as String),
      appointmentTime:    m['appointment_time']     as String?,
      visitReason:        m['visit_reason']         as String?,
      status: AppointmentStatusX.fromString(
          m['status'] as String? ?? 'scheduled'),
      notes:           m['notes']           as String?,
      prescriptionIds: prescIds,
      testReportIds:   (m['test_report_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      proposedDate: m['proposed_date'] != null
          ? DateTime.parse(m['proposed_date'] as String)
          : null,
      doctorUserId: m['doctor_user_id'] as String?,
      ticketNo:     (m['ticket_no'] as num?)?.toInt(),
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id':              userId,
        'doctor_id':            doctorId,
        'doctor_name_snapshot': doctorNameSnapshot,
        'appointment_date':     appointmentDate.toIso8601String().substring(0, 10),
        'appointment_time':     appointmentTime,
        'visit_reason':         visitReason,
        'status':               status.value,
        'notes':                notes,
        'prescription_ids':     prescriptionIds,
        'test_report_ids':      testReportIds,
      };

  Appointment copyWith({
    String?             id,
    String?             userId,
    String?             doctorId,
    bool                clearDoctorId        = false,
    String?             doctorNameSnapshot,
    DateTime?           appointmentDate,
    String?             appointmentTime,
    String?             visitReason,
    AppointmentStatus?  status,
    String?             notes,
    List<String>?       prescriptionIds,
    bool                clearPrescriptionIds = false,
    List<String>?       testReportIds,
    bool                clearTestReportIds   = false,
    DateTime?           proposedDate,
    bool                clearProposedDate    = false,
    String?             doctorUserId,
    int?                ticketNo,
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
        prescriptionIds:    clearPrescriptionIds
            ? []
            : (prescriptionIds ?? this.prescriptionIds),
        testReportIds:      clearTestReportIds
            ? []
            : (testReportIds ?? this.testReportIds),
        proposedDate:       clearProposedDate
            ? null
            : (proposedDate ?? this.proposedDate),
        doctorUserId:       doctorUserId       ?? this.doctorUserId,
        ticketNo:           ticketNo           ?? this.ticketNo,
        createdAt:          createdAt          ?? this.createdAt,
        updatedAt:          updatedAt          ?? this.updatedAt,
      );
}
