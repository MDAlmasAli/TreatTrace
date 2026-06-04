// doctor_filter_sheet.dart — Filter & sort UI + logic for the patient doctor search.
//
// The doctor maps come from DoctorPatientLinkService.fetchApprovedDoctors(), so
// filtering/sorting is done client-side over that small list.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';

enum DoctorSort { rating, feeLow, feeHigh, name, mostReviewed }

extension DoctorSortLabel on DoctorSort {
  String get label => switch (this) {
        DoctorSort.rating       => 'Rating (high → low)',
        DoctorSort.feeLow       => 'Fee (low → high)',
        DoctorSort.feeHigh      => 'Fee (high → low)',
        DoctorSort.name         => 'Name (A → Z)',
        DoctorSort.mostReviewed => 'Most reviewed',
      };
}

// 0 = Morning (≤12:00), 1 = Afternoon (12:00–17:00), 2 = Evening (≥17:00).
const _bandRanges = [
  (start: 5 * 60, end: 12 * 60),
  (start: 12 * 60, end: 17 * 60),
  (start: 17 * 60, end: 23 * 60 + 59),
];
const _bandLabels = ['Morning', 'Afternoon', 'Evening'];
const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class DoctorFilter {
  final DoctorSort sort;
  final Set<String> specialties;
  final Set<String> hospitals;
  final RangeValues? feeRange; // null = no fee constraint
  final Set<int> days;         // ISO dow 1..7
  final Set<int> timeBands;    // indexes into _bandRanges
  final double minRating;      // 0 = any

  const DoctorFilter({
    this.sort = DoctorSort.rating,
    this.specialties = const {},
    this.hospitals = const {},
    this.feeRange,
    this.days = const {},
    this.timeBands = const {},
    this.minRating = 0,
  });

  // Number of active filter groups (sort isn't counted — it's always set).
  int get activeCount =>
      (specialties.isEmpty ? 0 : 1) +
      (hospitals.isEmpty ? 0 : 1) +
      (feeRange == null ? 0 : 1) +
      (days.isEmpty ? 0 : 1) +
      (timeBands.isEmpty ? 0 : 1) +
      (minRating > 0 ? 1 : 0);

  DoctorFilter copyWith({
    DoctorSort? sort,
    Set<String>? specialties,
    Set<String>? hospitals,
    RangeValues? feeRange,
    bool clearFeeRange = false,
    Set<int>? days,
    Set<int>? timeBands,
    double? minRating,
  }) =>
      DoctorFilter(
        sort:        sort ?? this.sort,
        specialties: specialties ?? this.specialties,
        hospitals:   hospitals ?? this.hospitals,
        feeRange:    clearFeeRange ? null : (feeRange ?? this.feeRange),
        days:        days ?? this.days,
        timeBands:   timeBands ?? this.timeBands,
        minRating:   minRating ?? this.minRating,
      );
}

// ── Apply (filter + sort) ──────────────────────────────────────────────────

int? _toMinutes(dynamic hms) {
  if (hms is! String || hms.isEmpty) return null;
  final p = hms.split(':');
  final h = int.tryParse(p[0]) ?? 0;
  final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
  return h * 60 + m;
}

bool _matchesTime(Map<String, dynamic> d, Set<int> bands) {
  if (bands.isEmpty) return true;
  final start = _toMinutes(d['visiting_start_time']) ?? 0;
  final end = _toMinutes(d['visiting_end_time']) ?? (23 * 60 + 59);
  for (final b in bands) {
    final r = _bandRanges[b];
    if (start < r.end && end > r.start) return true; // window overlaps band
  }
  return false;
}

bool _matchesDays(Map<String, dynamic> d, Set<int> days) {
  if (days.isEmpty) return true;
  final raw = d['visiting_days'];
  if (raw is! List) return false;
  final docDays = raw.map((e) => (e as num).toInt()).toSet();
  return days.any(docDays.contains);
}

List<Map<String, dynamic>> applyDoctorFilter(
    List<Map<String, dynamic>> docs, DoctorFilter f) {
  final list = docs.where((d) {
    if (f.specialties.isNotEmpty &&
        !f.specialties.contains(d['specialty'] as String?)) {
      return false;
    }
    if (f.hospitals.isNotEmpty &&
        !f.hospitals.contains(d['hospital'] as String?)) {
      return false;
    }
    if (f.feeRange != null) {
      final fee = (d['visiting_fee'] as num?)?.toDouble();
      if (fee == null) return false;
      if (fee < f.feeRange!.start || fee > f.feeRange!.end) return false;
    }
    if (f.minRating > 0 &&
        ((d['rating_avg'] as num?)?.toDouble() ?? 0) < f.minRating) {
      return false;
    }
    if (!_matchesDays(d, f.days)) return false;
    if (!_matchesTime(d, f.timeBands)) return false;
    return true;
  }).toList();

  double rating(Map<String, dynamic> d) => (d['rating_avg'] as num?)?.toDouble() ?? 0;
  int count(Map<String, dynamic> d) => (d['rating_count'] as num?)?.toInt() ?? 0;
  int? fee(Map<String, dynamic> d) => (d['visiting_fee'] as num?)?.toInt();
  String name(Map<String, dynamic> d) =>
      (d['full_name'] as String? ?? '').toLowerCase();

  int feeCmp(Map<String, dynamic> a, Map<String, dynamic> b, {required bool asc}) {
    final fa = fee(a), fb = fee(b);
    if (fa == null && fb == null) return 0;
    if (fa == null) return 1; // nulls last
    if (fb == null) return -1;
    return asc ? fa.compareTo(fb) : fb.compareTo(fa);
  }

  switch (f.sort) {
    case DoctorSort.rating:
      list.sort((a, b) {
        final r = rating(b).compareTo(rating(a));
        if (r != 0) return r;
        final c = count(b).compareTo(count(a));
        return c != 0 ? c : name(a).compareTo(name(b));
      });
    case DoctorSort.mostReviewed:
      list.sort((a, b) {
        final c = count(b).compareTo(count(a));
        return c != 0 ? c : rating(b).compareTo(rating(a));
      });
    case DoctorSort.feeLow:
      list.sort((a, b) => feeCmp(a, b, asc: true));
    case DoctorSort.feeHigh:
      list.sort((a, b) => feeCmp(a, b, asc: false));
    case DoctorSort.name:
      list.sort((a, b) => name(a).compareTo(name(b)));
  }
  return list;
}

// ── Sheet ──────────────────────────────────────────────────────────────────

Future<DoctorFilter?> showDoctorFilterSheet(
  BuildContext context, {
  required DoctorFilter current,
  required List<String> specialties,
  required List<String> hospitals,
  required RangeValues? feeBounds, // null = no fee data
}) {
  return showModalBottomSheet<DoctorFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DoctorFilterSheet(
      current: current,
      specialties: specialties,
      hospitals: hospitals,
      feeBounds: feeBounds,
    ),
  );
}

class _DoctorFilterSheet extends StatefulWidget {
  final DoctorFilter current;
  final List<String> specialties;
  final List<String> hospitals;
  final RangeValues? feeBounds;

  const _DoctorFilterSheet({
    required this.current,
    required this.specialties,
    required this.hospitals,
    required this.feeBounds,
  });

  @override
  State<_DoctorFilterSheet> createState() => _DoctorFilterSheetState();
}

class _DoctorFilterSheetState extends State<_DoctorFilterSheet> {
  late DoctorSort _sort;
  late Set<String> _specialties;
  late Set<String> _hospitals;
  late RangeValues? _fee;
  late Set<int> _days;
  late Set<int> _bands;
  late double _minRating;
  String _hospitalQuery = '';

  @override
  void initState() {
    super.initState();
    final f = widget.current;
    _sort = f.sort;
    _specialties = {...f.specialties};
    _hospitals = {...f.hospitals};
    _fee = f.feeRange ?? widget.feeBounds;
    _days = {...f.days};
    _bands = {...f.timeBands};
    _minRating = f.minRating;
  }

  void _reset() => setState(() {
        _sort = DoctorSort.rating;
        _specialties = {};
        _hospitals = {};
        _fee = widget.feeBounds;
        _days = {};
        _bands = {};
        _minRating = 0;
      });

  void _apply() {
    final bounds = widget.feeBounds;
    final narrowed = bounds != null &&
        _fee != null &&
        (_fee!.start > bounds.start || _fee!.end < bounds.end);
    Navigator.of(context).pop(DoctorFilter(
      sort: _sort,
      specialties: _specialties,
      hospitals: _hospitals,
      feeRange: narrowed ? _fee : null,
      days: _days,
      timeBands: _bands,
      minRating: _minRating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bounds = widget.feeBounds;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text('Filter & Sort',
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary)),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: Text('Reset',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.accent)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  _section(c, 'Sort by'),
                  ...DoctorSort.values.map((s) => _radioRow(c, s)),
                  if (widget.specialties.isNotEmpty) ...[
                    _section(c, 'Specialty'),
                    _chipWrap(c, widget.specialties, _specialties),
                  ],
                  if (widget.hospitals.isNotEmpty) ...[
                    _section(c, 'Hospital'),
                    if (widget.hospitals.length > 6) _hospitalSearch(c),
                    _chipWrap(
                      c,
                      widget.hospitals
                          .where((h) => h
                              .toLowerCase()
                              .contains(_hospitalQuery.toLowerCase()))
                          .toList(),
                      _hospitals,
                    ),
                  ],
                  if (bounds != null && bounds.end > bounds.start) ...[
                    _section(c,
                        'Visiting fee  ·  BDT ${_fee!.start.round()}–${_fee!.end.round()}'),
                    RangeSlider(
                      values: _fee!,
                      min: bounds.start,
                      max: bounds.end,
                      divisions:
                          ((bounds.end - bounds.start) / 50).clamp(1, 100).round(),
                      activeColor: c.accent,
                      inactiveColor: c.border,
                      labels: RangeLabels(
                          _fee!.start.round().toString(),
                          _fee!.end.round().toString()),
                      onChanged: (v) => setState(() => _fee = v),
                    ),
                  ],
                  _section(c, 'Visiting day'),
                  _dayChips(c),
                  _section(c, 'Time of day'),
                  _bandChips(c),
                  _section(c, 'Minimum rating'),
                  _ratingChips(c),
                ],
              ),
            ),
            _applyBar(c),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeColors c, String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.textPrimary)),
      );

  Widget _radioRow(ThemeColors c, DoctorSort s) {
    final sel = _sort == s;
    return InkWell(
      onTap: () => setState(() => _sort = s),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(
              sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 20,
              color: sel ? c.accent : c.textMuted,
            ),
            const SizedBox(width: 10),
            Text(s.label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: c.textPrimary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _hospitalSearch(ThemeColors c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 40,
          child: TextField(
            onChanged: (v) => setState(() => _hospitalQuery = v),
            style: GoogleFonts.poppins(fontSize: 12, color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search hospitals…',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.textMuted),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.accent),
              ),
            ),
          ),
        ),
      );

  Widget _chipWrap(ThemeColors c, List<String> options, Set<String> selected) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((o) => _chip(c, o, selected.contains(o), () {
                  setState(() {
                    selected.contains(o) ? selected.remove(o) : selected.add(o);
                  });
                }))
            .toList(),
      );

  Widget _dayChips(ThemeColors c) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(7, (i) {
          final dow = i + 1; // ISO 1..7
          return _chip(c, _dayLabels[i], _days.contains(dow), () {
            setState(() {
              _days.contains(dow) ? _days.remove(dow) : _days.add(dow);
            });
          });
        }),
      );

  Widget _bandChips(ThemeColors c) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(3, (i) {
          return _chip(c, _bandLabels[i], _bands.contains(i), () {
            setState(() {
              _bands.contains(i) ? _bands.remove(i) : _bands.add(i);
            });
          });
        }),
      );

  Widget _ratingChips(ThemeColors c) {
    const opts = [(0.0, 'Any'), (3.0, '3★+'), (4.0, '4★+'), (4.5, '4.5★+')];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opts
          .map((o) => _chip(c, o.$2, _minRating == o.$1,
              () => setState(() => _minRating = o.$1)))
          .toList(),
    );
  }

  Widget _chip(ThemeColors c, String label, bool sel, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? c.accent.withAlpha(22) : c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? c.accent : c.border),
          ),
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? c.accent : c.textSec)),
        ),
      );

  Widget _applyBar(ThemeColors c) => Container(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Apply',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      );
}
