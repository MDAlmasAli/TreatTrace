// doctors_screen.dart — Personal doctor book: list, search, specialty filter.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../search/screens/doctor_public_profile_screen.dart';
import '../../search/screens/global_search_screen.dart';
import '../models/doctor.dart';
import '../services/doctor_service.dart';
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

  Future<void> _openDoctorSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
    );
    _load();
  }

  Future<void> _openDetail(Doctor d) async {
    if (d.sourceId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DoctorPublicProfileScreen(
            doctorId:        d.sourceId!,
            initialName:     d.name,
            initialAvatarUrl: d.imageUrl,
          ),
        ),
      );
    } else {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: d)),
      );
      if (changed == true) _load();
    }
  }

  Future<void> _toggleFavorite(Doctor d) async {
    await _service.toggleFavorite(d);
    _load();
  }

  Future<bool?> _showDeleteConfirm(Doctor d) {
    final c = context.colors;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Doctor?',
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary),
        ),
        content: Text(
          '${d.displayName} will be removed from your list.',
          style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.red)),
          ),
        ],
      ),
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
          _buildSpecialtyChips(c, s),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: c.accent))
                : items.isEmpty
                    ? _EmptyState(
                        message: _query.isNotEmpty || _selectedSpecialty != null
                            ? 'No results found'
                            : s.noDoctors,
                        onAdd: _query.isNotEmpty || _selectedSpecialty != null
                            ? null
                            : _openDoctorSearch,
                      )
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          itemCount:        items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final doc = items[i];
                            return Dismissible(
                              key:        ValueKey(doc.id),
                              direction:  DismissDirection.endToStart,
                              confirmDismiss: (_) => _showDeleteConfirm(doc),
                              onDismissed: (_) async {
                                await _service.delete(doc.id);
                                _load();
                              },
                              background: const _DeleteBackground(),
                              child: _DoctorCard(
                                doctor:     doc,
                                onTap:      () => _openDetail(doc),
                                onFavorite: () => _toggleFavorite(doc),
                                delay:      i * 40,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       _openDoctorSearch,
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        icon:  const Icon(Icons.add_rounded, size: 22),
        label: Text('Add Doctor',
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700)),
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
              color:        c.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: c.accent.withAlpha(60)),
            ),
            child: Text(
              '${_all.length}',
              style: GoogleFonts.poppins(
                fontSize:   12,
                fontWeight: FontWeight.w700,
                color:      c.accent,
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
        splashColor:  c.accent.withAlpha(12),
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
                  Container(width: 4, color: c.accent),
                  // Avatar when doctor has a photo
                  if (d.imageUrl?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          d.imageUrl!,
                          width: 52, height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
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
                                    size: 12, color: c.accent),
                                const SizedBox(width: 3),
                                Text(
                                  d.fee!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: c.accent,
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
                                ? c.red
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
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.accent.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w700, color: c.accent),
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
          color: selected ? c.accent.withAlpha(25) : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize:   12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color:      selected ? c.accent : c.textMuted,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String        message;
  final VoidCallback? onAdd;
  const _EmptyState({required this.message, this.onAdd});

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
              color:        c.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.person_rounded,
                color: c.accent, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed:  onAdd,
              icon:       const Icon(Icons.add_rounded, size: 18),
              label:      Text('Add Doctor',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin:       const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color:        c.red,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      padding:   const EdgeInsets.only(right: 24),
      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
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
