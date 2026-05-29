import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../test_report/models/lab_report.dart';
import '../../test_report/services/lab_report_service.dart';

enum _UploadSource { gallery, camera, document }

class DoctorLabReportScreen extends StatefulWidget {
  final String     patientId;
  final String     patientName;
  final LabReport? existing; // null = new order, non-null = edit

  const DoctorLabReportScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.existing,
  });

  @override
  State<DoctorLabReportScreen> createState() => _DoctorLabReportScreenState();
}

class _DoctorLabReportScreenState extends State<DoctorLabReportScreen> {
  final _svc         = LabReportService();
  final _imagePicker = ImagePicker();

  final _notesCtrl    = TextEditingController();
  final _categoryCtrl = TextEditingController();

  DateTime?    _testDate;
  List<String> _imageUrls      = [];
  bool         _uploadingImage = false;
  bool         _saving         = false;
  bool         _loadingDoctor  = true;
  String?      _doctorName;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
    if (_isEdit) {
      final e = widget.existing!;
      _notesCtrl.text    = e.notes    ?? '';
      _categoryCtrl.text = e.category ?? e.testName;
      _testDate          = e.testDate;
      _imageUrls         = List.from(e.imageUrls);
    }
  }

  Future<void> _loadDoctorInfo() async {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    _doctorName = meta?['full_name'] as String?;
    if (mounted) setState(() => _loadingDoctor = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _testDate ?? DateTime.now(),
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: context.colors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _testDate = picked);
  }

  Future<void> _pickAttachment() async {
    final c = context.colors;
    final source = await showDialog<_UploadSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Add attachment',
            style: GoogleFonts.poppins(
                color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sourceTile(ctx, Icons.photo_library_rounded, c.accent, 'Gallery (Images)', _UploadSource.gallery),
            _sourceTile(ctx, Icons.camera_alt_rounded,    c.green,  'Camera',           _UploadSource.camera),
            _sourceTile(ctx, Icons.attach_file_rounded,   c.amber,  'Document (PDF, Word)', _UploadSource.document),
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
        final picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1024);
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

  Widget _sourceTile(BuildContext ctx, IconData icon, Color color, String label, _UploadSource val) {
    final c = ctx.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary)),
      onTap: () => Navigator.of(ctx).pop(val),
    );
  }

  Future<void> _save() async {
    final category = _categoryCtrl.text.trim();
    if (category.isEmpty) {
      _snack('Enter a test category.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final report = LabReport(
        id:                widget.existing?.id ?? '',
        userId:            widget.patientId,
        testName:          category,
        category:          category,
        testDate:          _testDate,
        doctorName:        _doctorName,
        notes:             _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        imageUrls:         _imageUrls,
        orderedByDoctorId: widget.existing?.orderedByDoctorId,
        createdAt:         widget.existing?.createdAt ?? DateTime.now(),
        updatedAt:         DateTime.now(),
      );

      if (_isEdit) {
        await _svc.updateForDoctor(report);
      } else {
        await _svc.createForPatient(patientId: widget.patientId, report: report);
      }

      if (mounted) {
        _snack(_isEdit ? 'Test report updated!' : 'Test report created!');
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
  void dispose() {
    _notesCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final months  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = _testDate != null
        ? '${_testDate!.day} ${months[_testDate!.month - 1]} ${_testDate!.year}'
        : 'Select date';

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

                // Doctor banner
                _DoctorBanner(
                  name:    _doctorName,
                  loading: _loadingDoctor,
                ).animate().fadeIn(delay: 40.ms),
                const SizedBox(height: 20),

                // Category (= test name)
                _field(_categoryCtrl, c, 'Test Category * (e.g. Blood Test, X-Ray)', Icons.category_rounded),
                const SizedBox(height: 10),

                // Date
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
                        Text('Test Date', style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
                        const Spacer(),
                        Text(dateStr,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: _testDate != null ? FontWeight.w600 : FontWeight.normal,
                                color: _testDate != null ? c.textPrimary : c.textMuted)),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_rounded, size: 14, color: c.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Notes
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
                      hintText:       'Clinical notes, expected results, special instructions...',
                      hintStyle:      GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                      prefixIcon:     const Padding(
                        padding: EdgeInsets.only(left: 14, top: 14),
                        child: Icon(Icons.notes_rounded, size: 18),
                      ),
                      prefixIconConstraints: const BoxConstraints(),
                      border:         InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Images
                _buildImageSection(c),
                const SizedBox(height: 28),

                // Save
                SizedBox(
                  height: 52,
                  width:  double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_isEdit ? Icons.save_rounded : Icons.add_circle_rounded, size: 20),
                    label: Text(
                      _saving ? 'Saving...' : (_isEdit ? 'Update Test Report' : 'Create Test Report'),
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          hintText:   hint,
          hintStyle:  GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
          prefixIcon: Icon(icon, color: c.textSec, size: 18),
          border:     InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _docFileTile(String ext, ThemeColors c) => Container(
    width: 80, height: 80,
    decoration: BoxDecoration(
      color:        c.amber.withAlpha(20),
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: c.amber.withAlpha(80)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.picture_as_pdf_rounded, color: c.amber, size: 28),
        const SizedBox(height: 4),
        Text(ext.toUpperCase(),
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: c.amber)),
      ],
    ),
  );

  Widget _buildImageSection(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_rounded, color: c.accent, size: 18),
              const SizedBox(width: 8),
              Text('Report Images',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: _uploadingImage ? null : _pickAttachment,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        c.accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _uploadingImage
                      ? SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(color: c.accent, strokeWidth: 2))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: c.accent, size: 16),
                            const SizedBox(width: 4),
                            Text('Add', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
                          ],
                        ),
                ),
              ),
            ],
          ),
          if (_imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                                errorBuilder: (_, _, _) => _docFileTile(extFromUrl(url), c)),
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
          ] else ...[
            const SizedBox(height: 8),
            Text('No files added', style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
          ],
        ],
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
                Text(_isEdit ? 'Edit Test Report' : 'Order Test',
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

class _DoctorBanner extends StatelessWidget {
  final String? name;
  final bool    loading;
  const _DoctorBanner({this.name, required this.loading});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.green.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.green.withAlpha(40)),
      ),
      child: loading
          ? Row(children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: c.green, strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Loading...', style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
            ])
          : Row(
              children: [
                Icon(Icons.science_rounded, color: c.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name != null ? 'Dr. $name' : 'Ordering Doctor',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.green.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: Text('Auto-filled', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: c.green)),
                ),
              ],
            ),
    );
  }
}
