import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/profile_service.dart';
import '../../profile/models/health_profile.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import '../../test_report/models/lab_report.dart';
import '../../test_report/services/lab_report_service.dart';
import '../../appointment/models/appointment.dart';
import '../../appointment/services/appointment_service.dart';
import 'doctor_write_prescription_screen.dart';
import 'doctor_add_appointment_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String  patientId;
  final String  patientName;
  final String? patientPhone;
  final String? patientAvatarUrl;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.patientAvatarUrl,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _profileSvc = ProfileService();
  final _rxSvc      = PrescriptionService();
  final _labSvc     = LabReportService();
  final _apptSvc    = AppointmentService();

  HealthProfile?     _profile;
  List<Prescription> _rxList = [];
  List<LabReport>    _labs   = [];
  List<Appointment>  _appts  = [];
  bool               _loading = true;

  final String _currentDoctorId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _profileSvc.fetchForPatient(widget.patientId),
        _rxSvc.fetchForPatient(widget.patientId),
        _labSvc.fetchForPatient(widget.patientId),
        _apptSvc.fetchForPatient(widget.patientId),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as HealthProfile?;
          _rxList  = List<Prescription>.from(results[1] as List);
          _labs    = List<LabReport>.from(results[2] as List);
          _appts   = List<Appointment>.from(results[3] as List);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goWriteRx() async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorWritePrescriptionScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
      ),
    ));
    if (result == true) _load();
  }

  Future<void> _goEditRx(Prescription rx) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorWritePrescriptionScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
        existing:    rx,
      ),
    ));
    if (result == true) _load();
  }

  Future<void> _goAddAppt() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DoctorAddAppointmentScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
      ),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  c.statusBarIconBrightness,
    ));

    return Scaffold(
      backgroundColor: c.bg,
      bottomNavigationBar: _BottomBar(onWriteRx: _goWriteRx, onAddAppt: _goAddAppt),
      body: Column(
        children: [
          _buildHeader(c),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5))
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        _PatientCard(
                          name:      widget.patientName,
                          phone:     widget.patientPhone,
                          avatarUrl: widget.patientAvatarUrl,
                        ).animate().fadeIn(delay: 50.ms),
                        const SizedBox(height: 20),
                        _HealthProfileSection(profile: _profile)
                            .animate().fadeIn(delay: 100.ms),
                        const SizedBox(height: 20),
                        _PrescriptionsSection(
                          list:            _rxList,
                          currentDoctorId: _currentDoctorId,
                          onEdit:          _goEditRx,
                        ).animate().fadeIn(delay: 150.ms),
                        const SizedBox(height: 20),
                        _LabReportsSection(list: _labs)
                            .animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 20),
                        _AppointmentsSection(list: _appts)
                            .animate().fadeIn(delay: 250.ms),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeColors c) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      padding: EdgeInsets.only(top: topPad + 16, left: 20, right: 20, bottom: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        c.surface,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back_rounded, color: c.textSec, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient Details',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text(widget.patientName,
                    style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Patient summary card ─────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final String  name;
  final String? phone;
  final String? avatarUrl;
  const _PatientCard({required this.name, required this.phone, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.accent.withAlpha(60)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: c.accent.withAlpha(20),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Icon(Icons.person_rounded, color: c.accent, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
                if (phone != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded, size: 13, color: c.textSec),
                      const SizedBox(width: 4),
                      Text(phone!, style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.green.withAlpha(20), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, size: 12, color: c.green),
                const SizedBox(width: 4),
                Text('Linked', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: c.green)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final int      count;
  final Color    color;
  const _SectionHeader({required this.icon, required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      child: Text(message, style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted)),
    );
  }
}

// ── Health Profile section ────────────────────────────────────────────────────

class _HealthProfileSection extends StatelessWidget {
  final HealthProfile? profile;
  const _HealthProfileSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon:  Icons.favorite_rounded,
          title: 'Health Profile',
          count: 1,
          color: c.red,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        c.card,
            borderRadius: BorderRadius.circular(18),
            border:       Border.all(color: c.border),
          ),
          child: p == null
              ? _EmptySection(message: 'No health profile found.')
              : Column(
                  children: [
                    Row(
                      children: [
                        _VitalChip(label: 'Blood', value: p.bloodGroup ?? '—', color: c.red),
                        const SizedBox(width: 8),
                        _VitalChip(label: 'Age',    value: p.ageDisplay,    color: c.accent),
                        const SizedBox(width: 8),
                        _VitalChip(label: 'Height', value: p.heightDisplay, color: c.green),
                        const SizedBox(width: 8),
                        _VitalChip(label: 'Weight', value: p.weightDisplay, color: c.amber),
                      ],
                    ),
                    if (p.allergies != null && p.allergies!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ProfileRow(icon: Icons.warning_amber_rounded, label: 'Allergies', value: p.allergies!, color: c.amber),
                    ],
                    if (p.ongoingTreatment != null && p.ongoingTreatment!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ProfileRow(icon: Icons.medical_services_rounded, label: 'Treatment', value: p.ongoingTreatment!, color: c.accent),
                    ],
                    if (p.emergencyName != null && p.emergencyName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ProfileRow(icon: Icons.emergency_rounded, label: 'Emergency', value: '${p.emergencyName} · ${p.emergencyPhone ?? "—"}', color: c.red),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _VitalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _VitalChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:        color.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.poppins(fontSize: 9,  fontWeight: FontWeight.w500, color: c.textSec)),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _ProfileRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text('$label: ', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSec)),
        Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: c.textPrimary))),
      ],
    );
  }
}

// ── Prescriptions section ─────────────────────────────────────────────────────

class _PrescriptionsSection extends StatelessWidget {
  final List<Prescription>          list;
  final String                      currentDoctorId;
  final Future<void> Function(Prescription) onEdit;

  const _PrescriptionsSection({
    required this.list,
    required this.currentDoctorId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon:  Icons.medication_rounded,
          title: 'Prescriptions',
          count: list.length,
          color: c.accent,
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          _EmptySection(message: 'No prescriptions found.')
        else
          ...list.take(5).map((rx) => _RxTile(
            rx:             rx,
            canEdit:        rx.writtenByDoctorId == currentDoctorId,
            onEdit:         () => onEdit(rx),
          )),
      ],
    );
  }
}

class _RxTile extends StatelessWidget {
  final Prescription rx;
  final bool         canEdit;
  final VoidCallback onEdit;

  const _RxTile({
    required this.rx,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final date    = rx.prescriptionDate;
    final months  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${date.day} ${months[date.month-1]} ${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            decoration: BoxDecoration(color: c.accent.withAlpha(15), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.medication_rounded, color: c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rx.diagnosis ?? (rx.medicines.isNotEmpty ? rx.medicines.first.medicineName : 'Prescription'),
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        (rx.medicines.isEmpty || rx.isActive ? c.green : c.textMuted).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${rx.medicines.length} med${rx.medicines.length == 1 ? '' : 's'}',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600,
                  color: rx.medicines.isEmpty || rx.isActive ? c.green : c.textMuted),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color:        c.accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.edit_rounded, size: 15, color: c.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Lab Reports section ───────────────────────────────────────────────────────

class _LabReportsSection extends StatelessWidget {
  final List<LabReport> list;
  const _LabReportsSection({required this.list});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon:  Icons.science_rounded,
          title: 'Lab Reports',
          count: list.length,
          color: c.green,
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          _EmptySection(message: 'No lab reports found.')
        else
          ...list.take(5).map((lab) => _LabTile(lab: lab)),
      ],
    );
  }
}

class _LabTile extends StatelessWidget {
  final LabReport lab;
  const _LabTile({required this.lab});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d      = lab.testDate;
    final dateStr = d != null ? '${d.day} ${months[d.month-1]} ${d.year}' : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            decoration: BoxDecoration(color: c.green.withAlpha(15), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.science_rounded, color: c.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lab.testName,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
              ],
            ),
          ),
          if (lab.category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.green.withAlpha(15), borderRadius: BorderRadius.circular(8)),
              child: Text(lab.category!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: c.green),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

// ── Appointments section ──────────────────────────────────────────────────────

class _AppointmentsSection extends StatelessWidget {
  final List<Appointment> list;
  const _AppointmentsSection({required this.list});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon:  Icons.calendar_month_rounded,
          title: 'Appointments',
          count: list.length,
          color: c.amber,
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          _EmptySection(message: 'No appointments found.')
        else
          ...list.take(5).map((appt) => _ApptTile(appt: appt)),
      ],
    );
  }
}

class _ApptTile extends StatelessWidget {
  final Appointment appt;
  const _ApptTile({required this.appt});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d      = appt.appointmentDate;
    final dateStr = '${d.day} ${months[d.month-1]} ${d.year}';

    final statusColor = appt.isUpcoming  ? c.green
        : appt.isCancelled ? c.red
        : c.textSec;
    final statusLabel = appt.isUpcoming  ? 'Scheduled'
        : appt.isCancelled ? 'Cancelled'
        : 'Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            decoration: BoxDecoration(color: c.amber.withAlpha(15), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.calendar_month_rounded, color: c.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appt.visitReason ?? appt.doctorNameSnapshot,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  dateStr + (appt.appointmentTime != null ? ' · ${appt.appointmentTime}' : ''),
                  style: GoogleFonts.poppins(fontSize: 11, color: c.textSec),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withAlpha(15), borderRadius: BorderRadius.circular(8)),
            child: Text(statusLabel, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onWriteRx;
  final VoidCallback onAddAppt;
  const _BottomBar({required this.onWriteRx, required this.onAddAppt});

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final botPad  = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + botPad),
      decoration: BoxDecoration(
        color:  c.card,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAddAppt,
              icon:  const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text('Add Appointment', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.accent,
                side:            BorderSide(color: c.accent.withAlpha(120)),
                shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding:         const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onWriteRx,
              icon:  const Icon(Icons.medication_rounded, size: 18),
              label: Text('Write Prescription', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding:         const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
