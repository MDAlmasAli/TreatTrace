// add_edit_prescription_screen.dart
// Form to create or edit a prescription with doctor info, medicines, image upload.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/reminder_service.dart';
import '../models/prescription.dart';
import '../models/prescription_medicine.dart';
import '../services/prescription_service.dart';

class AddEditPrescriptionScreen extends StatefulWidget {
  final Prescription? existing;

  const AddEditPrescriptionScreen({super.key, this.existing});

  @override
  State<AddEditPrescriptionScreen> createState() =>
      _AddEditPrescriptionScreenState();
}

class _AddEditPrescriptionScreenState
    extends State<AddEditPrescriptionScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _prescService    = PrescriptionService();
  final _profileService  = ProfileService();
  final _reminderService = ReminderService();
  final _imagePicker     = ImagePicker();

  // Doctor fields
  final _doctorNameCtrl     = TextEditingController();
  final _specialtyCtrl      = TextEditingController();
  final _hospitalCtrl       = TextEditingController();
  final _doctorPhoneCtrl    = TextEditingController();
  final _diagnosisCtrl      = TextEditingController();
  final _notesCtrl          = TextEditingController();

  DateTime     _prescDate     = DateTime.now();
  List<String> _imageUrls     = [];
  bool         _uploadingImage = false;
  bool         _saving         = false;

  // Medicines list (mutable draft entries)
  final List<_MedicineDraft> _medicines = [];

  // Allergy conflicts detected
  List<String> _allergyConflicts = [];
  String?      _userAllergies;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadAllergies();
    if (_isEdit) _populateFromExisting();
  }

  Future<void> _loadAllergies() async {
    final hp = await _profileService.fetchHealthProfile();
    if (mounted) setState(() => _userAllergies = hp?.allergies);
  }

  void _populateFromExisting() {
    final p = widget.existing!;
    _doctorNameCtrl.text  = p.doctorName    ?? '';
    _specialtyCtrl.text   = p.doctorSpecialty ?? '';
    _hospitalCtrl.text    = p.doctorHospital  ?? '';
    _doctorPhoneCtrl.text = p.doctorPhone     ?? '';
    _diagnosisCtrl.text   = p.diagnosis       ?? '';
    _notesCtrl.text       = p.notes           ?? '';
    _prescDate            = p.prescriptionDate;
    _imageUrls            = List.from(p.imageUrls);
    _medicines.addAll(p.medicines.map(_MedicineDraft.fromModel));
  }

  @override
  void dispose() {
    _doctorNameCtrl.dispose();
    _specialtyCtrl.dispose();
    _hospitalCtrl.dispose();
    _doctorPhoneCtrl.dispose();
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    for (final m in _medicines) {
      m.dispose();
    }
    super.dispose();
  }

  void _checkAllergies() {
    final meds = _medicines.map((d) => d.toModel('')).toList();
    setState(() {
      _allergyConflicts =
          _prescService.checkAllergyConflicts(meds, _userAllergies);
    });
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _prescDate,
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:    DarkColors.purpleBright,
            onPrimary:  Colors.white,
            surface:    context.colors.card,
            onSurface:  context.colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _prescDate = picked);
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
      final url = await _prescService.uploadImage(picked);
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
            icon:     const Icon(Icons.photo_library_rounded,
                          color: DarkColors.purpleBright),
            label:    Text('Gallery',
                          style: GoogleFonts.poppins(
                              color: DarkColors.purpleBright)),
            onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          TextButton.icon(
            icon:     const Icon(Icons.camera_alt_rounded,
                          color: DarkColors.cyan),
            label:    Text('Camera',
                          style: GoogleFonts.poppins(color: DarkColors.cyan)),
            onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              'Add at least one medicine.',
              style: GoogleFonts.poppins())));
      return;
    }

    setState(() => _saving = true);
    try {
      final meds = _medicines
          .map((d) => d.toModel(_isEdit ? widget.existing!.id : ''))
          .toList();

      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          doctorName:       _doctorNameCtrl.text.trim().nullIfEmpty,
          doctorSpecialty:  _specialtyCtrl.text.trim().nullIfEmpty,
          doctorHospital:   _hospitalCtrl.text.trim().nullIfEmpty,
          doctorPhone:      _doctorPhoneCtrl.text.trim().nullIfEmpty,
          diagnosis:        _diagnosisCtrl.text.trim().nullIfEmpty,
          prescriptionDate: _prescDate,
          imageUrls:        _imageUrls,
          notes:            _notesCtrl.text.trim().nullIfEmpty,
        );
        await _prescService.updateHeader(updated);
        await _prescService.replaceMedicines(updated.id, meds);

        await _reminderService.cancelForPrescription(updated.id);
        final full = await _prescService.fetchOne(updated.id);
        if (full != null) await _reminderService.scheduleForPrescription(full);
      } else {
        // Build a placeholder Prescription for create (id assigned by DB)
        final draft = Prescription(
          id:               '',
          userId:           '',
          doctorName:       _doctorNameCtrl.text.trim().nullIfEmpty,
          doctorSpecialty:  _specialtyCtrl.text.trim().nullIfEmpty,
          doctorHospital:   _hospitalCtrl.text.trim().nullIfEmpty,
          doctorPhone:      _doctorPhoneCtrl.text.trim().nullIfEmpty,
          diagnosis:        _diagnosisCtrl.text.trim().nullIfEmpty,
          prescriptionDate: _prescDate,
          imageUrls:        _imageUrls,
          notes:            _notesCtrl.text.trim().nullIfEmpty,
          createdAt:        DateTime.now(),
        );
        final saved = await _prescService.create(
            prescription: draft, medicines: meds);
        await _reminderService.scheduleForPrescription(saved);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isEdit ? 'Prescription updated.' : S.of(context).reminderSet,
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
                    // Allergy warning banner
                    if (_allergyConflicts.isNotEmpty)
                      _AllergyBanner(medicines: _allergyConflicts)
                          .animate().fadeIn().slideY(begin: -0.1),

                    _SectionLabel(text: 'Doctor Info'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:  _doctorNameCtrl,
                        label: s.doctorName,
                        icon:  Icons.person_rounded,
                      ),
                      _Field(
                        ctrl:  _specialtyCtrl,
                        label: s.doctorSpecialty,
                        icon:  Icons.medical_services_rounded,
                      ),
                      _Field(
                        ctrl:  _hospitalCtrl,
                        label: s.hospitalClinic,
                        icon:  Icons.local_hospital_rounded,
                      ),
                      _Field(
                        ctrl:        _doctorPhoneCtrl,
                        label:       s.doctorPhone,
                        icon:        Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        isLast:      true,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _SectionLabel(text: 'Prescription Info'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:  _diagnosisCtrl,
                        label: s.diagnosis,
                        icon:  Icons.sick_rounded,
                      ),
                      // Date picker row
                      _DateRow(
                        date:    _prescDate,
                        onTap:   _pickDate,
                        label:   s.prescriptionDate,
                      ),
                      _Field(
                        ctrl:    _notesCtrl,
                        label:   s.notes,
                        icon:    Icons.notes_rounded,
                        maxLines: 3,
                        isLast:  true,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _SectionLabel(text: s.uploadImage),
                        const Spacer(),
                        if (_uploadingImage)
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: DarkColors.purpleBright,
                                strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MultiImageUploadCard(
                      imageUrls: _imageUrls,
                      uploading: _uploadingImage,
                      onAdd:     _pickImage,
                      onRemove:  (url) => setState(() => _imageUrls.remove(url)),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _SectionLabel(text: s.medicines),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            setState(() => _medicines.add(_MedicineDraft()));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:        DarkColors.purpleBright.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border:       Border.all(
                                  color: DarkColors.purpleBright.withAlpha(60)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded,
                                    size: 14, color: DarkColors.purpleBright),
                                const SizedBox(width: 4),
                                Text(s.addMedicine,
                                    style: GoogleFonts.poppins(
                                      fontSize:   12,
                                      fontWeight: FontWeight.w600,
                                      color:      DarkColors.purpleBright,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_medicines.isEmpty)
                      _EmptyMedicineHint()
                    else
                      ...List.generate(_medicines.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MedicineCard(
                            draft:    _medicines[i],
                            index:    i,
                            onRemove: () {
                              setState(() => _medicines.removeAt(i));
                              _checkAllergies();
                            },
                            onChanged: _checkAllergies,
                          ),
                        );
                      }),

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
            _isEdit ? s.editPrescription : s.addPrescription,
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
// _MedicineDraft — mutable draft for one medicine entry in the form
// ══════════════════════════════════════════════════════════════════════════════

class _MedicineDraft {
  final nameCtrl         = TextEditingController();
  final doseCtrl         = TextEditingController();
  final durationCtrl     = TextEditingController();
  final instructionsCtrl = TextEditingController();
  bool morning   = false;
  bool afternoon = false;
  bool evening   = false;
  bool night     = false;
  DateTime startDate = DateTime.now();

  _MedicineDraft();

  factory _MedicineDraft.fromModel(PrescriptionMedicine m) {
    final d = _MedicineDraft();
    d.nameCtrl.text         = m.medicineName;
    d.doseCtrl.text         = m.dose ?? '';
    d.durationCtrl.text     = m.durationDays?.toString() ?? '';
    d.instructionsCtrl.text = m.instructions ?? '';
    d.morning   = m.morning;
    d.afternoon = m.afternoon;
    d.evening   = m.evening;
    d.night     = m.night;
    d.startDate = m.startDate ?? DateTime.now();
    return d;
  }

  PrescriptionMedicine toModel(String prescriptionId) => PrescriptionMedicine(
        id:             '',
        prescriptionId: prescriptionId,
        medicineName:   nameCtrl.text.trim(),
        dose:           doseCtrl.text.trim().nullIfEmpty,
        morning:        morning,
        afternoon:      afternoon,
        evening:        evening,
        night:          night,
        durationDays:   int.tryParse(durationCtrl.text.trim()),
        instructions:   instructionsCtrl.text.trim().nullIfEmpty,
        startDate:      startDate,
      );

  void dispose() {
    nameCtrl.dispose();
    doseCtrl.dispose();
    durationCtrl.dispose();
    instructionsCtrl.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets
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
  final TextInputType         keyboardType;
  final int                   maxLines;
  final bool                  isLast;
  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines     = 1,
    this.isLast       = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller:   ctrl,
            keyboardType: keyboardType,
            maxLines:     maxLines,
            style:        GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
            validator: null,
            decoration: InputDecoration(
              labelText:      label,
              labelStyle:     GoogleFonts.poppins(
                  fontSize: 12, color: c.textMuted),
              prefixIcon:     Icon(icon, size: 18, color: DarkColors.purpleBright),
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 16, endIndent: 16,
            color: context.colors.border, thickness: 1),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  final String   label;

  const _DateRow({
    required this.date,
    required this.onTap,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 18, color: DarkColors.purpleBright),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: c.textMuted)),
                      Text(
                        '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/'
                        '${date.year}',
                        style: GoogleFonts.poppins(
                          fontSize:   13,
                          color:      c.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
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

// Multi-image grid: shows existing pages + an "Add Page" tile
class _MultiImageUploadCard extends StatelessWidget {
  final List<String>           imageUrls;
  final bool                   uploading;
  final VoidCallback           onAdd;
  final void Function(String)  onRemove;

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
      // Existing image thumbnails
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
                width:  90,
                height: 110,
                fit:    BoxFit.cover,
                errorBuilder: (ctx, err, st) => Container(
                  width: 90, height: 110,
                  decoration: BoxDecoration(
                    color:        c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: c.border),
                  ),
                  child: const Icon(Icons.broken_image_rounded,
                      color: DarkColors.purpleBright),
                ),
              ),
            ),
            // Page label
            Positioned(
              bottom: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color:        Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page ${idx + 1}',
                  style: GoogleFonts.poppins(
                      fontSize: 9, color: Colors.white),
                ),
              ),
            ),
            // Remove button
            Positioned(
              top: -6, right: -6,
              child: GestureDetector(
                onTap: () => onRemove(url),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color:  DarkColors.red,
                    shape:  BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        );
      }),

      // "Add page" tile
      GestureDetector(
        onTap: uploading ? null : onAdd,
        child: Container(
          width: 90, height: 110,
          decoration: BoxDecoration(
            color:        c.card,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(
                color: DarkColors.purpleBright.withAlpha(100),
                width: 1.5),
          ),
          child: uploading
              ? const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: DarkColors.purpleBright, strokeWidth: 2),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded,
                        color: DarkColors.purpleBright, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      imageUrls.isEmpty ? 'Add\nImage' : 'Add\nPage',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: DarkColors.purpleBright),
                    ),
                  ],
                ),
        ),
      ),
    ];

    return Wrap(
      spacing:    10,
      runSpacing: 10,
      children:   items,
    );
  }
}

class _MedicineCard extends StatefulWidget {
  final _MedicineDraft draft;
  final int            index;
  final VoidCallback   onRemove;
  final VoidCallback   onChanged;

  const _MedicineCard({
    required this.draft,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<_MedicineCard> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = widget.draft;

    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color:      DarkColors.cyan.withAlpha(8),
            blurRadius: 10,
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
              Container(width: 4, color: DarkColors.cyan),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Medicine ${widget.index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize:   13,
                              fontWeight: FontWeight.w700,
                              color:      DarkColors.cyan,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: widget.onRemove,
                            child: const Icon(Icons.remove_circle_rounded,
                                color: DarkColors.red, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Name
                      _MedField(
                        ctrl:      d.nameCtrl,
                        label:     'Medicine Name *',
                        icon:      Icons.medication_rounded,
                        required:  true,
                        onChanged: (_) => widget.onChanged(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MedField(
                              ctrl:  d.doseCtrl,
                              label: 'Dose',
                              icon:  Icons.scale_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MedField(
                              ctrl:        d.durationCtrl,
                              label:       'Days',
                              icon:        Icons.timer_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Frequency checkboxes
                      Text('Frequency',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: c.textMuted)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _FreqChip(
                            label:    'Morning',
                            selected: d.morning,
                            onTap: () => setState(() {
                              d.morning = !d.morning;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FreqChip(
                            label:    'Afternoon',
                            selected: d.afternoon,
                            onTap: () => setState(() {
                              d.afternoon = !d.afternoon;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FreqChip(
                            label:    'Evening',
                            selected: d.evening,
                            onTap: () => setState(() {
                              d.evening = !d.evening;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FreqChip(
                            label:    'Night',
                            selected: d.night,
                            onTap: () => setState(() {
                              d.night = !d.night;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MedField(
                        ctrl:  d.instructionsCtrl,
                        label: 'Instructions (e.g. after meal)',
                        icon:  Icons.info_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedField extends StatelessWidget {
  final TextEditingController ctrl;
  final String                label;
  final IconData              icon;
  final TextInputType         keyboardType;
  final bool                  required;
  final void Function(String)? onChanged;

  const _MedField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.required     = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
      controller:   ctrl,
      keyboardType: keyboardType,
      onChanged:    onChanged,
      style:        GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText:      label,
        labelStyle:     GoogleFonts.poppins(fontSize: 11, color: c.textMuted),
        prefixIcon:     Icon(icon, size: 16, color: DarkColors.cyan),
        filled:         true,
        fillColor:      c.surface,
        border:         OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: DarkColors.cyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: DarkColors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        isDense:        true,
      ),
    );
  }
}

class _FreqChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;

  const _FreqChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Flexible(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? DarkColors.cyan.withAlpha(25)
                : c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? DarkColors.cyan : c.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow:  TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize:   10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color:      selected ? DarkColors.cyan : c.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AllergyBanner extends StatelessWidget {
  final List<String> medicines;
  const _AllergyBanner({required this.medicines});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        DarkColors.red.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: DarkColors.red.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: DarkColors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).allergyWarning,
                  style: GoogleFonts.poppins(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      DarkColors.red,
                  ),
                ),
                Text(
                  medicines.join(', '),
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: DarkColors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMedicineHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(
            color: c.borderLight, width: 1.5, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          const Icon(Icons.medication_outlined,
              color: DarkColors.purpleBright, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap "+ Add Medicine" to add medicines',
              style: GoogleFonts.poppins(fontSize: 12, color: c.textSec),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool         saving;
  final VoidCallback onTap;

  const _SaveButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        width:   double.infinity,
        height:  52,
        decoration: BoxDecoration(
          gradient:     DarkColors.accentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      DarkColors.purpleBright.withAlpha(60),
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

// ── String extension ──────────────────────────────────────────────────────────

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
