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
import '../../test_report/models/test_report.dart';
import '../../test_report/services/test_report_service.dart';
import '../../appointment/models/appointment.dart';
import '../../appointment/services/appointment_service.dart';
import '../../test_report/screens/test_report_detail_screen.dart';
import 'all_test_reports_screen.dart';
import 'all_prescriptions_screen.dart';
import 'all_appointments_screen.dart';
import 'doctor_prescription_view_screen.dart';
import 'doctor_write_prescription_screen.dart';
import '../../appointment/screens/appointment_detail_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String  patientId;
  final String  patientName;
  final String? patientPhone;
  final String? patientAvatarUrl;
  final String? appointmentId; // if set, marks appointment completed on first Rx

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.patientAvatarUrl,
    this.appointmentId,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _profileSvc = ProfileService();
  final _rxSvc      = PrescriptionService();
  final _testReportSvc     = TestReportService();
  final _apptSvc    = AppointmentService();

  HealthProfile?     _profile;
  List<Prescription> _rxList = [];
  List<TestReport>    _testReports   = [];
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
        _testReportSvc.fetchForPatient(widget.patientId),
        _apptSvc.fetchForPatient(widget.patientId),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as HealthProfile?;
          _rxList  = List<Prescription>.from(results[1] as List);
          _testReports    = List<TestReport>.from(results[2] as List);
          _appts   = List<Appointment>.from(results[3] as List)
            ..sort((a, b) {
              final aUp = a.isUpcoming ? 0 : 1;
              final bUp = b.isUpcoming ? 0 : 1;
              if (aUp != bUp) return aUp.compareTo(bUp);
              return aUp == 0
                  ? a.appointmentDate.compareTo(b.appointmentDate)
                  : b.appointmentDate.compareTo(a.appointmentDate);
            });
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goViewRx(Prescription rx) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorPrescriptionViewScreen(
        rx:          rx,
        canEdit:     rx.writtenByDoctorId == _currentDoctorId,
        patientId:   widget.patientId,
        patientName: widget.patientName,
      ),
    ));
    if (result == true) _load();
  }

  Future<void> _goShowMoreRx() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AllPrescriptionsScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
      ),
    ));
    _load();
  }

  Future<void> _goWriteRx() async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorWritePrescriptionScreen(
        patientId:     widget.patientId,
        patientName:   widget.patientName,
        appointmentId: widget.appointmentId,
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

  Future<void> _goShowMoreTest() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AllTestReportsScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
      ),
    ));
    _load();
  }

  Future<void> _goShowMoreAppts() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AllAppointmentsScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
      ),
    ));
    _load();
  }

  Future<void> _goViewTest(TestReport lab) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TestReportDetailScreen(
        report:            lab,
        canEdit:           false,
        canDelete:         false,
        onPrescriptionTap: (id) => _openLinkedRx(id),
      ),
    ));
    _load();
  }

  Future<void> _openLinkedRx(String prescriptionId) async {
    final p = await _rxSvc.fetchOne(prescriptionId);
    if (p == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DoctorPrescriptionViewScreen(
        rx:          p,
        canEdit:     p.writtenByDoctorId == _currentDoctorId,
        patientId:   widget.patientId,
        patientName: widget.patientName,
      ),
    ));
  }

  Future<void> _openAppointmentDetail(Appointment appt) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(
          appointment:  appt,
          isDoctorView: true,
          patientName:  widget.patientName,
          // Own prescription = editable; others = view only.
          onPrescriptionTapDoctor: (p) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DoctorPrescriptionViewScreen(
                rx:          p,
                canEdit:     p.writtenByDoctorId == _currentDoctorId,
                patientId:   widget.patientId,
                patientName: widget.patientName,
              ),
            ),
          ),
          // Test reports are always view-only for doctors.
          onTestReportTapDoctor: (t) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TestReportDetailScreen(
                report:            t,
                canEdit:           false,
                canDelete:         false,
                onPrescriptionTap: _openLinkedRx,
              ),
            ),
          ),
          // Write a prescription without leaving the appointment.
          onWritePrescription: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => DoctorWritePrescriptionScreen(
                  patientId:     widget.patientId,
                  patientName:   widget.patientName,
                  appointmentId: appt.status == AppointmentStatus.scheduled
                      ? appt.id
                      : null,
                ),
              ),
            );
            if (result == true && mounted) {
              Navigator.of(context).pop(); // close appointment detail
              _load();
            }
          },
          // Already inside the patient profile — no need for the button here.
        ),
      ),
    );
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
      bottomNavigationBar: _BottomBar(onWriteRx: _goWriteRx),
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
                          onView:          _goViewRx,
                          onEdit:          _goEditRx,
                          onShowMore:      _goShowMoreRx,
                        ).animate().fadeIn(delay: 150.ms),
                        const SizedBox(height: 20),
                        _TestReportsSection(
                          list:       _testReports,
                          onView:     _goViewTest,
                          onShowMore: _goShowMoreTest,
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 20),
                        _AppointmentsSection(
                          list:             _appts,
                          onShowMore:       _goShowMoreAppts,
                          onAppointmentTap: _openAppointmentDetail,
                        ).animate().fadeIn(delay: 250.ms),
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
  final List<Prescription>               list;
  final String                           currentDoctorId;
  final Future<void> Function(Prescription) onView;
  final Future<void> Function(Prescription) onEdit;
  final VoidCallback                     onShowMore;

  static const _previewCount = 5;

  const _PrescriptionsSection({
    required this.list,
    required this.currentDoctorId,
    required this.onView,
    required this.onEdit,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final visible = list.take(_previewCount).toList();
    final hasMore = list.length > _previewCount;

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
        else ...[
          ...visible.map((rx) => _RxTile(
            rx:      rx,
            canEdit: rx.writtenByDoctorId == currentDoctorId,
            onView:  () => onView(rx),
            onEdit:  () => onEdit(rx),
          )),
          if (hasMore)
            GestureDetector(
              onTap: onShowMore,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:        c.accent.withAlpha(10),
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: c.accent.withAlpha(40)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Show ${list.length - _previewCount} more',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 15, color: c.accent),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _RxTile extends StatelessWidget {
  final Prescription rx;
  final bool         canEdit;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const _RxTile({
    required this.rx,
    required this.canEdit,
    required this.onView,
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
            decoration: BoxDecoration(
              color:        c.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.medication_rounded, color: c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rx.diagnosis ?? (rx.medicines.isNotEmpty
                      ? rx.medicines.first.medicineName : 'Prescription'),
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(dateStr,
                    style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // View button — always visible
          GestureDetector(
            onTap: onView,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        c.accent.withAlpha(12),
                borderRadius: BorderRadius.circular(9),
                border:       Border.all(color: c.accent.withAlpha(40)),
              ),
              child: Icon(Icons.visibility_rounded, size: 15, color: c.accent),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color:        c.green.withAlpha(12),
                  borderRadius: BorderRadius.circular(9),
                  border:       Border.all(color: c.green.withAlpha(40)),
                ),
                child: Icon(Icons.edit_rounded, size: 15, color: c.green),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Test Reports section ───────────────────────────────────────────────────────

class _TestReportsSection extends StatelessWidget {
  final List<TestReport>                  list;
  final Future<void> Function(TestReport) onView;
  final VoidCallback                     onShowMore;

  static const _previewCount = 5;

  const _TestReportsSection({
    required this.list,
    required this.onView,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final visible = list.take(_previewCount).toList();
    final hasMore = list.length > _previewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon:  Icons.science_rounded,
          title: 'Test Reports',
          count: list.length,
          color: c.green,
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          _EmptySection(message: 'No test reports found.')
        else ...[
          ...visible.map((lab) => _TestReportTile(
                lab:   lab,
                onTap: () => onView(lab),
              )),
          if (hasMore)
            GestureDetector(
              onTap: onShowMore,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:        c.green.withAlpha(10),
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: c.green.withAlpha(40)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Show ${list.length - _previewCount} more',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: c.green)),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 15, color: c.green),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _TestReportTile extends StatelessWidget {
  final TestReport    lab;
  final VoidCallback onTap;

  const _TestReportTile({
    required this.lab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final months  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d       = lab.testDate;
    final dateStr = d != null ? '${d.day} ${months[d.month - 1]} ${d.year}' : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            decoration: BoxDecoration(
                color: c.green.withAlpha(15), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.science_rounded, color: c.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lab.testName,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
              ],
            ),
          ),
          if (lab.category != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: c.green.withAlpha(15), borderRadius: BorderRadius.circular(8)),
              child: Text(lab.category!,
                  style: GoogleFonts.poppins(
                      fontSize: 10, fontWeight: FontWeight.w600, color: c.green),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    ),
    );
  }
}

// ── Appointments section ──────────────────────────────────────────────────────

class _AppointmentsSection extends StatelessWidget {
  final List<Appointment>            list;
  final VoidCallback                 onShowMore;
  final void Function(Appointment)?  onAppointmentTap;

  static const _previewCount = 3;

  const _AppointmentsSection({
    required this.list,
    required this.onShowMore,
    this.onAppointmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final visible = list.take(_previewCount).toList();
    final hasMore = list.length > _previewCount;

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
        else ...[
          ...visible.map((appt) => _ApptTile(appt: appt, onAppointmentTap: onAppointmentTap)),
          if (hasMore)
            GestureDetector(
              onTap: onShowMore,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:        c.amber.withAlpha(10),
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: c.amber.withAlpha(40)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Show ${list.length - _previewCount} more',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: c.amber)),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 15, color: c.amber),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ApptTile extends StatefulWidget {
  final Appointment                 appt;
  final void Function(Appointment)? onAppointmentTap;
  const _ApptTile({required this.appt, this.onAppointmentTap});

  @override
  State<_ApptTile> createState() => _ApptTileState();
}

class _ApptTileState extends State<_ApptTile> {
  final _prescSvc = PrescriptionService();
  final Map<String, Prescription> _linkedPrescMap = {};

  @override
  void initState() {
    super.initState();
    if (widget.appt.prescriptionIds.isNotEmpty) _fetchLinkedRx();
  }

  Future<void> _fetchLinkedRx() async {
    for (final id in widget.appt.prescriptionIds) {
      try {
        final p = await _prescSvc.fetchOne(id);
        if (p != null && mounted) setState(() => _linkedPrescMap[id] = p);
      } catch (_) {}
    }
  }

  String _rxLabel(Prescription p) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final doc = p.doctorName?.isNotEmpty == true ? 'Dr. ${p.doctorName}' : 'Prescription';
    final d = p.prescriptionDate;
    return '$doc — ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _prescBadgeLabel() {
    final ids = widget.appt.prescriptionIds;
    if (ids.isEmpty) return '';
    if (ids.length == 1) {
      final p = _linkedPrescMap[ids.first];
      return p != null ? _rxLabel(p) : 'Linked Prescription';
    }
    final first = _linkedPrescMap[ids.first];
    final firstLabel = first != null ? _rxLabel(first) : 'Linked Prescription';
    return '$firstLabel  +${ids.length - 1} more';
  }

  @override
  Widget build(BuildContext context) {
    final appt   = widget.appt;
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

    final hasRx        = appt.prescriptionIds.isNotEmpty;
    final hasTestRep   = appt.testReportIds.isNotEmpty;
    final hasAnyLink   = hasRx || hasTestRep;

    return GestureDetector(
      onTap: widget.onAppointmentTap != null
          ? () => widget.onAppointmentTap!(appt)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        c.card,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: hasAnyLink ? c.purpleBright.withAlpha(60) : c.border),
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
                  if (hasRx) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.link_rounded, size: 10, color: c.purpleBright),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(_prescBadgeLabel(),
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: c.purpleBright),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                  if (hasTestRep) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.science_rounded, size: 10, color: c.cyan),
                        const SizedBox(width: 3),
                        Text(
                          appt.testReportIds.length == 1
                              ? '1 Test Report Linked'
                              : '${appt.testReportIds.length} Test Reports Linked',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: c.cyan),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withAlpha(15), borderRadius: BorderRadius.circular(8)),
              child: Text(statusLabel, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onWriteRx;
  const _BottomBar({required this.onWriteRx});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final botPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + botPad),
      decoration: BoxDecoration(
        color:  c.card,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
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
    );
  }
}
