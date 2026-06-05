// patient_appointment_tile.dart — One appointment row inside a doctor's view of
// a patient (used by the patient detail preview and the All Appointments list).
//
// Privacy: full details + tap-through only for the doctor's OWN appointments
// with the patient. Other doctors' appointments are redacted (doctor name, date
// and status only) and tapping shows a short note.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../appointment/models/appointment_model.dart';

class PatientAppointmentTile extends StatelessWidget {
  final Appointment appt;
  final String      currentDoctorId;

  /// Invoked (with the appointment) when the doctor taps one of their OWN
  /// appointments. Other doctors' appointments are never opened.
  final void Function(Appointment)? onTap;

  const PatientAppointmentTile({
    super.key,
    required this.appt,
    required this.currentDoctorId,
    this.onTap,
  });

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final d       = appt.appointmentDate;
    final dateStr = '${d.day} ${_months[d.month - 1]} ${d.year}';

    final statusColor = appt.isUpcoming  ? c.green
        : appt.isCancelled ? c.red
        : c.textSec;
    final statusLabel = appt.isUpcoming  ? 'Scheduled'
        : appt.isCancelled ? 'Cancelled'
        : 'Completed';

    final isMine =
        appt.doctorUserId != null && appt.doctorUserId == currentDoctorId;

    final docTitle = appt.doctorNameSnapshot.isNotEmpty
        ? 'Dr. ${appt.doctorNameSnapshot}'
        : 'Doctor';

    // ── Redacted (another doctor's appointment) ──────────────────────────────
    if (!isMine) {
      return GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior:        SnackBarBehavior.floating,
              backgroundColor: c.card,
              content: Text(
                "Only the attending doctor can view this appointment's details.",
                style: GoogleFonts.poppins(fontSize: 12.5, color: c.textPrimary),
              ),
            ),
          );
        },
        child: Container(
          margin:  const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        c.card,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: c.textMuted.withAlpha(15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.lock_outline_rounded, color: c.textMuted, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(docTitle,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(dateStr,
                        style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
                    const SizedBox(height: 3),
                    Text('Details private to the attending doctor',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: c.textMuted, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
        ),
      );
    }

    // ── Full (the doctor's own appointment) ──────────────────────────────────
    final reason    = appt.visitReason?.trim() ?? '';
    final subtitle  = (reason.isNotEmpty ? '$reason · ' : '') +
        dateStr +
        (appt.appointmentTime != null ? ' · ${appt.appointmentTime}' : '');
    final rxCount   = appt.prescriptionIds.length;
    final testCount = appt.testReportIds.length;
    final hasLink   = rxCount > 0 || testCount > 0;

    return GestureDetector(
      onTap: onTap != null ? () => onTap!(appt) : null,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        c.card,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(
              color: hasLink ? c.purpleBright.withAlpha(60) : c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: c.amber.withAlpha(15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.calendar_month_rounded, color: c.amber, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(docTitle,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: GoogleFonts.poppins(fontSize: 11, color: c.textSec),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (rxCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.link_rounded, size: 10, color: c.purpleBright),
                        const SizedBox(width: 3),
                        Text(
                          rxCount == 1
                              ? '1 Prescription Linked'
                              : '$rxCount Prescriptions Linked',
                          style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w600, color: c.purpleBright),
                        ),
                      ],
                    ),
                  ],
                  if (testCount > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.science_rounded, size: 10, color: c.cyan),
                        const SizedBox(width: 3),
                        Text(
                          testCount == 1
                              ? '1 Test Report Linked'
                              : '$testCount Test Reports Linked',
                          style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w600, color: c.cyan),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _StatusBadge(label: statusLabel, color: statusColor),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withAlpha(15), borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
