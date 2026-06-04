// global_search_screen.dart â€” Cross-feature search: doctors, prescriptions, lab reports.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../doctor_home/models/doctor_patient_link.dart';
import '../../doctor_home/services/doctor_patient_link_service.dart';
import 'doctor_public_profile_screen.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import '../../prescription/screens/prescription_detail_screen.dart';
import '../../test_report/models/test_report.dart';
import '../../test_report/services/test_report_service.dart';
import '../../test_report/screens/test_report_detail_screen.dart';
import '../../review/widgets/review_widgets.dart';
import '../widgets/doctor_filter_sheet.dart';

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
  final _testReportSvc = TestReportService();

  bool _loading = true;
  String _query = '';
  DoctorFilter _filter = const DoctorFilter();

  List<Map<String, dynamic>> _allDoctors = [];
  Set<String> _linkedIds = {};
  List<Prescription> _prescriptions = [];
  List<TestReport> _testReports = [];

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
        _testReportSvc.fetchAll(),
      ]);
      _allDoctors = results[0] as List<Map<String, dynamic>>;
      _linkedIds = (results[1] as List<DoctorPatientLink>)
          .where((l) => l.isAccepted)
          .map((l) => l.doctorId)
          .toSet();
      _prescriptions = results[2] as List<Prescription>;
      _testReports = results[3] as List<TestReport>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // â”€â”€ Filtered results â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // Doctors are shown by default (empty query = all), narrowed by the text
  // query and the active filter, then sorted. The filter/sort always applies.
  List<Map<String, dynamic>> get _filteredDoctors {
    final q = _query.toLowerCase();
    final base = _query.isEmpty
        ? _allDoctors
        : _allDoctors.where((d) =>
            ((d['full_name'] as String?)?.toLowerCase().contains(q) ?? false) ||
            ((d['specialty'] as String?)?.toLowerCase().contains(q) ?? false) ||
            ((d['hospital'] as String?)?.toLowerCase().contains(q) ?? false)).toList();
    return applyDoctorFilter(base, _filter);
  }

  // ── Filter option lists (derived from the loaded doctors) ─────────────────

  List<String> get _specialtyOptions => (_allDoctors
          .map((d) => d['specialty'] as String?)
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort());

  List<String> get _hospitalOptions => (_allDoctors
          .map((d) => d['hospital'] as String?)
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort());

  RangeValues? get _feeBounds {
    final fees = _allDoctors
        .map((d) => (d['visiting_fee'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (fees.isEmpty) return null;
    final lo = fees.reduce((a, b) => a < b ? a : b);
    final hi = fees.reduce((a, b) => a > b ? a : b);
    return hi > lo ? RangeValues(lo, hi) : null;
  }

  Future<void> _openFilter() async {
    final res = await showDoctorFilterSheet(
      context,
      current:     _filter,
      specialties: _specialtyOptions,
      hospitals:   _hospitalOptions,
      feeBounds:   _feeBounds,
    );
    if (res != null) setState(() => _filter = res);
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

  List<TestReport> get _filteredTestReports {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _testReports
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
      _filteredTestReports.isNotEmpty;

  // â”€â”€ Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _openDoctorProfile(Map<String, dynamic> d) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorPublicProfileScreen(
          doctorId:        d['id'] as String,
          initialName:     d['full_name'] as String?,
          initialAvatarUrl: d['avatar_url'] as String?,
        ),
      ),
    );
  }

  void _openPrescription(Prescription p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrescriptionDetailScreen(prescription: p),
      ),
    );
  }

  void _openTestReport(TestReport r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TestReportDetailScreen(
        report:            r,
        onPrescriptionTap: (id) => _openLinkedRx(id),
      ),
    ));
  }

  Future<void> _openLinkedRx(String prescriptionId) async {
    final p = await _prescriptionSvc.fetchOne(prescriptionId);
    if (p == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PrescriptionDetailScreen(prescription: p)),
    );
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                  hintText: 'Search doctors, medicines, reportsâ€¦',
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
          const SizedBox(width: 12),
          _buildFilterButton(c),
        ],
      ),
    );
  }

  Widget _buildFilterButton(ThemeColors c) {
    final count = _filter.activeCount;
    final active = count > 0;
    return GestureDetector(
      onTap: _openFilter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? c.accent.withAlpha(22) : c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? c.accent : c.border),
            ),
            child: Icon(Icons.tune_rounded,
                color: active ? c.accent : c.textSec, size: 20),
          ),
          if (active)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: c.card, width: 1.5),
                ),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1)),
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
    if (!_hasAnyResults) return _emptyState(c);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (_filteredDoctors.isNotEmpty) ...[
          _SectionHeader(
            title: _query.isEmpty
                ? 'All Doctors (${_filteredDoctors.length})'
                : 'Doctors (${_filteredDoctors.length})',
            icon: Icons.person_rounded,
            c: c,
          ),
          const SizedBox(height: 8),
          ..._filteredDoctors.map((d) {
            final isLinked = _linkedIds.contains(d['id'] as String?);
            return _DoctorResultTile(
              name: 'Dr. ${d['full_name'] ?? "Unknown"}',
              specialty: d['specialty'] as String?,
              hospital: d['hospital'] as String?,
              visitingFee: d['visiting_fee'] as int?,
              imageUrl: d['avatar_url'] as String?,
              ratingAvg: (d['rating_avg'] as num?)?.toDouble() ?? 0,
              ratingCount: (d['rating_count'] as num?)?.toInt() ?? 0,
              badge: isLinked ? 'My Doctor' : 'Doctor',
              badgeColor: isLinked ? c.green : c.accent,
              onTap: () => _openDoctorProfile(d),
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
                  ].join('  Â·  '),
                  onTap: () => _openPrescription(p),
                  c: c,
                ),
              ),
          const SizedBox(height: 20),
        ],
        if (_filteredTestReports.isNotEmpty) ...[
          _SectionHeader(
            title: 'Test Reports',
            icon: Icons.science_rounded,
            c: c,
          ),
          const SizedBox(height: 8),
          ..._filteredTestReports
              .take(4)
              .map(
                (r) => _ResultTile(
                  icon: Icons.science_rounded,
                  iconColor: c.accent,
                  title: r.testName,
                  subtitle: [
                    if (r.category != null) r.category!,
                    if (r.testDate != null) _fmt(r.testDate!),
                  ].join('  Â·  '),
                  onTap: () => _openTestReport(r),
                  c: c,
                ),
              ),
        ],
      ],
    );
  }

  Widget _emptyState(ThemeColors c) {
    final filterActive = _query.isEmpty && _filter.activeCount > 0;
    final String msg;
    if (_query.isNotEmpty) {
      msg = 'No results for "$_query"';
    } else if (filterActive) {
      msg = 'No doctors match your filters';
    } else {
      msg = 'No registered doctors yet';
    }
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
          Text(msg, style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
          if (filterActive) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _filter = const DoctorFilter()),
              child: Text('Clear filters',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.accent)),
            ),
          ],
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

// â”€â”€ Section header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€ Doctor result tile (with photo) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DoctorResultTile extends StatelessWidget {
  final String name;
  final String? specialty;
  final String? hospital;
  final int? visitingFee;
  final String? imageUrl;
  final double ratingAvg;
  final int ratingCount;
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
    this.ratingAvg = 0,
    this.ratingCount = 0,
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
                  Row(
                    children: [
                      if (visitingFee != null)
                        Text(
                          'BDT $visitingFee',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: c.green,
                          ),
                        ),
                      if (visitingFee != null && ratingCount > 0)
                        Text('  ·  ',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: c.textMuted)),
                      if (ratingCount > 0)
                        RatingBadge(avg: ratingAvg, count: ratingCount),
                    ],
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

// â”€â”€ Generic result tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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


