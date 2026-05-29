import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/doctor_verification_service.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../appointment/models/appointment.dart';
import '../../appointment/services/appointment_service.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/models/prescription_medicine.dart';
import '../../prescription/services/prescription_service.dart';
import '../services/doctor_patient_link_service.dart';

enum _UploadSource { gallery, camera, document }

class DoctorWritePrescriptionScreen extends StatefulWidget {
  final String       patientId;
  final String       patientName;
  final Prescription? existing;    // null = new, non-null = edit
  final String?      appointmentId; // if set, mark appointment completed on save

  const DoctorWritePrescriptionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.existing,
    this.appointmentId,
  });

  @override
  State<DoctorWritePrescriptionScreen> createState() =>
      _DoctorWritePrescriptionScreenState();
}

class _DoctorWritePrescriptionScreenState
    extends State<DoctorWritePrescriptionScreen> {
  final _svc         = PrescriptionService();
  final _dvrSvc      = DoctorVerificationService();
  final _apptSvc     = AppointmentService();
  final _linkSvc     = DoctorPatientLinkService();
  final _imagePicker = ImagePicker();

  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();

  DateTime         _date          = DateTime.now();
  final List<_MedEntry> _meds     = [];
  List<String>     _imageUrls     = [];
  bool _saving        = false;
  bool _uploadingImage = false;
  bool _loadingDoctor = true;

  // auto-filled from doctor_verifications
  String? _doctorName;
  String? _doctorSpecialty;
  String? _doctorHospital;
  String? _doctorPhone;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
    _prefill();
  }

  Future<void> _loadDoctorInfo() async {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    _doctorName = meta?['full_name'] as String?;

    final dv = await _dvrSvc.fetchMyVerification();
    if (mounted) {
      setState(() {
        _doctorSpecialty = dv?['specialty']    as String?;
        _doctorHospital  = dv?['hospital']     as String?;
        _doctorPhone     = dv?['phone']        as String?; // from profiles via join
        _loadingDoctor   = false;
      });
    }
  }

  void _prefill() {
    final rx = widget.existing;
    if (rx == null) {
      _addMed();
      return;
    }
    _date = rx.prescriptionDate;
    _diagnosisCtrl.text = rx.diagnosis ?? '';
    _notesCtrl.text     = rx.notes     ?? '';
    _imageUrls          = List.from(rx.imageUrls);
    if (rx.medicines.isEmpty) {
      _addMed();
    } else {
      for (final m in rx.medicines) {
        _meds.add(_MedEntry.fromMedicine(m));
      }
    }
  }

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    for (final m in _meds) { m.dispose(); }
    super.dispose();
  }

  void _addMed() => setState(() => _meds.insert(0, _MedEntry()));

  void _removeMed(int i) {
    _meds[i].dispose();
    setState(() => _meds.removeAt(i));
  }

  Future<void> _pickAttachment() async {
    final c = context.colors;
    final source = await showDialog<_UploadSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Add file',
            style: GoogleFonts.poppins(color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sourceTile(ctx, Icons.photo_library_rounded, 'Gallery', c.accent,  _UploadSource.gallery),
            _sourceTile(ctx, Icons.camera_alt_rounded,    'Camera',  c.green,   _UploadSource.camera),
            _sourceTile(ctx, Icons.insert_drive_file_rounded, 'Document (PDF/DOC)', Colors.orange, _UploadSource.document),
          ],
        ),
      ),
    );
    if (source == null) return;

    switch (source) {
      case _UploadSource.gallery:
        final picked = await _imagePicker.pickMultiImage(imageQuality: 80, maxWidth: 1024);
        if (picked.isEmpty) return;
        setState(() => _uploadingImage = true);
        try {
          for (final file in picked) {
            final url = await _svc.uploadImage(file);
            if (url != null && mounted) setState(() => _imageUrls.add(url));
          }
        } catch (e) {
          if (mounted) _snack('Upload failed: $e', isError: true);
        } finally {
          if (mounted) setState(() => _uploadingImage = false);
        }
      case _UploadSource.camera:
        XFile? picked;
        try {
          picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1024);
        } catch (e) {
          if (mounted) _snack('Could not open camera: $e', isError: true);
          return;
        }
        if (picked == null) return;
        setState(() => _uploadingImage = true);
        try {
          final url = await _svc.uploadImage(picked);
          if (url != null && mounted) setState(() => _imageUrls.add(url));
        } catch (e) {
          if (mounted) _snack('Upload failed: $e', isError: true);
        } finally {
          if (mounted) setState(() => _uploadingImage = false);
        }
      case _UploadSource.document:
        final result = await FilePicker.platform.pickFiles(
          type:              FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx'],
          allowMultiple:     true,
          withData:          true,
        );
        if (result == null || result.files.isEmpty) return;
        setState(() => _uploadingImage = true);
        try {
          for (final file in result.files) {
            final url = await _svc.uploadDocument(file);
            if (url != null && mounted) setState(() => _imageUrls.add(url));
          }
        } catch (e) {
          if (mounted) _snack('Upload failed: $e', isError: true);
        } finally {
          if (mounted) setState(() => _uploadingImage = false);
        }
    }
  }

  Widget _sourceTile(BuildContext ctx, IconData icon, String label, Color color, _UploadSource src) {
    final c = context.colors;
    return ListTile(
      leading:       Icon(icon, color: color),
      title:         Text(label, style: GoogleFonts.poppins(fontSize: 14, color: c.textPrimary)),
      onTap:         () => Navigator.of(ctx).pop(src),
      shape:         RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _docFileTile(String ext, ThemeColors c) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color:        Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf_rounded, color: Colors.orange, size: 32),
          const SizedBox(height: 4),
          Text(ext.toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange)),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: context.colors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final validMeds = _meds
        .where((m) => m.nameCtrl.text.trim().isNotEmpty)
        .toList();

    if (_diagnosisCtrl.text.trim().isEmpty && validMeds.isEmpty) {
      _snack('Add a diagnosis or at least one medicine.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final medicines = validMeds.map((e) => e.toMedicine()).toList();

      String? logPrescriptionId;

      if (_isEdit) {
        await _svc.updateForDoctor(
          prescriptionId: widget.existing!.id,
          diagnosis:      _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
          date:           _date,
          notes:          _notesCtrl.text.trim().isEmpty     ? null : _notesCtrl.text.trim(),
          imageUrls:      _imageUrls,
          medicines:      medicines,
        );
        logPrescriptionId = widget.existing!.id;
      } else {
        final doctorId = Supabase.instance.client.auth.currentUser?.id;
        final rx = Prescription(
          id:               '',
          userId:           widget.patientId,
          doctorName:       _doctorName,
          doctorSpecialty:  _doctorSpecialty,
          doctorHospital:   _doctorHospital,
          doctorPhone:      _doctorPhone,
          diagnosis:        _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
          prescriptionDate: _date,
          imageUrls:        _imageUrls,
          notes:            _notesCtrl.text.trim().isEmpty     ? null : _notesCtrl.text.trim(),
          createdAt:        DateTime.now(),
          writtenByDoctorId: doctorId,
        );
        final saved = await _svc.createForPatient(
          patientId:    widget.patientId,
          prescription: rx,
          medicines:    medicines,
        );
        logPrescriptionId = saved.id;
      }

      await _svc.logEdit(logPrescriptionId, action: _isEdit ? 'edited' : 'created');

      if (!_isEdit && widget.appointmentId != null) {
        try {
          await _apptSvc.updateStatus(
              widget.appointmentId!, AppointmentStatus.completed);
          await _linkSvc.autoLinkPatient(widget.patientId);
        } catch (_) {}
      }

      if (mounted) {
        _snack(_isEdit ? 'Prescription updated!' : 'Prescription saved!');
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) _snack('Failed to save. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: isError ? c.red : c.green,
      behavior:        SnackBarBehavior.floating,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final months  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${_date.day} ${months[_date.month-1]} ${_date.year}';

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [

                // ── Doctor info banner (read-only) ────────────────────────────
                _DoctorInfoBanner(
                  name:      _doctorName,
                  specialty: _doctorSpecialty,
                  hospital:  _doctorHospital,
                  loading:   _loadingDoctor,
                ).animate().fadeIn(delay: 40.ms),

                const SizedBox(height: 20),

                // ── Prescription details ──────────────────────────────────────
                _SectionLabel(label: 'Prescription Details', icon: Icons.description_rounded, color: c.green),
                const SizedBox(height: 12),
                _field(_diagnosisCtrl, c, 'Diagnosis / Chief Complaint', Icons.sick_rounded),
                const SizedBox(height: 10),

                // Date picker row
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color:        c.card,
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: c.accent, size: 18),
                        const SizedBox(width: 10),
                        Text('Prescription Date',
                            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
                        const Spacer(),
                        Text(dateStr,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_rounded, size: 14, color: c.textMuted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Medicines ─────────────────────────────────────────────────
                Row(
                  children: [
                    _SectionLabel(label: 'Medicines', icon: Icons.medication_rounded, color: c.accent),
                    const Spacer(),
                    GestureDetector(
                      onTap: _addMed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:        c.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 14, color: c.accent),
                            const SizedBox(width: 4),
                            Text('Add', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._meds.asMap().entries.map((e) => _MedicineCard(
                  key:       ValueKey(e.key),
                  entry:     e.value,
                  index:     e.key,
                  canRemove: _meds.length > 1,
                  onRemove:  () => _removeMed(e.key),
                ).animate().fadeIn(delay: Duration(milliseconds: 40 * e.key))),

                const SizedBox(height: 24),

                // ── Notes ─────────────────────────────────────────────────────
                _SectionLabel(label: 'Notes', icon: Icons.notes_rounded, color: c.textSec),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color:        c.card,
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(color: c.border),
                  ),
                  child: TextField(
                    controller: _notesCtrl,
                    maxLines:   4,
                    style:      GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText:       'Additional instructions for the patient...',
                      hintStyle:      GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                      border:         InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Prescription files ────────────────────────────────────────
                Row(
                  children: [
                    _SectionLabel(label: 'Prescription Files', icon: Icons.attach_file_rounded, color: c.textSec),
                    const Spacer(),
                    GestureDetector(
                      onTap: _uploadingImage ? null : _pickAttachment,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:        c.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _uploadingImage
                            ? SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(color: c.accent, strokeWidth: 2))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 14, color: c.accent),
                                  const SizedBox(width: 4),
                                  Text('Add', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_imageUrls.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:        c.card,
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file_rounded, color: c.textMuted, size: 20),
                        const SizedBox(width: 10),
                        Text('No files added', style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
                      ],
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _imageUrls.map((url) {
                      final isImg = isImageUrl(url);
                      return Stack(
                        children: [
                          isImg
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, st) => Container(
                                        width: 80, height: 80,
                                        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
                                        child: Icon(Icons.broken_image_rounded, color: c.textMuted),
                                      )),
                                )
                              : _docFileTile(extFromUrl(url), c),
                          Positioned(
                            top: 3, right: 3,
                            child: GestureDetector(
                              onTap: () => setState(() => _imageUrls.remove(url)),
                              child: Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(color: c.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 28),

                // ── Save button ───────────────────────────────────────────────
                SizedBox(
                  height: 52,
                  width:  double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_isEdit ? Icons.save_rounded : Icons.check_circle_rounded, size: 20),
                    label: Text(
                      _saving ? 'Saving...' : (_isEdit ? 'Update Prescription' : 'Save Prescription'),
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, ThemeColors c, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border),
      ),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
          prefixIcon: Icon(icon, color: c.textSec, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28),
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
                color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back_rounded, color: c.textSec, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEdit ? 'Edit Prescription' : 'Write Prescription',
                    style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text('For ${widget.patientName}',
                    style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Doctor info read-only banner ──────────────────────────────────────────────

class _DoctorInfoBanner extends StatelessWidget {
  final String? name;
  final String? specialty;
  final String? hospital;
  final bool    loading;
  const _DoctorInfoBanner({this.name, this.specialty, this.hospital, required this.loading});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        c.accent.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.accent.withAlpha(40)),
      ),
      child: loading
          ? Row(children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: c.accent, strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Loading doctor info...', style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
            ])
          : Row(
              children: [
                Icon(Icons.verified_user_rounded, color: c.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name != null ? 'Dr. $name' : 'Doctor',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      if (specialty != null || hospital != null)
                        Text(
                          [specialty, hospital].whereType<String>().join(' · '),
                          style: GoogleFonts.poppins(fontSize: 11, color: c.textSec),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Auto-filled', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: c.green)),
                ),
              ],
            ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  const _SectionLabel({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ── Medicine card ─────────────────────────────────────────────────────────────

class _MedicineCard extends StatefulWidget {
  final _MedEntry    entry;
  final int          index;
  final bool         canRemove;
  final VoidCallback onRemove;

  const _MedicineCard({
    super.key,
    required this.entry,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  State<_MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<_MedicineCard> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.entry;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header: Med N + remove
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: c.accent.withAlpha(15), borderRadius: BorderRadius.circular(20)),
                child: Text('Med ${widget.index + 1}',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: c.accent)),
              ),
              const Spacer(),
              if (widget.canRemove)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Icon(Icons.remove_circle_outline_rounded, color: c.red, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Name + dose
          Row(
            children: [
              Expanded(flex: 3, child: _inlineField(e.nameCtrl, c, 'Medicine name *')),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _inlineField(e.doseCtrl, c, 'Dose (e.g. 500mg)')),
            ],
          ),
          const SizedBox(height: 10),

          // Timing (full words)
          Row(
            children: [
              Text('Timing:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSec)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TimingChip(label: 'Morning',   active: e.morning,   onTap: () => setState(() => e.morning   = !e.morning)),
                    _TimingChip(label: 'Afternoon', active: e.afternoon, onTap: () => setState(() => e.afternoon = !e.afternoon)),
                    _TimingChip(label: 'Evening',   active: e.evening,   onTap: () => setState(() => e.evening   = !e.evening)),
                    _TimingChip(label: 'Night',     active: e.night,     onTap: () => setState(() => e.night     = !e.night)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Duration
          Row(
            children: [
              Text('Duration:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSec)),
              const Spacer(),
              SizedBox(
                width: 90,
                child: _inlineField(e.durationCtrl, c, 'Days', keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Meal timing
          Row(
            children: [
              Text('Meal:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSec)),
              const SizedBox(width: 8),
              _MealChip(
                label:  'Before',
                active: e.beforeMeal && !e.afterMeal,
                color:  c.amber,
                onTap:  () => setState(() { e.beforeMeal = true;  e.afterMeal = false; }),
              ),
              const SizedBox(width: 5),
              _MealChip(
                label:  'After',
                active: e.afterMeal && !e.beforeMeal,
                color:  c.green,
                onTap:  () => setState(() { e.afterMeal = true; e.beforeMeal = false; }),
              ),
              const SizedBox(width: 5),
              _MealChip(
                label:  'Any',
                active: !e.beforeMeal && !e.afterMeal,
                color:  c.textSec,
                onTap:  () => setState(() { e.beforeMeal = false; e.afterMeal = false; }),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Instructions
          _inlineField(e.instructionsCtrl, c, 'Special instructions (optional)'),
        ],
      ),
    );
  }

  Widget _inlineField(
    TextEditingController ctrl,
    ThemeColors c,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border),
      ),
      child: TextField(
        controller:   ctrl,
        keyboardType: keyboardType,
        style:        GoogleFonts.poppins(fontSize: 12, color: c.textPrimary),
        decoration: InputDecoration(
          hintText:       hint,
          hintStyle:      GoogleFonts.poppins(fontSize: 11, color: c.textMuted),
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          isDense:        true,
        ),
      ),
    );
  }
}

// ── Timing chip (Morning / Afternoon / Evening / Night) ──────────────────────

class _TimingChip extends StatelessWidget {
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  const _TimingChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: active ? c.accent : c.border),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: active ? Colors.white : c.textSec)),
      ),
    );
  }
}

// ── Meal chip (Before / After / Any) ─────────────────────────────────────────

class _MealChip extends StatelessWidget {
  final String       label;
  final bool         active;
  final Color        color;
  final VoidCallback onTap;
  const _MealChip({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color:        active ? color.withAlpha(30) : c.surface,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: active ? color : c.border),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: active ? color : c.textSec)),
      ),
    );
  }
}

// ── Mutable medicine entry for the form ──────────────────────────────────────

class _MedEntry {
  final nameCtrl         = TextEditingController();
  final doseCtrl         = TextEditingController();
  final durationCtrl     = TextEditingController();
  final instructionsCtrl = TextEditingController();
  bool morning    = false;
  bool afternoon  = false;
  bool evening    = false;
  bool night      = false;
  bool beforeMeal = false;
  bool afterMeal  = false;

  _MedEntry();

  factory _MedEntry.fromMedicine(PrescriptionMedicine m) {
    final e = _MedEntry();
    e.nameCtrl.text         = m.medicineName;
    e.doseCtrl.text         = m.dose ?? '';
    e.durationCtrl.text     = m.durationDays?.toString() ?? '';
    e.instructionsCtrl.text = m.instructions ?? '';
    e.morning    = m.morning;
    e.afternoon  = m.afternoon;
    e.evening    = m.evening;
    e.night      = m.night;
    e.beforeMeal = m.beforeMeal;
    e.afterMeal  = m.afterMeal;
    return e;
  }

  void dispose() {
    nameCtrl.dispose();
    doseCtrl.dispose();
    durationCtrl.dispose();
    instructionsCtrl.dispose();
  }

  PrescriptionMedicine toMedicine() => PrescriptionMedicine(
    id:             '',
    prescriptionId: '',
    medicineName:   nameCtrl.text.trim(),
    dose:           doseCtrl.text.trim().isEmpty         ? null : doseCtrl.text.trim(),
    morning:        morning,
    afternoon:      afternoon,
    evening:        evening,
    night:          night,
    beforeMeal:     beforeMeal,
    afterMeal:      afterMeal,
    durationDays:   int.tryParse(durationCtrl.text.trim()),
    instructions:   instructionsCtrl.text.trim().isEmpty ? null : instructionsCtrl.text.trim(),
  );
}
