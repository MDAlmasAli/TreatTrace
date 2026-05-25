// global_search_screen.dart — Cross-feature search: doctors, prescriptions, lab reports.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../appointment/screens/add_edit_appointment_screen.dart';
import '../../doctor/models/doctor.dart';
import '../../doctor/services/doctor_service.dart';
import '../../doctor_home/models/doctor_patient_link.dart';
import '../../doctor_home/services/doctor_patient_link_service.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import '../../prescription/screens/prescription_detail_screen.dart';
import '../../test_report/models/lab_report.dart';
import '../../test_report/services/lab_report_service.dart';
import '../../test_report/screens/lab_report_detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  final _linkSvc = DoctorPatientLinkService();
  final _prescriptionSvc = PrescriptionService();
  final _labReportSvc = LabReportService();

  bool _loading = true;
  String _query = '';

  List<Map<String, dynamic>> _allDoctors = [];
  Set<String> _linkedIds = {};
  List<Prescription> _prescriptions = [];
  List<LabReport> _labReports = [];

  @override
  void initState() {
    super.initState();
    _load();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _linkSvc.fetchApprovedDoctors(),
        _linkSvc.fetchIncomingRequests(),
        _prescriptionSvc.fetchAll(),
        _labReportSvc.fetchAll(),
      ]);
      _allDoctors = results[0] as List<Map<String, dynamic>>;
      _linkedIds = (results[1] as List<DoctorPatientLink>)
          .where((l) => l.isAccepted)
          .map((l) => l.doctorId)
          .toSet();
      _prescriptions = results[2] as List<Prescription>;
      _labReports = results[3] as List<LabReport>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Filtered results ──────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredDoctors {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _allDoctors
        .where(
          (d) =>
              ((d['full_name'] as String?)?.toLowerCase().contains(q) ??
                  false) ||
              ((d['specialty'] as String?)?.toLowerCase().contains(q) ??
                  false) ||
              ((d['hospital'] as String?)?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  List<Prescription> get _filteredPrescriptions {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _prescriptions.where((p) {
      if (p.doctorName?.toLowerCase().contains(q) ?? false) return true;
      if (p.diagnosis?.toLowerCase().contains(q) ?? false) return true;
      return p.medicines.any((m) => m.medicineName.toLowerCase().contains(q));
    }).toList();
  }

  List<LabReport> get _filteredLabReports {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _labReports
        .where(
          (r) =>
              r.testName.toLowerCase().contains(q) ||
              (r.category?.toLowerCase().contains(q) ?? false) ||
              (r.doctorName?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  bool get _hasAnyResults =>
      _filteredDoctors.isNotEmpty ||
      _filteredPrescriptions.isNotEmpty ||
      _filteredLabReports.isNotEmpty;

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _showDoctorSheet(Map<String, dynamic> d, bool isLinked) async {
    final takeAppointment = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DoctorProfileSheet(doctorData: d, isLinked: isLinked),
    );
    if (takeAppointment == true && mounted) {
      final name = (d['full_name'] as String?)?.trim();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddEditAppointmentScreen(
            prefilledDoctorName: name?.isEmpty == true ? null : name,
            prefilledDoctorHospital: d['hospital'] as String?,
            prefilledDoctorUserId: d['id'] as String?,
          ),
        ),
      );
    }
  }

  void _openPrescription(Prescription p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrescriptionDetailScreen(prescription: p),
      ),
    );
  }

  void _openLabReport(LabReport r) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LabReportDetailScreen(report: r)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.statusBarIconBrightness,
      ),
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildSearchBar(c),
          Expanded(child: _buildBody(c)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeColors c) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: c.card,
      padding: EdgeInsets.only(
        top: topPad + 12,
        left: 16,
        right: 16,
        bottom: 14,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back_rounded, color: c.textSec, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search doctors, medicines, reports…',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: c.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: c.accent,
                    size: 20,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: c.textMuted,
                            size: 18,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeColors c) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }
    if (_query.isEmpty) return _buildEmptyPrompt(c);
    if (!_hasAnyResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.accent.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.search_off_rounded, color: c.accent, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$_query"',
              style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (_filteredDoctors.isNotEmpty) ...[
          _SectionHeader(title: 'Doctors', icon: Icons.person_rounded, c: c),
          const SizedBox(height: 8),
          ..._filteredDoctors.take(4).map((d) {
            final isLinked = _linkedIds.contains(d['id'] as String?);
            return _DoctorResultTile(
              name: 'Dr. ${d['full_name'] ?? "Unknown"}',
              specialty: d['specialty'] as String?,
              hospital: d['hospital'] as String?,
              visitingFee: d['visiting_fee'] as int?,
              imageUrl: d['avatar_url'] as String?,
              badge: isLinked ? 'My Doctor' : 'Doctor',
              badgeColor: isLinked ? c.green : c.accent,
              onTap: () => _showDoctorSheet(d, isLinked),
              c: c,
            );
          }),
          const SizedBox(height: 20),
        ],
        if (_filteredPrescriptions.isNotEmpty) ...[
          _SectionHeader(
            title: 'Prescriptions',
            icon: Icons.receipt_long_rounded,
            c: c,
          ),
          const SizedBox(height: 8),
          ..._filteredPrescriptions
              .take(4)
              .map(
                (p) => _ResultTile(
                  icon: Icons.receipt_long_rounded,
                  iconColor: c.accent,
                  title: p.diagnosis ?? p.doctorName ?? 'Prescription',
                  subtitle: [
                    if (p.doctorName != null) 'Dr. ${p.doctorName}',
                    _fmt(p.prescriptionDate),
                  ].join('  ·  '),
                  onTap: () => _openPrescription(p),
                  c: c,
                ),
              ),
          const SizedBox(height: 20),
        ],
        if (_filteredLabReports.isNotEmpty) ...[
          _SectionHeader(
            title: 'Lab Reports',
            icon: Icons.science_rounded,
            c: c,
          ),
          const SizedBox(height: 8),
          ..._filteredLabReports
              .take(4)
              .map(
                (r) => _ResultTile(
                  icon: Icons.science_rounded,
                  iconColor: c.accent,
                  title: r.testName,
                  subtitle: [
                    if (r.category != null) r.category!,
                    if (r.testDate != null) _fmt(r.testDate!),
                  ].join('  ·  '),
                  onTap: () => _openLabReport(r),
                  c: c,
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildEmptyPrompt(ThemeColors c) {
    final shortcuts = [
      _Shortcut(
        icon: Icons.person_rounded,
        label: 'My Doctors',
        onTap: () => Navigator.of(context).pop(),
      ),
      _Shortcut(
        icon: Icons.receipt_long_rounded,
        label: 'Prescriptions',
        onTap: () => Navigator.of(context).pop(),
      ),
      _Shortcut(
        icon: Icons.science_rounded,
        label: 'Lab Reports',
        onTap: () => Navigator.of(context).pop(),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search across',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textSec,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: shortcuts
                .map((s) => _ShortcutChip(shortcut: s, c: c))
                .toList(),
          ),
          const SizedBox(height: 28),
          Text(
            'Type anything to search…',
            style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final ThemeColors c;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: c.accent),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Doctor result tile (with photo) ──────────────────────────────────────────

class _DoctorResultTile extends StatelessWidget {
  final String name;
  final String? specialty;
  final String? hospital;
  final int? visitingFee;
  final String? imageUrl;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;
  final ThemeColors c;

  const _DoctorResultTile({
    required this.name,
    required this.specialty,
    required this.hospital,
    this.visitingFee,
    required this.imageUrl,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
    required this.c,
  });

  String get _initials {
    final parts = name.replaceFirst('Dr. ', '').trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46,
                height: 46,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _initialsBox,
                      )
                    : _initialsBox,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withAlpha(60)),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (specialty != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      specialty!,
                      style: GoogleFonts.poppins(fontSize: 11, color: c.accent),
                    ),
                  ],
                  if (hospital != null) ...[
                    Text(
                      hospital!,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: c.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (visitingFee != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'BDT $visitingFee',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: c.green,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget get _initialsBox => Container(
    color: c.accent.withAlpha(20),
    alignment: Alignment.center,
    child: Text(
      _initials,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: c.accent,
      ),
    ),
  );
}

// ── Generic result tile ───────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final ThemeColors c;

  const _ResultTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: c.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Shortcut chip ─────────────────────────────────────────────────────────────

class _Shortcut {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _ShortcutChip extends StatelessWidget {
  final _Shortcut shortcut;
  final ThemeColors c;
  const _ShortcutChip({required this.shortcut, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: shortcut.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.accent.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(shortcut.icon, color: c.accent, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              shortcut.label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Doctor profile bottom sheet ───────────────────────────────────────────────

class _DoctorProfileSheet extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final bool isLinked;
  const _DoctorProfileSheet({required this.doctorData, required this.isLinked});

  @override
  State<_DoctorProfileSheet> createState() => _DoctorProfileSheetState();
}

class _DoctorProfileSheetState extends State<_DoctorProfileSheet> {
  final _doctorSvc = DoctorService();
  bool _openingAppointment = false;
  bool _checkingMyDoctor = true;
  bool _addingMyDoctor = false;
  bool _alreadyInMyDoctors = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyInMyDoctors();
  }

  void _takeAppointment() {
    if (_openingAppointment) return;
    setState(() => _openingAppointment = true);
    Navigator.of(context).pop(true);
  }

  Future<void> _checkAlreadyInMyDoctors() async {
    try {
      final all = await _doctorSvc.fetchAll();
      final sourceId = widget.doctorData['id'] as String?;
      final fullName = (widget.doctorData['full_name'] as String?)
          ?.trim()
          .toLowerCase();
      final hospital = (widget.doctorData['hospital'] as String?)
          ?.trim()
          .toLowerCase();
      final exists = all.any((d) {
        if (sourceId != null && d.sourceId == sourceId) return true;
        final dn = d.name.trim().toLowerCase();
        final dh = d.hospital?.trim().toLowerCase();
        return dn == fullName && dh == hospital;
      });
      if (!mounted) return;
      setState(() {
        _alreadyInMyDoctors = exists;
        _checkingMyDoctor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingMyDoctor = false);
    }
  }

  Future<void> _addToMyDoctors() async {
    if (_addingMyDoctor || _alreadyInMyDoctors) return;
    setState(() => _addingMyDoctor = true);
    try {
      final d = widget.doctorData;
      await _doctorSvc.create(
        Doctor(
          id: '',
          userId: '',
          name: (d['full_name'] as String?)?.trim().isNotEmpty == true
              ? (d['full_name'] as String).trim()
              : 'Unknown',
          specialty: (d['specialty'] as String?)?.trim(),
          hospital: (d['hospital'] as String?)?.trim(),
          imageUrl: d['avatar_url'] as String?,
          sourceId: d['id'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _alreadyInMyDoctors = true;
        _addingMyDoctor = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Doctor added to My Doctors.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _addingMyDoctor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add doctor. Please try again.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = widget.doctorData;
    final name = d['full_name'] as String? ?? 'Unknown';
    final specialty = d['specialty'] as String?;
    final hospital = d['hospital'] as String?;
    final visitingFee = d['visiting_fee'] as int?;
    final avatar = d['avatar_url'] as String?;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(24, 8, 24, botPad + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          CircleAvatar(
            radius: 40,
            backgroundColor: c.accent.withAlpha(20),
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Icon(
                    Icons.medical_services_rounded,
                    color: c.accent,
                    size: 38,
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            'Dr. $name',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          if (specialty?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              specialty!,
              style: GoogleFonts.poppins(fontSize: 13, color: c.accent),
            ),
          ],
          if (hospital != null) ...[
            const SizedBox(height: 4),
            Text(
              hospital,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
            ),
          ],
          if (visitingFee != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: c.green.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.green.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payments_rounded, size: 14, color: c.green),
                  const SizedBox(width: 5),
                  Text(
                    'Visiting Fee: BDT $visitingFee',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600, color: c.green),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.isLinked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: c.green.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.green.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: c.green),
                  const SizedBox(width: 6),
                  Text(
                    'Linked Doctor',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.green,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.isLinked) ...[const SizedBox(height: 10)],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _checkingMyDoctor ||
                          _addingMyDoctor ||
                          _alreadyInMyDoctors
                      ? null
                      : _addToMyDoctors,
                  icon: _checkingMyDoctor || _addingMyDoctor
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _alreadyInMyDoctors
                              ? Icons.check_circle_rounded
                              : Icons.person_add_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _alreadyInMyDoctors
                        ? 'Added to My Doctors'
                        : 'Add to My Doctors',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _alreadyInMyDoctors ? c.green : c.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _alreadyInMyDoctors
                        ? c.green.withAlpha(170)
                        : c.green.withAlpha(120),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _openingAppointment ? null : _takeAppointment,
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text(
                    'Take Appointment',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Center(
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textSec,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
