// doctor_filter_sheet.dart — Filter & sort UI + logic for the patient doctor search.
//
// The doctor maps come from DoctorPatientLinkService.fetchApprovedDoctors(), so
// filtering/sorting is done client-side over that small list.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../shared/widgets/searchable_picker_field.dart';

enum DoctorSort { rating, feeLow, feeHigh, name, mostReviewed, district }

extension DoctorSortLabel on DoctorSort {
  String get label => switch (this) {
        DoctorSort.rating       => 'Rating (high → low)',
        DoctorSort.feeLow       => 'Fee (low → high)',
        DoctorSort.feeHigh      => 'Fee (high → low)',
        DoctorSort.name         => 'Name (A → Z)',
        DoctorSort.mostReviewed => 'Most reviewed',
        DoctorSort.district     => 'District (A → Z)',
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
  final String? specialty;   // single selection from the DB-backed picker
  final String? hospital;
  final String? district;
  final RangeValues? feeRange; // null = no fee constraint
  final Set<int> days;         // ISO dow 1..7
  final Set<int> timeBands;    // indexes into _bandRanges
  final double minRating;      // 0 = any

  const DoctorFilter({
    this.sort = DoctorSort.rating,
    this.specialty,
    this.hospital,
    this.district,
    this.feeRange,
    this.days = const {},
    this.timeBands = const {},
    this.minRating = 0,
  });

  // Number of active filter groups (sort isn't counted — it's always set).
  int get activeCount =>
      (specialty == null ? 0 : 1) +
      (hospital == null ? 0 : 1) +
      (district == null ? 0 : 1) +
      (feeRange == null ? 0 : 1) +
      (days.isEmpty ? 0 : 1) +
      (timeBands.isEmpty ? 0 : 1) +
      (minRating > 0 ? 1 : 0);
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
    if (f.specialty != null && d['specialty'] != f.specialty) return false;
    if (f.hospital != null && d['hospital'] != f.hospital) return false;
    if (f.district != null && d['district'] != f.district) return false;
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
  String district(Map<String, dynamic> d) =>
      (d['district'] as String? ?? '').toLowerCase();

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
    case DoctorSort.district:
      list.sort((a, b) {
        final da = district(a), db = district(b);
        // Doctors without a district sort last.
        if (da.isEmpty != db.isEmpty) return da.isEmpty ? 1 : -1;
        final d = da.compareTo(db);
        return d != 0 ? d : name(a).compareTo(name(b));
      });
  }
  return list;
}

// ── Sheet ──────────────────────────────────────────────────────────────────

Future<DoctorFilter?> showDoctorFilterSheet(
  BuildContext context, {
  required DoctorFilter current,
  required List<String> specialties,
  required List<String> hospitals,
  required List<String> districts,
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
      districts: districts,
      feeBounds: feeBounds,
    ),
  );
}

class _DoctorFilterSheet extends StatefulWidget {
  final DoctorFilter current;
  final List<String> specialties;
  final List<String> hospitals;
  final List<String> districts;
  final RangeValues? feeBounds;

  const _DoctorFilterSheet({
    required this.current,
    required this.specialties,
    required this.hospitals,
    required this.districts,
    required this.feeBounds,
  });

  @override
  State<_DoctorFilterSheet> createState() => _DoctorFilterSheetState();
}

class _DoctorFilterSheetState extends State<_DoctorFilterSheet> {
  late DoctorSort _sort;
  String? _specialty;
  String? _hospital;
  String? _district;
  late RangeValues? _fee;
  late Set<int> _days;
  late Set<int> _bands;
  late double _minRating;

  @override
  void initState() {
    super.initState();
    final f = widget.current;
    _sort = f.sort;
    _specialty = f.specialty;
    _hospital = f.hospital;
    _district = f.district;
    _fee = f.feeRange ?? widget.feeBounds;
    _days = {...f.days};
    _bands = {...f.timeBands};
    _minRating = f.minRating;
  }

  void _reset() => setState(() {
        _sort = DoctorSort.rating;
        _specialty = null;
        _hospital = null;
        _district = null;
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
      specialty: _specialty,
      hospital: _hospital,
      district: _district,
      feeRange: narrowed ? _fee : null,
      days: _days,
      timeBands: _bands,
      minRating: _minRating,
    ));
  }

  // Opens the searchable picker for one filter category, backed by [options]
  // (the full DB-backed list). Selecting again the current value clears it.
  Future<String?> _pickOne({
    required String title,
    required String hint,
    required List<String> options,
    required String? current,
  }) async {
    final res = await showSearchablePicker(
      context: context,
      title: title,
      searchHint: hint,
      options: options.map((o) => PickerOption(id: o, label: o)).toList(),
      selectedId: current,
    );
    return res?.id;
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
                  _section(c, 'District'),
                  _filterPicker(
                    c,
                    label: 'District',
                    icon: Icons.location_city_rounded,
                    hint: 'Search & select a district',
                    value: _district,
                    onTap: () async {
                      final v = await _pickOne(
                        title: 'Select District',
                        hint: 'Search district…',
                        options: widget.districts,
                        current: _district,
                      );
                      if (v != null) setState(() => _district = v);
                    },
                    onClear: () => setState(() => _district = null),
                  ),
                  if (widget.hospitals.isNotEmpty) ...[
                    _section(c, 'Hospital'),
                    _filterPicker(
                      c,
                      label: 'Hospital',
                      icon: Icons.local_hospital_rounded,
                      hint: 'Search & select a hospital',
                      value: _hospital,
                      onTap: () async {
                        final v = await _pickOne(
                          title: 'Select Hospital',
                          hint: 'Search hospital…',
                          options: widget.hospitals,
                          current: _hospital,
                        );
                        if (v != null) setState(() => _hospital = v);
                      },
                      onClear: () => setState(() => _hospital = null),
                    ),
                  ],
                  if (widget.specialties.isNotEmpty) ...[
                    _section(c, 'Specialty'),
                    _filterPicker(
                      c,
                      label: 'Specialty',
                      icon: Icons.medical_services_rounded,
                      hint: 'Search & select a specialty',
                      value: _specialty,
                      onTap: () async {
                        final v = await _pickOne(
                          title: 'Select Specialty',
                          hint: 'Search specialty…',
                          options: widget.specialties,
                          current: _specialty,
                        );
                        if (v != null) setState(() => _specialty = v);
                      },
                      onClear: () => setState(() => _specialty = null),
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

  // A tap-to-search single-select field, with a Clear action once chosen.
  Widget _filterPicker(
    ThemeColors c, {
    required String label,
    required IconData icon,
    required String hint,
    required String? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchablePickerField(
          label: '',
          icon: icon,
          hint: hint,
          value: value,
          onTap: onTap,
        ),
        if (value != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, size: 14, color: c.textSec),
              label: Text('Clear',
                  style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28)),
            ),
          ),
      ],
    );
  }

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
