// test_reports_screen.dart — Test report list with search + category filter.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../models/test_report.dart';
import '../services/test_report_service.dart';
import '../../prescription/services/prescription_service.dart';
import '../../prescription/screens/prescription_detail_screen.dart';
import 'add_edit_test_report_screen.dart';
import 'test_report_detail_screen.dart';

class TestReportsScreen extends StatefulWidget {
  const TestReportsScreen({super.key});

  @override
  State<TestReportsScreen> createState() => _TestReportsScreenState();
}

class _TestReportsScreenState extends State<TestReportsScreen> {
  final _service = TestReportService();
  final _rxSvc   = PrescriptionService();
  final _searchCtrl = TextEditingController();

  bool             _loading        = true;
  List<TestReport>  _all            = [];
  String           _query          = '';
  String?          _selectedCategory; // null = show all
  DateTime?        _date;             // null = no date filter

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _all = await _service.fetchAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  List<String> get _categories {
    final seen = <String>{};
    final cats = <String>[];
    for (final r in _all) {
      final cat = r.category;
      if (cat != null && cat.isNotEmpty && seen.add(cat)) cats.add(cat);
    }
    cats.sort();
    return cats;
  }

  List<TestReport> get _filtered {
    var list = _all;
    if (_selectedCategory != null) {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }
    if (_date != null) {
      list = list
          .where((r) => r.testDate != null && _sameDay(r.testDate!, _date!))
          .toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((r) {
        return r.testName.toLowerCase().contains(q) ||
            (r.doctorName?.toLowerCase().contains(q) ?? false) ||
            (r.hospital?.toLowerCase().contains(q) ?? false) ||
            (r.category?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return list;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date ?? now,
      firstDate:   DateTime(2000),
      lastDate:    DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditTestReportScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _openDetail(TestReport r) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TestReportDetailScreen(
          report:            r,
          onPrescriptionTap: (id) => _openLinkedRx(id),
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openLinkedRx(String prescriptionId) async {
    final p = await _rxSvc.fetchOne(prescriptionId);
    if (p == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PrescriptionDetailScreen(prescription: p)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    final items = _filtered;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c, s),
          _buildSearch(c, s),
          if (_date != null) _buildDateChip(c),
          _buildCategoryChips(c, s),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: c.cyan))
                : items.isEmpty
                    ? _EmptyState(
                        message: _query.isNotEmpty ||
                                _selectedCategory != null ||
                                _date != null
                            ? 'No results found'
                            : s.noTestReports,
                      )
                    : RefreshIndicator(
                        color: c.cyan,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          itemCount:        items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _TestReportCard(
                            report: items[i],
                            onTap:  () => _openDetail(items[i]),
                            delay:  i * 40,
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:       _openAdd,
        backgroundColor: c.cyan,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c, S s) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
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
            blurRadius: 12,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
          top: topPad + 16, left: 20, right: 20, bottom: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: _IconBtn(icon: Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s.testReports,
              style: GoogleFonts.poppins(
                fontSize:   22,
                fontWeight: FontWeight.w700,
                color:      c.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        c.cyan.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: c.cyan.withAlpha(60)),
            ),
            child: Text(
              '${_all.length}',
              style: GoogleFonts.poppins(
                fontSize:   12,
                fontWeight: FontWeight.w700,
                color:      c.cyan,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }

  Widget _buildSearch(ThemeColors c, S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color:        c.card,
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: c.border, width: 1),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged:  (v) => setState(() => _query = v.trim()),
                style:      GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText:  s.searchTestReports,
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: c.cyan, size: 20),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _DateFilterBtn(
            active: _date != null,
            accent: c.cyan,
            onTap:  _pickDate,
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(ThemeColors c) {
    final d = _date!;
    final label =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => setState(() => _date = null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color:        c.cyan.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: c.cyan.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_rounded, size: 14, color: c.cyan),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      c.cyan,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.close_rounded, size: 15, color: c.cyan),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(ThemeColors c, S s) {
    final cats = _categories;
    if (cats.isEmpty) return const SizedBox(height: 12);

    return SizedBox(
      height: 52,
      child: ListView(
        padding:       const EdgeInsets.fromLTRB(20, 12, 20, 0),
        scrollDirection: Axis.horizontal,
        children: [
          // "All" chip
          _FilterChip(
            label:    s.all,
            selected: _selectedCategory == null,
            onTap:    () => setState(() => _selectedCategory = null),
          ),
          ...cats.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _FilterChip(
                  label:    cat,
                  selected: _selectedCategory == cat,
                  onTap:    () => setState(() =>
                      _selectedCategory = _selectedCategory == cat
                          ? null
                          : cat),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Test report card ───────────────────────────────────────────────────────────

class _TestReportCard extends StatelessWidget {
  final TestReport    report;
  final VoidCallback onTap;
  final int          delay;

  const _TestReportCard({
    required this.report,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = report;

    return Material(
      color:        c.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor:  c.cyan.withAlpha(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withAlpha(6),
                blurRadius: 8,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: c.cyan),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.testName,
                                  style: GoogleFonts.poppins(
                                    fontSize:   15,
                                    fontWeight: FontWeight.w700,
                                    color:      c.textPrimary,
                                  ),
                                ),
                              ),
                              if (r.category?.isNotEmpty == true &&
                                  r.category != r.testName)
                                _CategoryBadge(label: r.category!),
                            ],
                          ),
                          if (r.doctorName?.isNotEmpty == true) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Dr. ${r.doctorName}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: c.textSec),
                            ),
                          ],
                          if (r.hospital?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              r.hospital!,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: c.textSec),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 12, color: c.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                r.testDate != null
                                    ? _fmtDate(r.testDate!)
                                    : '—',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: c.textMuted),
                              ),
                              const Spacer(),
                              if (r.hasImages) ...[
                                Icon(Icons.image_rounded,
                                    size: 12, color: c.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  '${r.imageUrls.length} image${r.imageUrls.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: c.textMuted),
                                ),
                              ],
                              if (r.prescriptionId != null) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.link_rounded,
                                    size: 12, color: c.purpleBright),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(Icons.chevron_right_rounded,
                        color: c.textMuted, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideY(begin: 0.06);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _DateFilterBtn extends StatelessWidget {
  final bool         active;
  final Color        accent;
  final VoidCallback onTap;
  const _DateFilterBtn({
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color:        active ? accent.withAlpha(20) : c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? accent : c.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Icon(Icons.calendar_today_rounded,
            color: active ? accent : c.textMuted, size: 20),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.cyan.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.cyan.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w700, color: c.cyan),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.cyan.withAlpha(25) : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.cyan : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize:   12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color:      selected ? c.cyan : c.textMuted,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color:        c.cyan.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.science_rounded,
                color: c.cyan, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
          ),
        ],
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
