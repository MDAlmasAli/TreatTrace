import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../test_report/models/test_report.dart';
import '../../test_report/services/test_report_service.dart';
import '../../test_report/screens/test_report_detail_screen.dart';
import '../../prescription/services/prescription_service.dart';
import 'doctor_test_report_screen.dart';
import 'doctor_prescription_view_screen.dart';

class AllTestReportsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const AllTestReportsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<AllTestReportsScreen> createState() => _AllTestReportsScreenState();
}

class _AllTestReportsScreenState extends State<AllTestReportsScreen> {
  final _svc   = TestReportService();
  final _rxSvc = PrescriptionService();
  final _searchCtrl = TextEditingController();

  final String _currentDoctorId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  List<TestReport> _list       = [];
  bool            _loading    = true;
  DateTime?       _selectedDate;
  bool            _sortNewest = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchForPatient(widget.patientId);
      if (mounted) setState(() => _list = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TestReport> get _filteredList {
    var result = List<TestReport>.from(_list);

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((lab) {
        final name = lab.testName.toLowerCase();
        final cat  = (lab.category ?? '').toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
    }

    if (_selectedDate != null) {
      result = result.where((lab) =>
        lab.testDate != null &&
        lab.testDate!.year  == _selectedDate!.year  &&
        lab.testDate!.month == _selectedDate!.month &&
        lab.testDate!.day   == _selectedDate!.day,
      ).toList();
    }

    result.sort((a, b) {
      final ad = a.testDate;
      final bd = b.testDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return _sortNewest ? 1 : -1;
      if (bd == null) return _sortNewest ? -1 : 1;
      return _sortNewest ? bd.compareTo(ad) : ad.compareTo(bd);
    });

    return result;
  }

  bool get _hasActiveFilter =>
      _searchCtrl.text.trim().isNotEmpty || _selectedDate != null;

  void _clearAll() => setState(() {
    _searchCtrl.clear();
    _selectedDate = null;
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: context.colors.green),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _goView(TestReport lab) async {
    final canEdit = lab.orderedByDoctorId == _currentDoctorId;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TestReportDetailScreen(
        report:    lab,
        canEdit:   canEdit,
        canDelete: false,
        onEditOverride: canEdit
            ? (r) => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DoctorTestReportScreen(
                    patientId:   widget.patientId,
                    patientName: widget.patientName,
                    existing:    r,
                  ),
                ))
            : null,
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

  Future<void> _goEdit(TestReport lab) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorTestReportScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
        existing:    lab,
      ),
    ));
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final filtered = _filteredList;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c),

          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color:        c.card,
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: c.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                style:      GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText:   'Search by test name or category…',
                  hintStyle:  GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: c.textSec, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => _searchCtrl.clear()),
                          child: Icon(Icons.close_rounded, color: c.textMuted, size: 18),
                        )
                      : null,
                  border:         InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
          ),

          // ── Filter row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color:        _selectedDate != null
                          ? c.green.withAlpha(18) : c.card,
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(
                        color: _selectedDate != null ? c.green : c.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 13,
                            color: _selectedDate != null ? c.green : c.textSec),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDate != null
                              ? _fmtDate(_selectedDate!) : 'All dates',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedDate != null ? c.green : c.textSec),
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: () => setState(() => _selectedDate = null),
                            child: Icon(Icons.close_rounded, size: 13, color: c.green),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                GestureDetector(
                  onTap: () => setState(() => _sortNewest = !_sortNewest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color:        c.card,
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sortNewest
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size:  13,
                          color: c.textSec,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _sortNewest ? 'Newest' : 'Oldest',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.textSec),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                if (_hasActiveFilter)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Text('Clear',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.red)),
                  ),

                if (!_hasActiveFilter || filtered.length != _list.length)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      _hasActiveFilter
                          ? '${filtered.length} / ${_list.length}'
                          : '${_list.length}',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted),
                    ),
                  ),
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.green, strokeWidth: 2.5))
                : filtered.isEmpty
                    ? _EmptyState(hasFilter: _hasActiveFilter)
                    : RefreshIndicator(
                        color:     c.green,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:     const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount:   filtered.length,
                          itemBuilder: (ctx, i) => _TestReportTile(
                            lab:     filtered[i],
                            canEdit: filtered[i].orderedByDoctorId == _currentDoctorId,
                            onView:  () => _goView(filtered[i]),
                            onEdit:  () => _goEdit(filtered[i]),
                          ).animate().fadeIn(delay: Duration(milliseconds: 25 * i)),
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
        color: c.card,
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
                Text('All Test Reports',
                    style: GoogleFonts.poppins(
                        fontSize: 19, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text(widget.patientName,
                    style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        c.green.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_list.length}',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.green)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter ? Icons.search_off_rounded : Icons.science_outlined,
            size: 56, color: c.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'No results found' : 'No test reports found',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600, color: c.textSec),
          ),
          const SizedBox(height: 4),
          Text(
            hasFilter
                ? 'Try adjusting your search or filters.'
                : 'No test reports have been added yet.',
            style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Test report tile ───────────────────────────────────────────────────────────

class _TestReportTile extends StatelessWidget {
  final TestReport    lab;
  final bool         canEdit;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const _TestReportTile({
    required this.lab,
    required this.canEdit,
    required this.onView,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final months  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d       = lab.testDate;
    final dateStr = d != null ? '${d.day} ${months[d.month - 1]} ${d.year}' : '—';

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
              color:        c.green.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
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
                Text(dateStr,
                    style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
              ],
            ),
          ),
          if (lab.category != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        c.green.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(lab.category!,
                  style: GoogleFonts.poppins(
                      fontSize: 10, fontWeight: FontWeight.w600, color: c.green),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onView,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        c.green.withAlpha(12),
                borderRadius: BorderRadius.circular(9),
                border:       Border.all(color: c.green.withAlpha(40)),
              ),
              child: Icon(Icons.visibility_rounded, size: 15, color: c.green),
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
