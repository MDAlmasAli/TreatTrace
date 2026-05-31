// appointment_detail_screen.dart — View appointment details, change status.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../features/prescription/models/prescription.dart';
import '../../../features/prescription/services/prescription_service.dart';
import '../../../features/prescription/screens/prescription_detail_screen.dart';
import '../../../features/test_report/models/test_report.dart';
import '../../../features/test_report/services/test_report_service.dart';
import '../../../features/test_report/screens/test_report_detail_screen.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';
import 'add_edit_appointment_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;

  /// Doctor-side, read-only view: hides status/edit/delete controls, opens
  /// linked items via the doctor-side callbacks below, and (optionally) shows
  /// an "Open Patient Profile" button.
  final bool isDoctorView;

  /// Shown as the header title in doctor view (the patient who booked).
  final String? patientName;

  /// Doctor view — tapping a linked prescription. Caller decides edit rights
  /// (own prescription = editable, others = view only).
  final void Function(Prescription rx)? onPrescriptionTapDoctor;

  /// Doctor view — tapping a linked test report (always view-only).
  final void Function(TestReport report)? onTestReportTapDoctor;

  /// Doctor view — opens the patient's full profile. Null hides the button.
  final VoidCallback? onOpenPatientProfile;

  /// Doctor view — write a new prescription for this patient straight from the
  /// appointment (no need to open the profile first). Null hides the button.
  final VoidCallback? onWritePrescription;

  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    this.isDoctorView = false,
    this.patientName,
    this.onPrescriptionTapDoctor,
    this.onTestReportTapDoctor,
    this.onOpenPatientProfile,
    this.onWritePrescription,
  });

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final _service    = AppointmentService();
  final _prescSvc   = PrescriptionService();
  final _testRepSvc = TestReportService();

  late Appointment _appt;
  bool _loading = false;
  bool _changed = false;

  final Map<String, Prescription> _prescMap      = {};
  final Map<String, TestReport>   _testReportMap = {};

  @override
  void initState() {
    super.initState();
    _appt = widget.appointment;
    _fetchLinkedData();
  }

  Future<void> _fetchLinkedData() async {
    for (final id in _appt.prescriptionIds) {
      try {
        final p = await _prescSvc.fetchOne(id);
        if (p != null && mounted) setState(() => _prescMap[id] = p);
      } catch (_) {}
    }
    for (final id in _appt.testReportIds) {
      try {
        final t = await _testRepSvc.fetchOne(id);
        if (t != null && mounted) setState(() => _testReportMap[id] = t);
      } catch (_) {}
    }
  }

  String _prescLabel(Prescription p) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final doc = p.doctorName?.isNotEmpty == true ? 'Dr. ${p.doctorName}' : 'Prescription';
    final d   = p.prescriptionDate;
    return '$doc — ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _openPrescription(String id) async {
    final p = _prescMap[id];
    if (p == null || !mounted) return;
    if (widget.isDoctorView) {
      widget.onPrescriptionTapDoctor?.call(p);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PrescriptionDetailScreen(prescription: p),
    ));
  }

  Future<void> _openTestReport(String id) async {
    final t = _testReportMap[id];
    if (t == null || !mounted) return;
    if (widget.isDoctorView) {
      widget.onTestReportTapDoctor?.call(t);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TestReportDetailScreen(report: t),
    ));
  }

  Future<void> _updateStatus(AppointmentStatus status) async {
    final s = S.of(context);
    final label = status == AppointmentStatus.completed
        ? s.markCompleted
        : s.cancelAppointment;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = context.colors;
        return AlertDialog(
          backgroundColor: c.card,
          title: Text(label,
              style: GoogleFonts.poppins(
                  color: c.textPrimary, fontWeight: FontWeight.w600)),
          content: Text(
            status == AppointmentStatus.completed
                ? 'Mark this appointment as completed?'
                : 'Cancel this appointment?',
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(s.cancel,
                  style: GoogleFonts.poppins(color: c.textSec)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                s.confirm,
                style: GoogleFonts.poppins(
                  color: status == AppointmentStatus.completed
                      ? c.green
                      : c.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _service.updateStatus(_appt.id, status);
      final updated = await _service.fetchOne(_appt.id);
      if (mounted && updated != null) {
        setState(() {
          _appt    = updated;
          _changed = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _delete() async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = context.colors;
        return AlertDialog(
          backgroundColor: c.card,
          title: Text(s.deleteAppointment,
              style: GoogleFonts.poppins(
                  color: c.textPrimary, fontWeight: FontWeight.w600)),
          content: Text(s.deleteApptConfirm,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(s.cancel,
                  style: GoogleFonts.poppins(color: c.textSec)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Delete',
                  style: GoogleFonts.poppins(
                      color: c.red, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await _service.delete(_appt.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => AddEditAppointmentScreen(existing: _appt)),
    );
    if (changed == true) {
      final updated = await _service.fetchOne(_appt.id);
      if (mounted && updated != null) {
        setState(() {
          _appt    = updated;
          _changed = true;
          _prescMap.clear();
          _testReportMap.clear();
        });
        _fetchLinkedData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, _) {
        if (_changed) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            _buildHeader(c, s),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: c.amber))
                  : SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusBanner(status: _appt.status),
                          const SizedBox(height: 20),
                          _InfoCard(
                            children: [
                              _InfoRow(
                                icon:  Icons.person_rounded,
                                label: widget.isDoctorView ? 'Patient' : 'Doctor',
                                value: widget.isDoctorView
                                    ? (widget.patientName ?? 'Patient')
                                    : 'Dr. ${_appt.doctorNameSnapshot}',
                              ),
                              _InfoRow(
                                icon:  Icons.calendar_today_rounded,
                                label: s.appointmentDate,
                                value: _fmtDate(_appt.appointmentDate),
                              ),
                              if (_appt.appointmentTime?.isNotEmpty == true)
                                _InfoRow(
                                  icon:  Icons.access_time_rounded,
                                  label: s.appointmentTime,
                                  value: _appt.appointmentTime!,
                                ),
                              if (_appt.visitReason?.isNotEmpty == true)
                                _InfoRow(
                                  icon:  Icons.medical_services_rounded,
                                  label: s.visitReason,
                                  value: _appt.visitReason!,
                                  isLast: _appt.notes?.isEmpty != false &&
                                      _appt.prescriptionIds.isEmpty &&
                                      _appt.testReportIds.isEmpty,
                                ),
                              if (_appt.notes?.isNotEmpty == true)
                                _InfoRow(
                                  icon:  Icons.notes_rounded,
                                  label: s.notes,
                                  value: _appt.notes!,
                                  isLast: _appt.prescriptionIds.isEmpty &&
                                      _appt.testReportIds.isEmpty,
                                ),
                              ..._appt.prescriptionIds.asMap().entries.map((e) {
                                final idx   = e.key;
                                final id    = e.value;
                                final p     = _prescMap[id];
                                final label = p != null ? _prescLabel(p) : 'Linked Prescription';
                                final isLast = idx == _appt.prescriptionIds.length - 1 &&
                                    _appt.testReportIds.isEmpty;
                                return GestureDetector(
                                  onTap: () => _openPrescription(id),
                                  child: _InfoRow(
                                    icon:       Icons.link_rounded,
                                    iconColor:  c.purpleBright,
                                    label:      _appt.prescriptionIds.length > 1
                                        ? '${s.linkedPrescription} ${idx + 1}'
                                        : s.linkedPrescription,
                                    value:      label,
                                    valueColor: c.purpleBright,
                                    isLast:     isLast,
                                    trailing:   Icon(Icons.arrow_forward_ios_rounded,
                                        size: 12, color: c.purpleBright),
                                  ),
                                );
                              }),
                              ..._appt.testReportIds.asMap().entries.map((e) {
                                final idx   = e.key;
                                final id    = e.value;
                                final t     = _testReportMap[id];
                                final label = t != null ? t.testName : 'Linked Test Report';
                                final isLast = idx == _appt.testReportIds.length - 1;
                                return GestureDetector(
                                  onTap: () => _openTestReport(id),
                                  child: _InfoRow(
                                    icon:       Icons.science_rounded,
                                    iconColor:  c.cyan,
                                    label:      _appt.testReportIds.length > 1
                                        ? 'Test Report ${idx + 1}'
                                        : 'Test Report',
                                    value:      label,
                                    valueColor: c.cyan,
                                    isLast:     isLast,
                                    trailing:   Icon(Icons.arrow_forward_ios_rounded,
                                        size: 12, color: c.cyan),
                                  ),
                                );
                              }),
                            ],
                          ),

                          // Doctor view — read-only; only an optional
                          // "Open Patient Profile" action.
                          if (widget.isDoctorView) ...[
                            if (widget.onWritePrescription != null) ...[
                              const SizedBox(height: 28),
                              _ActionBtn(
                                label:    'Write Prescription',
                                icon:     Icons.medication_rounded,
                                color:    c.accent,
                                onTap:    widget.onWritePrescription!,
                              ),
                            ],
                            if (widget.onOpenPatientProfile != null) ...[
                              SizedBox(
                                  height: widget.onWritePrescription != null
                                      ? 12
                                      : 28),
                              _ActionBtn(
                                label:    'Open Patient Profile',
                                icon:     Icons.person_rounded,
                                color:    c.accent,
                                onTap:    widget.onOpenPatientProfile!,
                                outlined: true,
                              ),
                            ],
                          ] else ...[
                            const SizedBox(height: 28),

                            // Action buttons — only when scheduled
                            if (_appt.status ==
                                AppointmentStatus.scheduled) ...[
                              _ActionBtn(
                                label:   s.markCompleted,
                                icon:    Icons.check_circle_outline_rounded,
                                color:   c.green,
                                onTap:   () => _updateStatus(
                                    AppointmentStatus.completed),
                              ),
                              const SizedBox(height: 12),
                              _ActionBtn(
                                label:   s.cancelAppointment,
                                icon:    Icons.cancel_outlined,
                                color:   c.red,
                                onTap:   () => _updateStatus(
                                    AppointmentStatus.cancelled),
                                outlined: true,
                              ),
                              const SizedBox(height: 28),
                            ],

                            // Edit / Delete row
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionBtn(
                                    label:    'Edit',
                                    icon:     Icons.edit_rounded,
                                    color:    c.amber,
                                    onTap:    _edit,
                                    outlined: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionBtn(
                                    label:    'Delete',
                                    icon:     Icons.delete_outline_rounded,
                                    color:    c.red,
                                    onTap:    _delete,
                                    outlined: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c, S s) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(8),
            blurRadius: 20,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
          top: topPad + 16, left: 20, right: 20, bottom: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(_changed ? true : null),
            child: _IconBtn(icon: Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isDoctorView && widget.patientName != null
                      ? widget.patientName!
                      : 'Dr. ${_appt.doctorNameSnapshot}',
                  style: GoogleFonts.poppins(
                    fontSize:   18,
                    fontWeight: FontWeight.w700,
                    color:      c.textPrimary,
                  ),
                ),
                Text(
                  _fmtDate(_appt.appointmentDate),
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: c.amber),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final AppointmentStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final c   = context.colors;
    final s   = S.of(context);
    final col = status == AppointmentStatus.scheduled
        ? c.amber
        : status == AppointmentStatus.completed
            ? c.green
            : c.red;
    final label = status == AppointmentStatus.scheduled
        ? s.statusScheduled
        : status == AppointmentStatus.completed
            ? s.statusCompleted
            : s.statusCancelled;
    final icon = status == AppointmentStatus.scheduled
        ? Icons.schedule_rounded
        : status == AppointmentStatus.completed
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        col.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: col.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: col, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: col),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: c.amber),
              Expanded(
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color?   iconColor;
  final String   label;
  final String   value;
  final Color?   valueColor;
  final bool     isLast;
  final Widget?  trailing;

  const _InfoRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast  = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final iCol = iconColor ?? c.amber;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color:        iCol.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iCol),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: c.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      valueColor ?? c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, endIndent: 16,
              color: c.border, thickness: 1),
      ],
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final bool         outlined;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color:        outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: color, width: 1.5),
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color:      color.withAlpha(50),
                    blurRadius: 12,
                    offset:     const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18,
                color: outlined ? color : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   14,
                fontWeight: FontWeight.w600,
                color:      outlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  const _IconBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color:        c.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: c.border, width: 1),
      ),
      child: Icon(icon, color: c.textSec, size: 20),
    );
  }
}
