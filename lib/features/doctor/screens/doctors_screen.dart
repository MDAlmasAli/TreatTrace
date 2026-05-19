// doctors_screen.dart — Personal doctor book: list, search, specialty filter.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../models/doctor.dart';
import '../services/doctor_service.dart';
import 'add_edit_doctor_screen.dart';
import 'doctor_detail_screen.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _service    = DoctorService();
  final _searchCtrl = TextEditingController();

  bool          _loading           = true;
  List<Doctor>  _all               = [];
  String        _query             = '';
  String?       _selectedSpecialty;

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

  List<String> get _specialties {
    final seen = <String>{};
    final list = <String>[];
    for (final d in _all) {
      final sp = d.specialty;
      if (sp != null && sp.isNotEmpty && seen.add(sp)) list.add(sp);
    }
    list.sort();
    return list;
  }

  List<Doctor> get _filtered {
    var list = _all;
    if (_selectedSpecialty != null) {
      list = list.where((d) => d.specialty == _selectedSpecialty).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((d) {
        return d.name.toLowerCase().contains(q) ||
            (d.specialty?.toLowerCase().contains(q) ?? false) ||
            (d.hospital?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return list;
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditDoctorScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _openDetail(Doctor d) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: d)),
    );
    if (changed == true) _load();
  }

  Future<void> _toggleFavorite(Doctor d) async {
    await _service.toggleFavorite(d);
    _load();
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
          _buildSpecialtyChips(c, s),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: DarkColors.green))
                : items.isEmpty
                    ? _EmptyState(
                        message: _query.isNotEmpty || _selectedSpecialty != null
                            ? 'No results found'
                            : s.noDoctors,
                      )
                    : RefreshIndicator(
                        color: DarkColors.green,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          itemCount:        items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _DoctorCard(
                            doctor:          items[i],
                            onTap:           () => _openDetail(items[i]),
                            onFavorite:      () => _toggleFavorite(items[i]),
                            delay:           i * 40,
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:       _openAdd,
        backgroundColor: DarkColors.green,
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
            color:      DarkColors.green.withAlpha(18),
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
            onTap: () => Navigator.of(context).pop(),
            child: _IconBtn(icon: Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s.myDoctors,
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
              color:        DarkColors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: DarkColors.green.withAlpha(60)),
            ),
            child: Text(
              '${_all.length}',
              style: GoogleFonts.poppins(
                fontSize:   12,
                fontWeight: FontWeight.w700,
                color:      DarkColors.green,
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
            hintText:  s.searchDoctors,
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
            prefixIcon: const Icon(Icons.search_rounded,
                color: DarkColors.green, size: 20),
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
    );
  }

  Widget _buildSpecialtyChips(ThemeColors c, S s) {
    final specs = _specialties;
    if (specs.isEmpty) return const SizedBox(height: 12);

    return SizedBox(
      height: 52,
      child: ListView(
        padding:       const EdgeInsets.fromLTRB(20, 12, 20, 0),
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label:    s.all,
            selected: _selectedSpecialty == null,
            onTap:    () => setState(() => _selectedSpecialty = null),
          ),
          ...specs.map((sp) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _FilterChip(
                  label:    sp,
                  selected: _selectedSpecialty == sp,
                  onTap: () => setState(() =>
                      _selectedSpecialty =
                          _selectedSpecialty == sp ? null : sp),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Doctor card ───────────────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final Doctor       doctor;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final int          delay;

  const _DoctorCard({
    required this.doctor,
    required this.onTap,
    required this.onFavorite,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = doctor;

    return Material(
      color:        c.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor:  DarkColors.green.withAlpha(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                color:      DarkColors.green.withAlpha(8),
                blurRadius: 12,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: DarkColors.green),
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
                                  d.displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize:   15,
                                    fontWeight: FontWeight.w700,
                                    color:      c.textPrimary,
                                  ),
                                ),
                              ),
                              if (d.specialty?.isNotEmpty == true)
                                _SpecialtyBadge(label: d.specialty!),
                            ],
                          ),
                          if (d.hospital?.isNotEmpty == true) ...[
                            const SizedBox(height: 3),
                            Text(
                              d.hospital!,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: c.textSec),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (d.phone?.isNotEmpty == true) ...[
                                Icon(Icons.phone_rounded,
                                    size: 12, color: c.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  d.phone!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: c.textMuted),
                                ),
                              ],
                              const Spacer(),
                              if (d.fee?.isNotEmpty == true) ...[
                                Icon(Icons.payments_outlined,
                                    size: 12, color: DarkColors.green),
                                const SizedBox(width: 3),
                                Text(
                                  d.fee!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: DarkColors.green,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onFavorite,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Icon(
                            d.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: d.isFavorite
                                ? DarkColors.red
                                : c.textMuted,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(Icons.chevron_right_rounded,
                            color: c.textMuted, size: 22),
                      ),
                    ],
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
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SpecialtyBadge extends StatelessWidget {
  final String label;
  const _SpecialtyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        DarkColors.green.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: DarkColors.green.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w700, color: DarkColors.green),
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
          color: selected ? DarkColors.green.withAlpha(25) : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? DarkColors.green : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize:   12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color:      selected ? DarkColors.green : c.textMuted,
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
              color:        DarkColors.green.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_rounded,
                color: DarkColors.green, size: 36),
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
