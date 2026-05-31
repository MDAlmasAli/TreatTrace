// add_edit_appointment_screen.dart — Form to create or edit an appointment.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../doctor/models/doctor.dart';
import '../../doctor/services/doctor_service.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import '../../test_report/models/test_report.dart';
import '../../test_report/services/test_report_service.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';

class AddEditAppointmentScreen extends StatefulWidget {
  final Appointment? existing;
  final Doctor? preselectedDoctor;
  final String? prefilledDoctorName;
  final String? prefilledDoctorHospital;
  final String? prefilledDoctorUserId;

  const AddEditAppointmentScreen({
    super.key,
    this.existing,
    this.preselectedDoctor,
    this.prefilledDoctorName,
    this.prefilledDoctorHospital,
    this.prefilledDoctorUserId,
  });

  @override
  State<AddEditAppointmentScreen> createState() =>
      _AddEditAppointmentScreenState();
}

class _AddEditAppointmentScreenState extends State<AddEditAppointmentScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _apptSvc   = AppointmentService();
  final _doctorSvc = DoctorService();
  final _prescSvc  = PrescriptionService();
  final _reportSvc = TestReportService();

  final _reasonCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();

  // Doctor selection
  List<Doctor> _doctors       = [];
  Doctor?      _selectedDoctor;
  bool         _loadingDoctors = false;

  // Date
  DateTime? _date;

  // Prescription links
  List<Prescription> _prescriptions       = [];
  List<String>       _linkedPrescIds      = [];
  bool               _loadingPrescriptions = false;

  // Test report links
  List<TestReport> _testReports         = [];
  List<String>     _linkedTestReportIds = [];
  bool             _loadingTestReports  = false;

  // Status (edit only)
  AppointmentStatus _status = AppointmentStatus.scheduled;

  bool    _saving = false;
  String? _fixedDoctorName;
  String? _fixedDoctorHospital;
  String? _fixedDoctorUserId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _fixedDoctorName     = widget.prefilledDoctorName?.trim().nullIfEmpty;
    _fixedDoctorHospital = widget.prefilledDoctorHospital?.trim().nullIfEmpty;
    _fixedDoctorUserId   = widget.prefilledDoctorUserId?.trim().nullIfEmpty;
    _loadDoctors();
    _loadPrescriptions();
    _loadTestReports();
    if (_isEdit) _populate();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _loadingDoctors = true);
    try {
      _doctors = await _doctorSvc.fetchAll();
      if (widget.preselectedDoctor != null && !_isEdit) {
        final match = _doctors.where((d) => d.id == widget.preselectedDoctor!.id).toList();
        if (match.isNotEmpty) {
          _selectedDoctor = match.first;
        } else {
          _fixedDoctorName     ??= widget.preselectedDoctor!.name.trim().nullIfEmpty;
          _fixedDoctorHospital ??= widget.preselectedDoctor!.hospital?.trim().nullIfEmpty;
        }
      }
    } finally {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _loadingPrescriptions = true);
    try {
      _prescriptions = await _prescSvc.fetchAll();
    } finally {
      if (mounted) setState(() => _loadingPrescriptions = false);
    }
  }

  Future<void> _loadTestReports() async {
    setState(() => _loadingTestReports = true);
    try {
      _testReports = await _reportSvc.fetchAll();
    } finally {
      if (mounted) setState(() => _loadingTestReports = false);
    }
  }

  void _populate() {
    final a = widget.existing!;
    _reasonCtrl.text      = a.visitReason ?? '';
    _notesCtrl.text       = a.notes       ?? '';
    _date                 = a.appointmentDate;
    _status               = a.status;
    _linkedPrescIds       = List.from(a.prescriptionIds);
    _linkedTestReportIds  = List.from(a.testReportIds);
    if (a.doctorId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final match = _doctors.where((d) => d.id == a.doctorId).toList();
        if (match.isNotEmpty) setState(() => _selectedDoctor = match.first);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date ?? DateTime.now(),
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   context.colors.amber,
            onPrimary: Colors.white,
            surface:   context.colors.card,
            onSurface: context.colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date.', style: GoogleFonts.poppins())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final useFixedDoctor = (_fixedDoctorName?.isNotEmpty ?? false);
      final doctorName = useFixedDoctor
          ? _fixedDoctorName!
          : (_selectedDoctor?.name ??
                (_isEdit ? widget.existing!.doctorNameSnapshot : 'Unknown'));

      final draft = Appointment(
        id:                 _isEdit ? widget.existing!.id : '',
        userId:             '',
        doctorId:           useFixedDoctor ? null : _selectedDoctor?.id,
        doctorNameSnapshot: doctorName,
        appointmentDate:    _date!,
        appointmentTime:    null,
        visitReason:        _reasonCtrl.text.trim().nullIfEmpty,
        status:             _status,
        notes:              _notesCtrl.text.trim().nullIfEmpty,
        prescriptionIds:    _linkedPrescIds,
        testReportIds:      _linkedTestReportIds,
        createdAt:          DateTime.now(),
        updatedAt:          DateTime.now(),
      );

      if (_isEdit) {
        await _apptSvc.update(draft);
      } else {
        await _apptSvc.create(draft, doctorUserId: useFixedDoctor ? _fixedDoctorUserId : null);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isEdit ? 'Appointment updated.' : 'Appointment saved.',
            style: GoogleFonts.poppins(),
          ),
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _prescLabel(Prescription p) {
    final doc = p.doctorName?.isNotEmpty == true
        ? 'Dr. ${p.doctorName}'
        : 'Prescription';
    final diag    = p.diagnosis?.trim();
    final dateStr = _fmtDate(p.prescriptionDate);
    // Lead with the diagnosis so it's clear what condition the Rx is for.
    if (diag != null && diag.isNotEmpty) {
      return '$diag · $doc · $dateStr';
    }
    return '$doc · $dateStr';
  }

  String _prescSearch(Prescription p) =>
      '${p.diagnosis ?? ''} ${p.doctorName ?? ''} ${_fmtDate(p.prescriptionDate)}'
          .toLowerCase();

  String _reportLabel(TestReport r) {
    final d       = r.testDate ?? r.createdAt;
    final dateStr = _fmtDate(d);
    final doc     = r.doctorName?.trim();
    if (doc != null && doc.isNotEmpty) {
      return '${r.testName} · Dr. $doc · $dateStr';
    }
    return '${r.testName} · $dateStr';
  }

  String _reportSearch(TestReport r) {
    final d = r.testDate ?? r.createdAt;
    return '${r.testName} ${r.doctorName ?? ''} ${_fmtDate(d)}'.toLowerCase();
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

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c, s),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Doctor ────────────────────────────────────────────
                    _SectionLabel(text: s.selectDoctor),
                    const SizedBox(height: 12),
                    if (_fixedDoctorName != null)
                      _FixedDoctorCard(name: _fixedDoctorName!, hospital: _fixedDoctorHospital)
                    else
                      _DoctorPicker(
                        doctors:   _doctors,
                        selected:  _selectedDoctor,
                        loading:   _loadingDoctors,
                        onChanged: (d) => setState(() => _selectedDoctor = d),
                      ),

                    // ── Date ─────────────────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: 'Date'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _DateRow(
                        date:    _date,
                        label:   s.appointmentDate,
                        onTap:   _pickDate,
                        onClear: () => setState(() => _date = null),
                        isLast:  true,
                      ),
                    ]),

                    // ── Visit info ────────────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: 'Visit Info'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:   _reasonCtrl,
                        label:  s.visitReason,
                        icon:   Icons.medical_services_rounded,
                      ),
                      _Field(
                        ctrl:     _notesCtrl,
                        label:    s.notes,
                        icon:     Icons.notes_rounded,
                        maxLines: 3,
                        isLast:   true,
                      ),
                    ]),

                    // ── Status (edit only) ────────────────────────────────
                    if (_isEdit) ...[
                      const SizedBox(height: 24),
                      _SectionLabel(text: 'Status'),
                      const SizedBox(height: 12),
                      _StatusPicker(
                        selected:  _status,
                        onChanged: (st) => setState(() => _status = st),
                      ),
                    ],

                    // ── Prescriptions ─────────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: s.linkedPrescription),
                    const SizedBox(height: 12),
                    _MultiItemPicker(
                      items: _prescriptions
                          .map((p) => _LinkItem(
                                id:         p.id,
                                label:      _prescLabel(p),
                                searchText: _prescSearch(p),
                              ))
                          .toList(),
                      selectedIds: _linkedPrescIds,
                      loading:     _loadingPrescriptions,
                      icon:        Icons.receipt_long_rounded,
                      color:       c.purpleBright,
                      addLabel:    'Add Prescription',
                      emptyHint:   'No prescriptions yet',
                      onChanged:   (ids) => setState(() => _linkedPrescIds = ids),
                    ),

                    // ── Test Reports ──────────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: 'Linked Test Reports'),
                    const SizedBox(height: 12),
                    _MultiItemPicker(
                      items: _testReports
                          .map((r) => _LinkItem(
                                id:         r.id,
                                label:      _reportLabel(r),
                                searchText: _reportSearch(r),
                              ))
                          .toList(),
                      selectedIds: _linkedTestReportIds,
                      loading:     _loadingTestReports,
                      icon:        Icons.science_rounded,
                      color:       c.cyan,
                      addLabel:    'Add Test Report',
                      emptyHint:   'No test reports yet',
                      onChanged:   (ids) => setState(() => _linkedTestReportIds = ids),
                    ),

                    const SizedBox(height: 32),
                    _SaveButton(saving: _saving, onTap: _save),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeColors c, S s) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        color:        c.card,
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
            child: _IconBtn(icon: Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 14),
          Text(
            _isEdit ? s.editAppointment : s.addAppointment,
            style: GoogleFonts.poppins(
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      c.textPrimary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Link item data class ──────────────────────────────────────────────────────

class _LinkItem {
  final String id;
  final String label;
  final String searchText; // lowercase, concatenated fields for filtering
  const _LinkItem({required this.id, required this.label, this.searchText = ''});
}

// ── Multi item picker ─────────────────────────────────────────────────────────

class _MultiItemPicker extends StatelessWidget {
  final List<_LinkItem>          items;
  final List<String>             selectedIds;
  final bool                     loading;
  final IconData                 icon;
  final Color                    color;
  final String                   addLabel;
  final String                   emptyHint;
  final void Function(List<String>) onChanged;

  const _MultiItemPicker({
    required this.items,
    required this.selectedIds,
    required this.loading,
    required this.icon,
    required this.color,
    required this.addLabel,
    required this.emptyHint,
    required this.onChanged,
  });

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context:       context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _ItemPickerSheet(
        items:       items,
        selectedIds: selectedIds,
        icon:        icon,
        color:       color,
        onChanged:   onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c            = context.colors;
    final selected     = items.where((i) => selectedIds.contains(i.id)).toList();
    final hasSelection = selected.isNotEmpty;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSelection ? color.withAlpha(80) : c.border,
        ),
      ),
      child: loading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: color, strokeWidth: 2),
                ),
              ),
            )
          : Wrap(
              spacing:    8,
              runSpacing: 8,
              children: [
                ...selected.map((item) => _SelectedChip(
                  label: item.label,
                  color: color,
                  onRemove: () {
                    onChanged(List<String>.from(selectedIds)..remove(item.id));
                  },
                )),
                _AddChipButton(
                  label:    addLabel,
                  color:    color,
                  icon:     icon,
                  disabled: items.isEmpty,
                  hint:     items.isEmpty ? emptyHint : null,
                  onTap:    items.isEmpty ? null : () => _openSheet(context),
                ),
              ],
            ),
    );
  }
}

// ── Selected chip ─────────────────────────────────────────────────────────────

class _SelectedChip extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback onRemove;

  const _SelectedChip({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      color,
              ),
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width:  16,
              height: 16,
              decoration: BoxDecoration(
                color:  color.withAlpha(40),
                shape:  BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add chip button ───────────────────────────────────────────────────────────

class _AddChipButton extends StatelessWidget {
  final String       label;
  final Color        color;
  final IconData     icon;
  final bool         disabled;
  final String?      hint;
  final VoidCallback? onTap;

  const _AddChipButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.disabled,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (disabled && hint != null) {
      return Text(
        hint!,
        style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        disabled ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:     disabled ? c.border : color.withAlpha(140),
            width:     1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: disabled ? c.textMuted : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      disabled ? c.textMuted : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item picker bottom sheet ──────────────────────────────────────────────────

class _ItemPickerSheet extends StatefulWidget {
  final List<_LinkItem>          items;
  final List<String>             selectedIds;
  final IconData                 icon;
  final Color                    color;
  final void Function(List<String>) onChanged;

  const _ItemPickerSheet({
    required this.items,
    required this.selectedIds,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  late List<String> _selected;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedIds);
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
    widget.onChanged(List.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final botPad  = MediaQuery.of(context).padding.bottom;
    final items   = _query.isEmpty
        ? widget.items
        : widget.items.where((i) => i.searchText.contains(_query)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // handle
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(
            children: [
              Text(
                'Select items',
                style: GoogleFonts.poppins(
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                  color:      c.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                    color:      widget.color,
                  ),
                ),
              ),
            ],
          ),
        ),
        // search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color:        c.surface,
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: c.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              style:      GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText:  'Search by doctor, name or date…',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: widget.color, size: 18),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: Icon(Icons.close_rounded, color: c.textMuted, size: 18),
                      )
                    : null,
                border:         InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        Divider(height: 1, color: c.border),
        // item list
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'No matches found',
                    style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                  ),
                )
              : ListView.separated(
            shrinkWrap:  true,
            itemCount:   items.length,
            separatorBuilder: (_, _) => Divider(
              height: 1, indent: 16, endIndent: 16, color: c.border,
            ),
            itemBuilder: (_, i) {
              final item     = items[i];
              final isChosen = _selected.contains(item.id);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color:        widget.color.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 16, color: widget.color),
                ),
                title: Text(
                  item.label,
                  style: GoogleFonts.poppins(
                    fontSize:   12,
                    fontWeight: isChosen ? FontWeight.w600 : FontWeight.w400,
                    color:      isChosen ? widget.color : c.textPrimary,
                  ),
                  maxLines:  2,
                  overflow:  TextOverflow.ellipsis,
                ),
                trailing: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width:  22, height: 22,
                  decoration: BoxDecoration(
                    color:        isChosen ? widget.color : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border:       Border.all(
                      color: isChosen ? widget.color : c.border,
                      width: 1.5,
                    ),
                  ),
                  child: isChosen
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                onTap: () => _toggle(item.id),
              );
            },
          ),
        ),
        SizedBox(height: botPad + 16),
      ],
    );
  }
}

// ── Doctor picker ─────────────────────────────────────────────────────────────

class _DoctorPicker extends StatelessWidget {
  final List<Doctor> doctors;
  final Doctor?      selected;
  final bool         loading;
  final void Function(Doctor?) onChanged;

  const _DoctorPicker({
    required this.doctors,
    required this.selected,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: c.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: loading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: c.amber, strokeWidth: 2),
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<Doctor?>(
                value:         selected,
                isExpanded:    true,
                dropdownColor: c.card,
                icon: Icon(Icons.expand_more_rounded, color: c.textMuted, size: 20),
                style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                hint: Text(s.noLinkedDoctor,
                    style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted)),
                onChanged: onChanged,
                items: [
                  DropdownMenuItem<Doctor?>(
                    value: null,
                    child: Text(s.noLinkedDoctor,
                        style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted)),
                  ),
                  ...doctors.map((d) => DropdownMenuItem<Doctor?>(
                        value: d,
                        child: Text(
                          d.displayName +
                              (d.specialty?.isNotEmpty == true ? ' · ${d.specialty}' : ''),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}

class _FixedDoctorCard extends StatelessWidget {
  final String  name;
  final String? hospital;

  const _FixedDoctorCard({required this.name, this.hospital});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: c.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.medical_services_rounded, size: 18, color: c.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. $name',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                if (hospital?.isNotEmpty == true)
                  Text(hospital!,
                      style: GoogleFonts.poppins(fontSize: 11, color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status picker ─────────────────────────────────────────────────────────────

class _StatusPicker extends StatelessWidget {
  final AppointmentStatus                selected;
  final void Function(AppointmentStatus) onChanged;

  const _StatusPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.colors;
    final options = [
      (AppointmentStatus.scheduled, s.statusScheduled, c.amber),
      (AppointmentStatus.completed, s.statusCompleted, c.green),
      (AppointmentStatus.cancelled, s.statusCancelled, c.red),
    ];

    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final (status, label, color) = opt;
        final isSelected = selected == status;
        return GestureDetector(
          onTap: () => onChanged(status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:        isSelected ? color.withAlpha(25) : context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : context.colors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color:      isSelected ? color : context.colors.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared form widgets ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize:   16,
          fontWeight: FontWeight.w700,
          color:      context.colors.textPrimary,
        ),
      );
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.border, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String                label;
  final IconData              icon;
  final int                   maxLines;
  final bool                  isLast;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.isLast   = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller: ctrl,
            maxLines:   maxLines,
            style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
            decoration: InputDecoration(
              labelText:      label,
              labelStyle:     GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
              prefixIcon:     Icon(icon, size: 18, color: c.amber),
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, endIndent: 16, color: c.border, thickness: 1),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime?    date;
  final String       label;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool         isLast;

  const _DateRow({
    required this.date,
    required this.label,
    required this.onTap,
    required this.onClear,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: c.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
                      Text(
                        date != null
                            ? '${date!.day.toString().padLeft(2, '0')}/'
                                  '${date!.month.toString().padLeft(2, '0')}/'
                                  '${date!.year}'
                            : '—',
                        style: GoogleFonts.poppins(
                          fontSize:   13,
                          color:      date != null ? c.textPrimary : c.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (date != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                  )
                else
                  Icon(Icons.edit_calendar_rounded, size: 16, color: c.textMuted),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, endIndent: 16, color: c.border, thickness: 1),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool         saving;
  final VoidCallback onTap;

  const _SaveButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        width:  double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color:        c.amber,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withAlpha(8),
              blurRadius: 16,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: saving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(
                  S.of(context).saveChanges,
                  style: GoogleFonts.poppins(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                  ),
                ),
        ),
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
      width:  40,
      height: 40,
      decoration: BoxDecoration(
        color:        c.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: c.border, width: 1),
      ),
      child: Icon(icon, color: c.textSec, size: 20),
    );
  }
}

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
