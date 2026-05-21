// doctor_detail_screen.dart — Doctor profile + their appointment history.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../appointment/models/appointment.dart';
import '../../appointment/screens/add_edit_appointment_screen.dart';
import '../../appointment/screens/appointment_detail_screen.dart';
import '../../appointment/services/appointment_service.dart';
import '../models/doctor.dart';
import '../services/doctor_service.dart';
import 'add_edit_doctor_screen.dart';

class DoctorDetailScreen extends StatefulWidget {
  final Doctor doctor;
  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  final _doctorSvc = DoctorService();
  final _apptSvc   = AppointmentService();

  late Doctor           _doctor;
  List<Appointment>     _appointments = [];
  bool                  _loading      = true;
  bool                  _changed      = false;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _loading = true);
    try {
      _appointments = await _apptSvc.fetchForDoctor(_doctor.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => AddEditDoctorScreen(existing: _doctor)),
    );
    if (changed == true) {
      final updated = await _doctorSvc.fetchOne(_doctor.id);
      if (mounted && updated != null) {
        setState(() {
          _doctor  = updated;
          _changed = true;
        });
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
          title: Text(s.deleteDoctor,
              style: GoogleFonts.poppins(
                  color: c.textPrimary, fontWeight: FontWeight.w600)),
          content: Text(s.deleteDoctorConfirm,
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
    await _doctorSvc.delete(_doctor.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleFavorite() async {
    await _doctorSvc.toggleFavorite(_doctor);
    final updated = await _doctorSvc.fetchOne(_doctor.id);
    if (mounted && updated != null) {
      setState(() {
        _doctor  = updated;
        _changed = true;
      });
    }
  }

  Future<void> _addAppointment() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditAppointmentScreen(
            preselectedDoctor: _doctor),
      ),
    );
    if (added == true) _loadAppointments();
  }

  Future<void> _openAppt(Appointment a) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => AppointmentDetailScreen(appointment: a)),
    );
    if (changed == true) _loadAppointments();
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Doctor Info ───────────────────────────────────────
                    _InfoCard(doctor: _doctor),

                    const SizedBox(height: 28),

                    // ── Action row ────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _SmallActionBtn(
                            label:   'Edit',
                            icon:    Icons.edit_rounded,
                            color:   c.green,
                            onTap:   _edit,
                            outlined: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SmallActionBtn(
                            label:   'Delete',
                            icon:    Icons.delete_outline_rounded,
                            color:   c.red,
                            onTap:   _delete,
                            outlined: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Appointments section ──────────────────────────────
                    Row(
                      children: [
                        Text(
                          s.appointments,
                          style: GoogleFonts.poppins(
                            fontSize:   16,
                            fontWeight: FontWeight.w700,
                            color:      c.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _addAppointment,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:        c.amber.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border:       Border.all(
                                  color: c.amber.withAlpha(60)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 14, color: c.amber),
                                const SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: c.amber),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_loading)
                      Center(
                        child: CircularProgressIndicator(
                            color: c.amber),
                      )
                    else if (_appointments.isEmpty)
                      Container(
                        width:   double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:        c.card,
                          borderRadius: BorderRadius.circular(16),
                          border:       Border.all(color: c.border),
                        ),
                        child: Text(
                          s.noAppointments,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: c.textSec),
                        ),
                      )
                    else
                      ...List.generate(_appointments.length, (i) {
                        final a = _appointments[i];
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: i < _appointments.length - 1 ? 10 : 0),
                          child: _ApptRow(
                            appt:  a,
                            onTap: () => _openAppt(a),
                          ),
                        );
                      }),
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
                  _doctor.displayName,
                  style: GoogleFonts.poppins(
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                    color:      c.textPrimary,
                  ),
                ),
                if (_doctor.specialty?.isNotEmpty == true)
                  Text(
                    _doctor.specialty!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: c.green),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleFavorite,
            child: Icon(
              _doctor.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _doctor.isFavorite ? c.red : c.textMuted,
              size: 26,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }
}

// ── Doctor info card ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Doctor doctor;
  const _InfoCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = doctor;

    final rows = <(IconData, String, String)>[];
    if (d.hospital?.isNotEmpty == true) {
      rows.add((Icons.apartment_rounded, 'Hospital', d.hospital!));
    }
    if (d.chamberAddress?.isNotEmpty == true) {
      rows.add((Icons.location_on_rounded, 'Chamber', d.chamberAddress!));
    }
    if (d.phone?.isNotEmpty == true) {
      rows.add((Icons.phone_rounded, 'Phone', d.phone!));
    }
    if (d.fee?.isNotEmpty == true) {
      rows.add((Icons.payments_outlined, 'Fee', d.fee!));
    }
    if (d.notes?.isNotEmpty == true) {
      rows.add((Icons.notes_rounded, 'Notes', d.notes!));
    }

    if (rows.isEmpty) {
      return Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:        c.card,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: c.border),
        ),
        child: Text(
          'No additional info saved.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
        ),
      );
    }

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
              Container(width: 4, color: c.green),
              Expanded(
                child: Column(
                  children: rows.asMap().entries.map((e) {
                    final (icon, label, value) = e.value;
                    final isLast = e.key == rows.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color:        c.green.withAlpha(15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon,
                                    size: 16, color: c.green),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(label,
                                        style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: c.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      value,
                                      style: GoogleFonts.poppins(
                                        fontSize:   13,
                                        fontWeight: FontWeight.w600,
                                        color:      c.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: c.border,
                              thickness: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04);
  }
}

// ── Appointment mini-row ──────────────────────────────────────────────────────

class _ApptRow extends StatelessWidget {
  final Appointment  appt;
  final VoidCallback onTap;

  const _ApptRow({required this.appt, required this.onTap});

  Color _color(ThemeColors c) {
    switch (appt.status) {
      case AppointmentStatus.scheduled: return c.amber;
      case AppointmentStatus.completed: return c.green;
      case AppointmentStatus.cancelled: return c.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = appt;

    return Material(
      color:        c.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: c.border, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: _color(c)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fmtDate(a.appointmentDate),
                                  style: GoogleFonts.poppins(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w600,
                                    color:      c.textPrimary,
                                  ),
                                ),
                                if (a.visitReason?.isNotEmpty == true)
                                  Text(
                                    a.visitReason!,
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: c.textSec),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          _StatusDot(status: a.status),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded,
                              color: c.textMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

class _StatusDot extends StatelessWidget {
  final AppointmentStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);
    final label = status == AppointmentStatus.scheduled
        ? s.statusScheduled
        : status == AppointmentStatus.completed
            ? s.statusCompleted
            : s.statusCancelled;
    final color = status == AppointmentStatus.scheduled
        ? c.amber
        : status == AppointmentStatus.completed
            ? c.green
            : c.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SmallActionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final bool         outlined;

  const _SmallActionBtn({
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
        height: 44,
        decoration: BoxDecoration(
          color:        outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16,
                color: outlined ? color : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   13,
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
