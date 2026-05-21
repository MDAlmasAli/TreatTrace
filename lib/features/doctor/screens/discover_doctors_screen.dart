// discover_doctors_screen.dart — Browse & save public doctor catalog.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../models/public_doctor.dart';
import '../services/public_doctor_service.dart';

class DiscoverDoctorsScreen extends StatefulWidget {
  const DiscoverDoctorsScreen({super.key});

  @override
  State<DiscoverDoctorsScreen> createState() => _DiscoverDoctorsScreenState();
}

class _DiscoverDoctorsScreenState extends State<DiscoverDoctorsScreen> {
  final _service    = PublicDoctorService();
  final _searchCtrl = TextEditingController();

  bool                  _loading   = true;
  List<PublicDoctor>    _all       = [];
  Set<String>           _savedIds  = {};
  final Set<String>     _saving    = {};
  String                _query     = '';
  String?               _selectedSpecialty;
  bool                  _anyAdded  = false;

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
      final results = await Future.wait([
        _service.fetchAll(),
        _service.fetchSavedSourceIds(),
      ]);
      _all      = results[0] as List<PublicDoctor>;
      _savedIds = results[1] as Set<String>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

  List<PublicDoctor> get _filtered {
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

  Future<void> _save(PublicDoctor pd) async {
    if (_savedIds.contains(pd.id) || _saving.contains(pd.id)) return;
    setState(() => _saving.add(pd.id));
    try {
      await _service.saveToMyDoctors(pd);
      if (mounted) {
        setState(() {
          _savedIds.add(pd.id);
          _saving.remove(pd.id);
          _anyAdded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${pd.displayName} added to My Doctors',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: const Color(0xFF136AFB),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving.remove(pd.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    final items = _filtered;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            _buildHeader(c),
            _buildSearch(c),
            _buildSpecialtyChips(c),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: c.accent))
                  : items.isEmpty
                      ? _EmptyState(c: c)
                      : RefreshIndicator(
                          color: c.accent,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                            itemCount:        items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final pd = items[i];
                              return _DoctorCatalogCard(
                                doctor:    pd,
                                saved:     _savedIds.contains(pd.id),
                                saving:    _saving.contains(pd.id),
                                onSave:    () => _save(pd),
                                delay:     i * 40,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c) {
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
            onTap: () => Navigator.of(context).pop(_anyAdded),
            child: _IconBtn(icon: Icons.arrow_back_rounded, c: c),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover Doctors',
                  style: GoogleFonts.poppins(
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      c.textPrimary,
                  ),
                ),
                Text(
                  'Search & add to My Doctors',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: c.textMuted),
                ),
              ],
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

  Widget _buildSearch(ThemeColors c) {
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
          style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
          decoration: InputDecoration(
            hintText:  'Search by name, specialty, hospital…',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
            prefixIcon: Icon(Icons.search_rounded, color: c.accent, size: 20),
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

  Widget _buildSpecialtyChips(ThemeColors c) {
    final specs = _specialties;
    if (specs.isEmpty) return const SizedBox(height: 12);

    return SizedBox(
      height: 52,
      child: ListView(
        padding:         const EdgeInsets.fromLTRB(20, 12, 20, 0),
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label:    'All',
            selected: _selectedSpecialty == null,
            onTap:    () => setState(() => _selectedSpecialty = null),
            c:        c,
          ),
          ...specs.map((sp) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _FilterChip(
                  label:    sp,
                  selected: _selectedSpecialty == sp,
                  onTap: () => setState(() =>
                      _selectedSpecialty =
                          _selectedSpecialty == sp ? null : sp),
                  c: c,
                ),
              )),
        ],
      ),
    );
  }
}

// ── Doctor catalog card ───────────────────────────────────────────────────────

class _DoctorCatalogCard extends StatelessWidget {
  final PublicDoctor pd;
  final bool         saved;
  final bool         saving;
  final VoidCallback onSave;
  final int          delay;

  const _DoctorCatalogCard({
    required PublicDoctor doctor,
    required this.saved,
    required this.saving,
    required this.onSave,
    required this.delay,
  }) : pd = doctor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color:        c.card,
      borderRadius: BorderRadius.circular(20),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DoctorAvatar(imageUrl: pd.imageUrl, name: pd.name, c: c),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pd.displayName,
                        style: GoogleFonts.poppins(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      c.textPrimary,
                        ),
                      ),
                      if (pd.specialty?.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        _SpecialtyBadge(label: pd.specialty!, c: c),
                      ],
                      if (pd.hospital?.isNotEmpty == true) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.local_hospital_rounded,
                                size: 12, color: c.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                pd.hospital!,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: c.textSec),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (pd.fee?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.payments_outlined,
                                size: 12, color: c.accent),
                            const SizedBox(width: 3),
                            Text(
                              pd.fee!,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: c.accent,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _SaveButton(
                  saved:  saved,
                  saving: saving,
                  onTap:  onSave,
                  c:      c,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideY(begin: 0.06);
  }
}

// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool         saved;
  final bool         saving;
  final VoidCallback onTap;
  final ThemeColors  c;

  const _SaveButton({
    required this.saved,
    required this.saving,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return SizedBox(
        width: 32, height: 32,
        child: CircularProgressIndicator(
            strokeWidth: 2.5, color: c.accent),
      );
    }
    if (saved) {
      return Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color:        const Color(0xFF22C55E).withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
              color: const Color(0xFF22C55E).withAlpha(80), width: 1.5),
        ),
        child: const Icon(Icons.check_rounded,
            color: Color(0xFF22C55E), size: 20),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color:        c.accent.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
              color: c.accent.withAlpha(80), width: 1.5),
        ),
        child: Icon(Icons.add_rounded, color: c.accent, size: 20),
      ),
    );
  }
}

// ── Doctor avatar with network image + initials fallback ──────────────────────

class _DoctorAvatar extends StatelessWidget {
  final String?     imageUrl;
  final String      name;
  final ThemeColors c;

  const _DoctorAvatar({
    required this.imageUrl,
    required this.name,
    required this.c,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64, height: 64,
        child: url != null
            ? Image.network(
                url,
                fit:          BoxFit.cover,
                errorBuilder: (_, _, _) => _InitialsBox(
                    initials: _initials, c: c),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _InitialsBox(initials: _initials, c: c);
                },
              )
            : _InitialsBox(initials: _initials, c: c),
      ),
    );
  }
}

class _InitialsBox extends StatelessWidget {
  final String      initials;
  final ThemeColors c;
  const _InitialsBox({required this.initials, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.accent.withAlpha(20),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize:   20,
          fontWeight: FontWeight.w700,
          color:      c.accent,
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SpecialtyBadge extends StatelessWidget {
  final String      label;
  final ThemeColors c;
  const _SpecialtyBadge({required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
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
  final ThemeColors  c;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
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
  final ThemeColors c;
  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
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
            child: Icon(Icons.search_rounded, color: c.accent, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'No doctors found',
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData    icon;
  final ThemeColors c;
  const _IconBtn({required this.icon, required this.c});

  @override
  Widget build(BuildContext context) {
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
