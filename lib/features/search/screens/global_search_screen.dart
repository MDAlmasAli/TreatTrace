// global_search_screen.dart — Cross-feature search: doctors, prescriptions, lab reports.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../doctor/models/doctor.dart';
import '../../doctor/models/public_doctor.dart';
import '../../doctor/services/doctor_service.dart';
import '../../doctor/services/public_doctor_service.dart';
import '../../doctor/screens/doctor_detail_screen.dart';
import '../../doctor/screens/discover_doctors_screen.dart';
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
  final _focusNode  = FocusNode();

  final _doctorSvc      = DoctorService();
  final _publicSvc      = PublicDoctorService();
  final _prescriptionSvc = PrescriptionService();
  final _labReportSvc   = LabReportService();

  bool                _loading      = true;
  String              _query        = '';

  List<Doctor>        _myDoctors    = [];
  List<PublicDoctor>  _pubDoctors   = [];
  Set<String>         _savedIds     = {};
  List<Prescription>  _prescriptions = [];
  List<LabReport>     _labReports   = [];

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
        _doctorSvc.fetchAll(),
        _publicSvc.fetchAll(),
        _publicSvc.fetchSavedSourceIds(),
        _prescriptionSvc.fetchAll(),
        _labReportSvc.fetchAll(),
      ]);
      _myDoctors     = results[0] as List<Doctor>;
      _pubDoctors    = results[1] as List<PublicDoctor>;
      _savedIds      = results[2] as Set<String>;
      _prescriptions = results[3] as List<Prescription>;
      _labReports    = results[4] as List<LabReport>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Filtered results ──────────────────────────────────────────────────────

  List<Doctor> get _filteredMyDoctors {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _myDoctors.where((d) =>
        d.name.toLowerCase().contains(q) ||
        (d.specialty?.toLowerCase().contains(q) ?? false) ||
        (d.hospital?.toLowerCase().contains(q) ?? false)).toList();
  }

  // Public doctors not yet saved to My Doctors
  List<PublicDoctor> get _filteredPublicDoctors {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _pubDoctors
        .where((pd) => !_savedIds.contains(pd.id))
        .where((pd) =>
            pd.name.toLowerCase().contains(q) ||
            (pd.specialty?.toLowerCase().contains(q) ?? false) ||
            (pd.hospital?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<Prescription> get _filteredPrescriptions {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _prescriptions.where((p) {
      if (p.doctorName?.toLowerCase().contains(q) ?? false) return true;
      if (p.diagnosis?.toLowerCase().contains(q) ?? false) return true;
      return p.medicines.any(
          (m) => m.medicineName.toLowerCase().contains(q));
    }).toList();
  }

  List<LabReport> get _filteredLabReports {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _labReports.where((r) =>
        r.testName.toLowerCase().contains(q) ||
        (r.category?.toLowerCase().contains(q) ?? false) ||
        (r.doctorName?.toLowerCase().contains(q) ?? false)).toList();
  }

  bool get _hasAnyResults =>
      _filteredMyDoctors.isNotEmpty ||
      _filteredPublicDoctors.isNotEmpty ||
      _filteredPrescriptions.isNotEmpty ||
      _filteredLabReports.isNotEmpty;

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDoctor(Doctor d) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: d)),
    );
  }

  void _openDiscover() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DiscoverDoctorsScreen()),
    );
  }

  void _openPrescription(Prescription p) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => PrescriptionDetailScreen(prescription: p)),
    );
  }

  void _openLabReport(LabReport r) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => LabReportDetailScreen(report: r)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

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
          top: topPad + 12, left: 16, right: 16, bottom: 14),
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
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color:        c.surface,
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: c.border),
              ),
              child: TextField(
                controller:  _searchCtrl,
                focusNode:   _focusNode,
                onChanged:   (v) => setState(() => _query = v.trim()),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText:  'Search doctors, medicines, reports…',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 12, color: c.textMuted),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: c.accent, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: Icon(Icons.close_rounded,
                              color: c.textMuted, size: 18),
                        )
                      : null,
                  border:         InputBorder.none,
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
      return Center(
          child: CircularProgressIndicator(color: c.accent));
    }
    if (_query.isEmpty) return _buildEmptyPrompt(c);
    if (!_hasAnyResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:        c.accent.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.search_off_rounded,
                  color: c.accent, size: 36),
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
        if (_filteredMyDoctors.isNotEmpty) ...[
          _SectionHeader(
            title: 'My Doctors',
            icon:  Icons.person_rounded,
            onSeeAll: () => Navigator.of(context).pop(),
            c: c,
          ),
          const SizedBox(height: 8),
          ..._filteredMyDoctors.take(4).map((d) => _DoctorResultTile(
                name:      d.displayName,
                specialty: d.specialty,
                hospital:  d.hospital,
                imageUrl:  d.imageUrl,
                badge:     'My Doctor',
                badgeColor: c.green,
                onTap:     () => _openDoctor(d),
                c: c,
              )),
          const SizedBox(height: 20),
        ],
        if (_filteredPublicDoctors.isNotEmpty) ...[
          _SectionHeader(
            title:    'Discover Doctors',
            icon:     Icons.explore_rounded,
            onSeeAll: _openDiscover,
            c: c,
          ),
          const SizedBox(height: 8),
          ..._filteredPublicDoctors.take(4).map((pd) => _DoctorResultTile(
                name:      pd.displayName,
                specialty: pd.specialty,
                hospital:  pd.hospital,
                imageUrl:  pd.imageUrl,
                badge:     'Catalog',
                badgeColor: c.accent,
                onTap:     _openDiscover,
                c: c,
              )),
          const SizedBox(height: 20),
        ],
        if (_filteredPrescriptions.isNotEmpty) ...[
          _SectionHeader(
            title:    'Prescriptions',
            icon:     Icons.receipt_long_rounded,
            c: c,
          ),
          const SizedBox(height: 8),
          ..._filteredPrescriptions.take(4).map((p) => _ResultTile(
                icon:     Icons.receipt_long_rounded,
                iconColor: c.accent,
                title:    p.diagnosis ?? p.doctorName ?? 'Prescription',
                subtitle: [
                  if (p.doctorName != null) 'Dr. ${p.doctorName}',
                  _fmt(p.prescriptionDate),
                ].join('  ·  '),
                onTap: () => _openPrescription(p),
                c: c,
              )),
          const SizedBox(height: 20),
        ],
        if (_filteredLabReports.isNotEmpty) ...[
          _SectionHeader(
            title:    'Lab Reports',
            icon:     Icons.science_rounded,
            c: c,
          ),
          const SizedBox(height: 8),
          ..._filteredLabReports.take(4).map((r) => _ResultTile(
                icon:     Icons.science_rounded,
                iconColor: c.accent,
                title:    r.testName,
                subtitle: [
                  if (r.category != null) r.category!,
                  if (r.testDate != null) _fmt(r.testDate!),
                ].join('  ·  '),
                onTap: () => _openLabReport(r),
                c: c,
              )),
        ],
      ],
    );
  }

  Widget _buildEmptyPrompt(ThemeColors c) {
    final shortcuts = [
      _Shortcut(
          icon: Icons.person_rounded,
          label: 'My Doctors',
          onTap: () => Navigator.of(context).pop()),
      _Shortcut(
          icon: Icons.explore_rounded,
          label: 'Discover',
          onTap: _openDiscover),
      _Shortcut(
          icon: Icons.receipt_long_rounded,
          label: 'Prescriptions',
          onTap: () => Navigator.of(context).pop()),
      _Shortcut(
          icon: Icons.science_rounded,
          label: 'Lab Reports',
          onTap: () => Navigator.of(context).pop()),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search across',
            style: GoogleFonts.poppins(
              fontSize:   14,
              fontWeight: FontWeight.w600,
              color:      c.textSec,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap:       true,
            physics:          const NeverScrollableScrollPhysics(),
            crossAxisCount:   2,
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
            childAspectRatio: 2.4,
            children: shortcuts
                .map((s) => _ShortcutChip(shortcut: s, c: c))
                .toList(),
          ),
          const SizedBox(height: 28),
          Text(
            'Type anything to search…',
            style: GoogleFonts.poppins(
                fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String      title;
  final IconData    icon;
  final VoidCallback? onSeeAll;
  final ThemeColors c;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.c,
    this.onSeeAll,
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
            fontSize:   13,
            fontWeight: FontWeight.w700,
            color:      c.textPrimary,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'See all',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: c.accent,
                  fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

// ── Doctor result tile (with photo) ──────────────────────────────────────────

class _DoctorResultTile extends StatelessWidget {
  final String      name;
  final String?     specialty;
  final String?     hospital;
  final String?     imageUrl;
  final String      badge;
  final Color       badgeColor;
  final VoidCallback onTap;
  final ThemeColors c;

  const _DoctorResultTile({
    required this.name,
    required this.specialty,
    required this.hospital,
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
          color:        c.card,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: c.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46, height: 46,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit:          BoxFit.cover,
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
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      c.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        badgeColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                          border:       Border.all(
                              color: badgeColor.withAlpha(60)),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  if (specialty != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      specialty!,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: c.accent),
                    ),
                  ],
                  if (hospital != null) ...[
                    Text(
                      hospital!,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            fontSize:   16,
            fontWeight: FontWeight.w700,
            color:      c.accent,
          ),
        ),
      );
}

// ── Generic result tile ───────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final IconData    icon;
  final Color       iconColor;
  final String      title;
  final String      subtitle;
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
          color:        c.card,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        iconColor.withAlpha(18),
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
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: c.textMuted),
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
  final IconData    icon;
  final String      label;
  final VoidCallback onTap;
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _ShortcutChip extends StatelessWidget {
  final _Shortcut   shortcut;
  final ThemeColors c;
  const _ShortcutChip({required this.shortcut, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: shortcut.onTap,
      child: Container(
        decoration: BoxDecoration(
          color:        c.card,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: c.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color:        c.accent.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(shortcut.icon, color: c.accent, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              shortcut.label,
              style: GoogleFonts.poppins(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
