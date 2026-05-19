// appointment_detail_screen.dart — View appointment details, change status.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';
import 'add_edit_appointment_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final _service = AppointmentService();
  late Appointment _appt;
  bool _loading = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _appt = widget.appointment;
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
                      ? DarkColors.green
                      : DarkColors.red,
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
                      color: DarkColors.red, fontWeight: FontWeight.w700)),
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
        });
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
                          color: DarkColors.amber))
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
                                label: 'Doctor',
                                value: 'Dr. ${_appt.doctorNameSnapshot}',
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
                                      _appt.prescriptionId == null,
                                ),
                              if (_appt.notes?.isNotEmpty == true)
                                _InfoRow(
                                  icon:  Icons.notes_rounded,
                                  label: s.notes,
                                  value: _appt.notes!,
                                  isLast: _appt.prescriptionId == null,
                                ),
                              if (_appt.prescriptionId != null)
                                _InfoRow(
                                  icon:  Icons.link_rounded,
                                  label: s.linkedPrescription,
                                  value: 'Linked',
                                  valueColor: DarkColors.purpleBright,
                                  isLast: true,
                                ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Action buttons — only when scheduled
                          if (_appt.status == AppointmentStatus.scheduled) ...[
                            _ActionBtn(
                              label:   s.markCompleted,
                              icon:    Icons.check_circle_outline_rounded,
                              color:   DarkColors.green,
                              onTap:   () => _updateStatus(
                                  AppointmentStatus.completed),
                            ),
                            const SizedBox(height: 12),
                            _ActionBtn(
                              label:   s.cancelAppointment,
                              icon:    Icons.cancel_outlined,
                              color:   DarkColors.red,
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
                                  color:    DarkColors.amber,
                                  onTap:    _edit,
                                  outlined: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionBtn(
                                  label:    'Delete',
                                  icon:     Icons.delete_outline_rounded,
                                  color:    DarkColors.red,
                                  onTap:    _delete,
                                  outlined: true,
                                ),
                              ),
                            ],
                          ),
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
            color:      DarkColors.amber.withAlpha(18),
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
                  'Dr. ${_appt.doctorNameSnapshot}',
                  style: GoogleFonts.poppins(
                    fontSize:   18,
                    fontWeight: FontWeight.w700,
                    color:      c.textPrimary,
                  ),
                ),
                Text(
                  _fmtDate(_appt.appointmentDate),
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: DarkColors.amber),
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
    final s   = S.of(context);
    final col = status == AppointmentStatus.scheduled
        ? DarkColors.amber
        : status == AppointmentStatus.completed
            ? DarkColors.green
            : DarkColors.red;
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
              Container(width: 4, color: DarkColors.amber),
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
  final String   label;
  final String   value;
  final Color?   valueColor;
  final bool     isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                  color:        DarkColors.amber.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: DarkColors.amber),
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
