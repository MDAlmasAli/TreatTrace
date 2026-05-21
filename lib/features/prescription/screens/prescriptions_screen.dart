// prescriptions_screen.dart — Prescription list with All/Active/Expired tabs + search.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../models/prescription.dart';
import '../services/prescription_service.dart';
import 'add_edit_prescription_screen.dart';
import 'prescription_detail_screen.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen>
    with SingleTickerProviderStateMixin {
  final _service    = PrescriptionService();
  final _searchCtrl = TextEditingController();

  late final TabController _tabCtrl;

  bool                  _loading = true;
  List<Prescription>    _all     = [];
  String                _query   = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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

  List<Prescription> _filtered(List<Prescription> source) {
    if (_query.isEmpty) return source;
    final q = _query.toLowerCase();
    return source.where((p) {
      return (p.doctorName?.toLowerCase().contains(q)    ?? false) ||
             (p.diagnosis?.toLowerCase().contains(q)     ?? false) ||
             p.medicines.any((m) => m.medicineName.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => const AddEditPrescriptionScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _openDetail(Prescription p) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => PrescriptionDetailScreen(prescription: p)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  c.statusBarIconBrightness,
    ));

    final all     = _filtered(_all);
    final active  = _filtered(_all.where((p) => p.isActive).toList());
    final expired = _filtered(_all.where((p) => !p.isActive).toList());

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c, s),
          _buildSearch(c, s),
          _buildTabBar(c, s),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: c.purpleBright))
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _PrescriptionList(
                        items:    all,
                        emptyMsg: s.noPrescriptions,
                        onTap:    _openDetail,
                      ),
                      _PrescriptionList(
                        items:    active,
                        emptyMsg: s.noPrescriptions,
                        onTap:    _openDetail,
                      ),
                      _PrescriptionList(
                        items:    expired,
                        emptyMsg: s.noPrescriptions,
                        onTap:    _openDetail,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:       _openAdd,
        backgroundColor: Theme.of(context).colorScheme.primary,
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
              s.prescriptions,
              style: GoogleFonts.poppins(
                fontSize:   22,
                fontWeight: FontWeight.w700,
                color:      c.textPrimary,
              ),
            ),
          ),
          _RefillBadge(count: _all.where((p) => p.needsRefillSoon).length),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }

  Widget _buildSearch(ThemeColors c, S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
            hintText:       s.searchPrescriptions,
            hintStyle:      GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
            prefixIcon:     Icon(Icons.search_rounded,
                                color: c.purpleBright, size: 20),
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
            border:          InputBorder.none,
            contentPadding:  const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeColors c, S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TabBar(
        controller:         _tabCtrl,
        labelColor:         c.purpleBright,
        unselectedLabelColor: c.textMuted,
        indicatorColor:     c.purpleBright,
        indicatorWeight:    2.5,
        labelStyle:         GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
        dividerColor:       c.border,
        tabs: [
          Tab(text: s.all),
          Tab(text: s.active),
          Tab(text: s.expired),
        ],
      ),
    );
  }
}

// ── Prescription list ─────────────────────────────────────────────────────────

class _PrescriptionList extends StatelessWidget {
  final List<Prescription> items;
  final String             emptyMsg;
  final void Function(Prescription) onTap;

  const _PrescriptionList({
    required this.items,
    required this.emptyMsg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(message: emptyMsg);
    }
    return RefreshIndicator(
      color: context.colors.purpleBright,
      onRefresh: () async {},
      child: ListView.separated(
        padding:           const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount:         items.length,
        separatorBuilder:  (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _PrescriptionCard(
          prescription: items[i],
          onTap:        () => onTap(items[i]),
          delay:        i * 40,
        ),
      ),
    );
  }
}

// ── Prescription card ─────────────────────────────────────────────────────────

class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  final VoidCallback onTap;
  final int          delay;

  const _PrescriptionCard({
    required this.prescription,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final p       = prescription;
    final isActive = p.isActive;
    final accent   = isActive ? c.cyan : c.textMuted;

    return Material(
      color:        c.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor:  c.purpleBright.withAlpha(12),
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
                  // Left accent bar
                  Container(width: 4, color: accent),
                  // Card content
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
                                  p.doctorName?.isNotEmpty == true
                                      ? 'Dr. ${p.doctorName}'
                                      : 'Unknown Doctor',
                                  style: GoogleFonts.poppins(
                                    fontSize:   15,
                                    fontWeight: FontWeight.w700,
                                    color:      c.textPrimary,
                                  ),
                                ),
                              ),
                              if (p.needsRefillSoon)
                                _Badge(
                                    label: 'Refill',
                                    color: c.amber),
                              if (!isActive)
                                _Badge(
                                    label: 'Expired',
                                    color: c.textMuted),
                              if (isActive && !p.needsRefillSoon)
                                _Badge(
                                    label: 'Active',
                                    color: c.green),
                            ],
                          ),
                          if (p.doctorSpecialty?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.doctorSpecialty!,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: c.textSec),
                            ),
                          ],
                          if (p.diagnosis?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Text(
                              p.diagnosis!,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: c.textSec),
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
                                _fmtDate(p.prescriptionDate),
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: c.textMuted),
                              ),
                              const Spacer(),
                              Icon(Icons.medication_rounded,
                                  size: 12, color: c.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${p.medicines.length} medicine${p.medicines.length == 1 ? '' : 's'}',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: c.textMuted),
                              ),
                            ],
                          ),
                          if (p.hasAllergyConflict) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.warning_rounded,
                                    size: 13, color: c.red),
                                const SizedBox(width: 4),
                                Text(
                                  'Allergy conflict',
                                  style: GoogleFonts.poppins(
                                    fontSize:   11,
                                    color:      c.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Arrow
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
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.06);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Empty state ───────────────────────────────────────────────────────────────

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
              color:        c.purpleBright.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.receipt_long_rounded,
                color: c.purpleBright, size: 36),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

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

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
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

class _RefillBadge extends StatelessWidget {
  final int count;
  const _RefillBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        c.amber.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.amber.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh_rounded, size: 13, color: c.amber),
          const SizedBox(width: 4),
          Text(
            '$count refill${count > 1 ? 's' : ''} soon',
            style: GoogleFonts.poppins(
              fontSize:   11,
              fontWeight: FontWeight.w700,
              color:      c.amber,
            ),
          ),
        ],
      ),
    );
  }
}
