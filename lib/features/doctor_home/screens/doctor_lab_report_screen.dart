import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/doctor_verification_service.dart';
import '../../test_report/models/lab_report.dart';
import '../../test_report/services/lab_report_service.dart';

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
  final _svc    = LabReportService();
  final _dvrSvc = DoctorVerificationService();

  final _testNameCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _categoryCtrl = TextEditingController();

  DateTime? _testDate;
  bool      _saving        = false;
  bool      _loadingDoctor = true;
  String?   _doctorName;
  String?   _doctorHospital;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
    if (_isEdit) {
      final e = widget.existing!;
      _testNameCtrl.text = e.testName;
      _notesCtrl.text    = e.notes    ?? '';
      _categoryCtrl.text = e.category ?? '';
      _testDate          = e.testDate;
    }
  }

  Future<void> _loadDoctorInfo() async {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    _doctorName = meta?['full_name'] as String?;
    final dv = await _dvrSvc.fetchMyVerification();
    if (mounted) {
      setState(() {
        _doctorHospital = dv?['hospital'] as String?;
        _loadingDoctor  = false;
      });
    }
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

  Future<void> _save() async {
    final name = _testNameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Enter a test name.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final report = LabReport(
        id:                widget.existing?.id ?? '',
        userId:            widget.patientId,
        testName:          name,
        category:          _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        testDate:          _testDate,
        doctorName:        _doctorName,
        hospital:          _doctorHospital,
        notes:             _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        imageUrls:         widget.existing?.imageUrls ?? [],
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
        _snack(_isEdit ? 'Lab order updated!' : 'Lab order created!');
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
    _testNameCtrl.dispose();
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
                  name:     _doctorName,
                  hospital: _doctorHospital,
                  loading:  _loadingDoctor,
                ).animate().fadeIn(delay: 40.ms),
                const SizedBox(height: 20),

                // Test name
                _field(_testNameCtrl, c, 'Test name *', Icons.science_rounded),
                const SizedBox(height: 10),

                // Category
                _field(_categoryCtrl, c, 'Category (e.g. Blood, Urine)', Icons.category_rounded),
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
                      _saving ? 'Saving...' : (_isEdit ? 'Update Lab Order' : 'Create Lab Order'),
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
                Text(_isEdit ? 'Edit Lab Order' : 'Order Lab Test',
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
  final String? hospital;
  final bool    loading;
  const _DoctorBanner({this.name, this.hospital, required this.loading});

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
                      Text(name != null ? 'Ordered by Dr. $name' : 'Ordering Doctor',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      if (hospital != null)
                        Text(hospital!, style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
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
