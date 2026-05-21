// add_edit_lab_report_screen.dart
// Form to create or edit a lab/test report.
// Features: test info, category (preset chips + custom input), date picker,
// doctor/lab info, multi-image upload, notes, optional prescription link.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import '../models/lab_report.dart';
import '../services/lab_report_service.dart';

// Default category presets — user can also type a custom one.
const _kPresetCategories = [
  'Blood Test',
  'Urine Test',
  'X-Ray',
  'MRI / CT Scan',
  'Ultrasound',
  'ECG / EEG',
  'Pathology',
  'Other',
];

class AddEditLabReportScreen extends StatefulWidget {
  final LabReport? existing;

  const AddEditLabReportScreen({super.key, this.existing});

  @override
  State<AddEditLabReportScreen> createState() =>
      _AddEditLabReportScreenState();
}

class _AddEditLabReportScreenState extends State<AddEditLabReportScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _reportService = LabReportService();
  final _prescService  = PrescriptionService();
  final _imagePicker   = ImagePicker();

  final _testNameCtrl  = TextEditingController();
  final _doctorCtrl    = TextEditingController();
  final _hospitalCtrl  = TextEditingController();
  final _notesCtrl     = TextEditingController();

  String?      _category;
  DateTime?    _testDate;
  List<String> _imageUrls      = [];
  bool         _uploadingImage = false;
  bool         _saving         = false;

  // Prescription link
  List<Prescription> _prescriptions      = [];
  String?            _linkedPrescId;
  bool               _loadingPrescriptions = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
    if (_isEdit) _populate();
  }

  @override
  void dispose() {
    _testNameCtrl.dispose();
    _doctorCtrl.dispose();
    _hospitalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _loadingPrescriptions = true);
    try {
      _prescriptions = await _prescService.fetchAll();
    } finally {
      if (mounted) setState(() => _loadingPrescriptions = false);
    }
  }

  void _populate() {
    final r = widget.existing!;
    _testNameCtrl.text = r.testName;
    _doctorCtrl.text   = r.doctorName  ?? '';
    _hospitalCtrl.text = r.hospital    ?? '';
    _notesCtrl.text    = r.notes       ?? '';
    _category          = r.category;
    _testDate          = r.testDate;
    _imageUrls         = List.from(r.imageUrls);
    _linkedPrescId     = r.prescriptionId;
  }

  // ── Category picker ───────────────────────────────────────────────────────

  Future<void> _pickCustomCategory() async {
    final c = context.colors;
    final s = S.of(context);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(s.customCategory,
            style: GoogleFonts.poppins(
                color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: TextField(
          controller:    ctrl,
          autofocus:     true,
          textCapitalization: TextCapitalization.words,
          style:         GoogleFonts.poppins(
              fontSize: 13, color: c.textPrimary),
          decoration: InputDecoration(
            hintText:  s.enterCustomCategory,
            hintStyle: GoogleFonts.poppins(
                fontSize: 12, color: c.textMuted),
            filled:      true,
            fillColor:   c.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: c.cyan, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel,
                style: GoogleFonts.poppins(color: c.textSec)),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.of(ctx).pop(v.isEmpty ? null : v);
            },
            child: Text(s.confirm,
                style: GoogleFonts.poppins(
                    color: c.cyan,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _category = result);
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _testDate ?? DateTime.now(),
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   context.colors.cyan,
            onPrimary: Colors.white,
            surface:   context.colors.card,
            onSurface: context.colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _testDate = picked);
  }

  // ── Image upload ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final source = await _showSourceDialog();
    if (source == null) return;
    final picked = await _imagePicker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1024);
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await _reportService.uploadImage(picked);
      if (url != null && mounted) setState(() => _imageUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<ImageSource?> _showSourceDialog() {
    final c = context.colors;
    return showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Choose source',
            style: GoogleFonts.poppins(
                color: c.textPrimary, fontWeight: FontWeight.w600)),
        actions: [
          TextButton.icon(
            icon:  Icon(Icons.photo_library_rounded,
                color: c.cyan),
            label: Text('Gallery',
                style: GoogleFonts.poppins(color: c.cyan)),
            onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          TextButton.icon(
            icon:  Icon(Icons.camera_alt_rounded,
                color: c.purpleBright),
            label: Text('Camera',
                style: GoogleFonts.poppins(
                    color: c.purpleBright)),
            onPressed: () =>
                Navigator.of(ctx).pop(ImageSource.camera),
          ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final draft = LabReport(
        id:             _isEdit ? widget.existing!.id : '',
        userId:         '',
        testName:       _testNameCtrl.text.trim(),
        category:       _category?.isEmpty == true ? null : _category,
        testDate:       _testDate,
        doctorName:     _doctorCtrl.text.trim().nullIfEmpty,
        hospital:       _hospitalCtrl.text.trim().nullIfEmpty,
        imageUrls:      _imageUrls,
        notes:          _notesCtrl.text.trim().nullIfEmpty,
        prescriptionId: _linkedPrescId,
        createdAt:      DateTime.now(),
        updatedAt:      DateTime.now(),
      );

      if (_isEdit) {
        await _reportService.update(draft);
      } else {
        await _reportService.create(draft);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isEdit ? 'Report updated.' : 'Report saved.',
            style: GoogleFonts.poppins(),
          ),
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e',
                style: GoogleFonts.poppins())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                    // ── Test Info ─────────────────────────────────────────
                    _SectionLabel(text: 'Test Info'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:      _testNameCtrl,
                        label:     s.testName,
                        icon:      Icons.science_rounded,
                        required:  true,
                      ),
                      _DateRow(
                        date:  _testDate,
                        onTap: _pickDate,
                        label: s.testDate,
                        onClear: () => setState(() => _testDate = null),
                      ),
                    ]),

                    // ── Category ──────────────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: s.category),
                    const SizedBox(height: 12),
                    _CategoryPicker(
                      selected:       _category,
                      onSelect:       (cat) => setState(() => _category = cat),
                      onPickCustom:   _pickCustomCategory,
                    ),

                    // ── Doctor / Lab Info ─────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: 'Doctor / Lab Info'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:  _doctorCtrl,
                        label: s.doctorName,
                        icon:  Icons.person_rounded,
                      ),
                      _Field(
                        ctrl:   _hospitalCtrl,
                        label:  s.labHospital,
                        icon:   Icons.local_hospital_rounded,
                        isLast: true,
                      ),
                    ]),

                    // ── Images ────────────────────────────────────────────
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _SectionLabel(text: s.uploadImage),
                        const Spacer(),
                        if (_uploadingImage)
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: c.cyan,
                                strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MultiImageUploadCard(
                      imageUrls: _imageUrls,
                      uploading: _uploadingImage,
                      onAdd:     _pickImage,
                      onRemove:  (url) =>
                          setState(() => _imageUrls.remove(url)),
                    ),

                    // ── Notes ─────────────────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: s.notes),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:     _notesCtrl,
                        label:    s.notes,
                        icon:     Icons.notes_rounded,
                        maxLines: 4,
                        isLast:   true,
                      ),
                    ]),

                    // ── Prescription Link ─────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: s.linkedPrescription),
                    const SizedBox(height: 12),
                    _PrescriptionLinkPicker(
                      prescriptions: _prescriptions,
                      selectedId:    _linkedPrescId,
                      loading:       _loadingPrescriptions,
                      onChanged: (id) =>
                          setState(() => _linkedPrescId = id),
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
        color: c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
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
          Text(
            _isEdit ? s.editTestReport : s.addTestReport,
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

// ══════════════════════════════════════════════════════════════════════════════
// _CategoryPicker
// ══════════════════════════════════════════════════════════════════════════════

class _CategoryPicker extends StatelessWidget {
  final String?      selected;
  final void Function(String?) onSelect;
  final VoidCallback onPickCustom;

  const _CategoryPicker({
    required this.selected,
    required this.onSelect,
    required this.onPickCustom,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    // If current category is custom (not in presets), show it as an extra chip
    final customCat =
        (selected != null && !_kPresetCategories.contains(selected))
            ? selected
            : null;

    return Wrap(
      spacing:    8,
      runSpacing: 8,
      children: [
        // Show custom chip first if set
        if (customCat != null)
          _Chip(
            label:    customCat,
            selected: true,
            color:    c.purpleBright,
            onTap:    () => onSelect(null),
          ),
        // Preset chips
        ..._kPresetCategories.map((cat) => _Chip(
              label:    cat,
              selected: selected == cat,
              color:    c.cyan,
              onTap:    () => onSelect(selected == cat ? null : cat),
            )),
        // "+ Custom" chip
        _Chip(
          label:    '+ ${s.customCategory}',
          selected: false,
          color:    c.purpleBright,
          onTap:    onPickCustom,
          dashed:   true,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap;
  final bool         dashed;

  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(25) : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : dashed
                    ? color.withAlpha(120)
                    : c.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize:   12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color:      selected
                ? color
                : dashed
                    ? color
                    : c.textSec,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PrescriptionLinkPicker — dropdown to optionally link to a prescription
// ══════════════════════════════════════════════════════════════════════════════

class _PrescriptionLinkPicker extends StatelessWidget {
  final List<Prescription> prescriptions;
  final String?            selectedId;
  final bool               loading;
  final void Function(String?) onChanged;

  const _PrescriptionLinkPicker({
    required this.prescriptions,
    required this.selectedId,
    required this.loading,
    required this.onChanged,
  });

  String _prescLabel(Prescription p) {
    final doc  = p.doctorName?.isNotEmpty == true
        ? 'Dr. ${p.doctorName}'
        : 'Unknown Doctor';
    final date =
        '${p.prescriptionDate.day.toString().padLeft(2, '0')}/'
        '${p.prescriptionDate.month.toString().padLeft(2, '0')}/'
        '${p.prescriptionDate.year}';
    return '$doc — $date';
  }

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
                  child: CircularProgressIndicator(
                      color: c.cyan, strokeWidth: 2),
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value:      selectedId,
                isExpanded: true,
                dropdownColor: c.card,
                icon: Icon(Icons.expand_more_rounded,
                    color: c.textMuted, size: 20),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: c.textPrimary),
                hint: Text(
                  s.noLinkedPrescription,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: c.textMuted),
                ),
                onChanged: onChanged,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(s.noLinkedPrescription,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: c.textMuted)),
                  ),
                  ...prescriptions.map((p) => DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(
                          _prescLabel(p),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: c.textPrimary),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared form widgets (mirrors prescription screen style)
// ══════════════════════════════════════════════════════════════════════════════

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
  final bool                  required;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.isLast   = false,
    this.required = false,
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
            style: GoogleFonts.poppins(
                fontSize: 13, color: c.textPrimary),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'Required'
                    : null
                : null,
            decoration: InputDecoration(
              labelText:  label,
              labelStyle: GoogleFonts.poppins(
                  fontSize: 12, color: c.textMuted),
              prefixIcon: Icon(icon,
                  size: 18, color: c.cyan),
              border:         InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: c.border,
              thickness: 1),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime?    date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String       label;

  const _DateRow({
    required this.date,
    required this.onTap,
    required this.onClear,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Divider(height: 1, indent: 16, endIndent: 16,
            color: c.border, thickness: 1),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18, color: c.cyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: c.textMuted)),
                      Text(
                        date != null
                            ? '${date!.day.toString().padLeft(2, '0')}/'
                              '${date!.month.toString().padLeft(2, '0')}/'
                              '${date!.year}'
                            : '—',
                        style: GoogleFonts.poppins(
                          fontSize:   13,
                          color:      date != null
                              ? c.textPrimary
                              : c.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (date != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded,
                        size: 16, color: c.textMuted),
                  )
                else
                  Icon(Icons.edit_calendar_rounded,
                      size: 16, color: c.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MultiImageUploadCard extends StatelessWidget {
  final List<String>          imageUrls;
  final bool                  uploading;
  final VoidCallback          onAdd;
  final void Function(String) onRemove;

  const _MultiImageUploadCard({
    required this.imageUrls,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = <Widget>[
      ...imageUrls.asMap().entries.map((e) {
        final idx = e.key;
        final url = e.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                width: 90, height: 110,
                fit:   BoxFit.cover,
                errorBuilder: (ctx, err, st) => Container(
                  width: 90, height: 110,
                  decoration: BoxDecoration(
                    color:        c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: c.border),
                  ),
                  child: Icon(Icons.broken_image_rounded,
                      color: c.cyan),
                ),
              ),
            ),
            Positioned(
              bottom: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color:        Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${idx + 1}',
                  style: GoogleFonts.poppins(
                      fontSize: 9, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: -6, right: -6,
              child: GestureDetector(
                onTap: () => onRemove(url),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color:  c.red,
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        );
      }),
      GestureDetector(
        onTap: uploading ? null : onAdd,
        child: Container(
          width: 90, height: 110,
          decoration: BoxDecoration(
            color:        c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: c.cyan.withAlpha(100), width: 1.5),
          ),
          child: uploading
              ? Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: c.cyan, strokeWidth: 2),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: c.cyan, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      imageUrls.isEmpty ? 'Add\nImage' : 'Add\nMore',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: c.cyan),
                    ),
                  ],
                ),
        ),
      ),
    ];

    return Wrap(spacing: 10, runSpacing: 10, children: items);
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
          gradient:     c.accentGradient,
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
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
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

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
