import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import 'doctor_prescription_view_screen.dart';
import 'doctor_write_prescription_screen.dart';

class AllPrescriptionsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const AllPrescriptionsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<AllPrescriptionsScreen> createState() => _AllPrescriptionsScreenState();
}

class _AllPrescriptionsScreenState extends State<AllPrescriptionsScreen> {
  final _svc        = PrescriptionService();
  final _searchCtrl = TextEditingController();

  final String _currentDoctorId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  List<Prescription> _list        = [];
  bool               _loading     = true;
  DateTime?          _selectedDate;
  bool               _sortNewest  = true;

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

  List<Prescription> get _filteredList {
    var result = List<Prescription>.from(_list);

    // Text search on diagnosis and medicine names
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((rx) {
        final diag = (rx.diagnosis ?? '').toLowerCase();
        final meds = rx.medicines.map((m) => m.medicineName.toLowerCase()).join(' ');
        return diag.contains(q) || meds.contains(q);
      }).toList();
    }

    // Date filter
    if (_selectedDate != null) {
      result = result.where((rx) =>
        rx.prescriptionDate.year  == _selectedDate!.year  &&
        rx.prescriptionDate.month == _selectedDate!.month &&
        rx.prescriptionDate.day   == _selectedDate!.day,
      ).toList();
    }

    // Sort
    result.sort((a, b) => _sortNewest
        ? b.prescriptionDate.compareTo(a.prescriptionDate)
        : a.prescriptionDate.compareTo(b.prescriptionDate));

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
          colorScheme: ColorScheme.light(primary: context.colors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _goView(Prescription rx) async {
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

  Future<void> _goEdit(Prescription rx) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorWritePrescriptionScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
        existing:    rx,
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
                controller:  _searchCtrl,
                style:       GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText:       'Search by diagnosis or medicine…',
                  hintStyle:      GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                  prefixIcon:     Icon(Icons.search_rounded, color: c.textSec, size: 20),
                  suffixIcon:     _searchCtrl.text.isNotEmpty
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
                // Date filter chip
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color:        _selectedDate != null
                          ? c.accent.withAlpha(18)
                          : c.card,
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(
                        color: _selectedDate != null ? c.accent : c.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 13,
                            color: _selectedDate != null ? c.accent : c.textSec),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDate != null
                              ? _fmtDate(_selectedDate!)
                              : 'All dates',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedDate != null ? c.accent : c.textSec),
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: () => setState(() => _selectedDate = null),
                            child: Icon(Icons.close_rounded,
                                size: 13, color: c.accent),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Sort toggle
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

                // Clear all filters
                if (_hasActiveFilter)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Text('Clear',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.red)),
                  ),

                // Result count
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
                ? Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5))
                : filtered.isEmpty
                    ? _EmptyState(hasFilter: _hasActiveFilter)
                    : RefreshIndicator(
                        color:     c.accent,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:     const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount:   filtered.length,
                          itemBuilder: (ctx, i) => _RxTile(
                            rx:      filtered[i],
                            canEdit: filtered[i].writtenByDoctorId == _currentDoctorId,
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
                Text('All Prescriptions',
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
              color:        c.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_list.length}',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
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
            hasFilter ? Icons.search_off_rounded : Icons.medication_outlined,
            size: 56, color: c.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'No results found' : 'No prescriptions found',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600, color: c.textSec),
          ),
          const SizedBox(height: 4),
          Text(
            hasFilter
                ? 'Try adjusting your search or filters.'
                : 'No prescriptions have been written yet.',
            style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Prescription tile ─────────────────────────────────────────────────────────

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
    final dateStr = '${date.day} ${months[date.month - 1]} ${date.year}';

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
