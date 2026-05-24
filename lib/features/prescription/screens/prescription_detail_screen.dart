// prescription_detail_screen.dart
// Full view of a prescription — medicines, doctor info, image, PDF export,
// allergy warning, edit/delete actions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/reminder_service.dart';
import '../models/prescription.dart';
import '../models/prescription_medicine.dart';
import '../services/prescription_service.dart';
import 'add_edit_prescription_screen.dart';

class PrescriptionDetailScreen extends StatefulWidget {
  final Prescription prescription;

  const PrescriptionDetailScreen({super.key, required this.prescription});

  @override
  State<PrescriptionDetailScreen> createState() =>
      _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState extends State<PrescriptionDetailScreen> {
  final _service        = PrescriptionService();
  final _profileService = ProfileService();
  final _reminders      = ReminderService();

  late Prescription _p;
  List<String>         _allergyConflicts = [];
  bool                 _loading          = false;
  Map<String, String?> _doctorProfile    = {};

  @override
  void initState() {
    super.initState();
    _p = widget.prescription;
    _checkAllergies();
    _fetchDoctorProfile();
  }

  Future<void> _checkAllergies() async {
    final hp = await _profileService.fetchHealthProfile();
    if (!mounted) return;
    final conflicts = _service.checkAllergyConflicts(_p.medicines, hp?.allergies);
    setState(() => _allergyConflicts = conflicts);
  }

  Future<void> _fetchDoctorProfile() async {
    final docId = _p.linkedDoctorId ?? _p.writtenByDoctorId;
    if (docId == null) return;
    final client = Supabase.instance.client;
    final results = await Future.wait([
      client.from('profiles').select('full_name, phone').eq('id', docId).maybeSingle(),
      client.from('doctor_verifications').select('specialty, hospital').eq('id', docId).eq('status', 'approved').maybeSingle(),
    ]);
    final prof  = results[0];
    final verif = results[1];
    if (mounted) {
      setState(() {
        _doctorProfile = {
          'name':      prof?['full_name']  as String?,
          'specialty': verif?['specialty'] as String?,
          'hospital':  verif?['hospital']  as String?,
          'phone':     prof?['phone']      as String?,
        };
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final fresh = await _service.fetchOne(_p.id);
      if (fresh != null && mounted) setState(() => _p = fresh);
      await Future.wait([_checkAllergies(), _fetchDoctorProfile()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Resolved doctor display values — prefer fetched profile, fall back to stored text.
  String? get _docName     => _doctorProfile['name']      ?? _p.doctorName;
  String? get _docSpecialty => _doctorProfile['specialty'] ?? _p.doctorSpecialty;
  String? get _docHospital  => _doctorProfile['hospital']  ?? _p.doctorHospital;
  String? get _docPhone     => _doctorProfile['phone']     ?? _p.doctorPhone;

  // ── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => AddEditPrescriptionScreen(existing: _p)),
    );
    if (changed == true) {
      await _refresh();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final c = context.colors;
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(s.deletePrescription,
            style: GoogleFonts.poppins(
                color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(s.deleteConfirm,
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel,
                style: GoogleFonts.poppins(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    color: c.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await _reminders.cancelForPrescription(_p.id);
      await _service.delete(_p.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  // ── PDF Export ────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final p   = _p;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin:     const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color:        PdfColor.fromHex('#7C3AED'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    // Logo badge
                    pw.Container(
                      width: 36, height: 36,
                      decoration: pw.BoxDecoration(
                        color:        PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'TT',
                          style: pw.TextStyle(
                            color:      PdfColor.fromHex('#7C3AED'),
                            fontSize:   14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TreatTrace',
                          style: pw.TextStyle(
                            color:      PdfColors.white,
                            fontSize:   16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Medical Prescription',
                          style: pw.TextStyle(
                              color: PdfColor.fromHex('#FFFFFFB0'), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date',
                      style: pw.TextStyle(
                          color: PdfColor.fromHex('#FFFFFFB0'), fontSize: 9),
                    ),
                    pw.Text(
                      _fmtDate(p.prescriptionDate),
                      style: pw.TextStyle(
                        color:      PdfColors.white,
                        fontSize:   12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Doctor section
          _pdfSection('Doctor Information', [
            if (_docName?.isNotEmpty == true)
              _pdfRow('Name', 'Dr. $_docName'),
            if (_docSpecialty?.isNotEmpty == true)
              _pdfRow('Specialty', _docSpecialty!),
            if (_docHospital?.isNotEmpty == true)
              _pdfRow('Hospital / Clinic', _docHospital!),
            if (_docPhone?.isNotEmpty == true)
              _pdfRow('Phone', _docPhone!),
          ]),

          if (p.diagnosis?.isNotEmpty == true) ...[
            pw.SizedBox(height: 12),
            _pdfSection('Diagnosis', [_pdfRow('', p.diagnosis!)]),
          ],

          pw.SizedBox(height: 12),
          _pdfSection('Medicines', [
            for (final m in p.medicines) ...[
              pw.Container(
                margin:  const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border:       pw.Border.all(
                      color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(m.medicineName,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    if (m.dose?.isNotEmpty == true)
                      pw.Text('Dose: ${m.dose}',
                          style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Frequency: ${m.frequencyDisplay}',
                        style: const pw.TextStyle(fontSize: 10)),
                    if (m.durationDays != null)
                      pw.Text('Duration: ${m.durationDays} days',
                          style: const pw.TextStyle(fontSize: 10)),
                    if (m.instructions?.isNotEmpty == true)
                      pw.Text('Note: ${m.instructions}',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ]),

          if (p.notes?.isNotEmpty == true) ...[
            pw.SizedBox(height: 12),
            _pdfSection('Notes', [_pdfRow('', p.notes!)]),
          ],

          pw.Spacer(),
          pw.Divider(),
          pw.Text('Generated by TreatTrace',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey)),
        ],
      ),
    ));

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes:    bytes,
      filename: 'prescription_${p.id.substring(0, 8)}.pdf',
    );
  }

  pw.Widget _pdfSection(String title, List<pw.Widget> children) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize:   13,
                color:      PdfColor.fromHex('#7C3AED'))),
        pw.SizedBox(height: 6),
        ...children,
      ]);

  pw.Widget _pdfRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            if (label.isNotEmpty)
              pw.TextSpan(
                  text: '$label: ',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.TextSpan(
                text: value,
                style: const pw.TextStyle(fontSize: 11)),
          ]),
        ),
      );

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
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: c.purpleBright))
                : SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Allergy warning
                        if (_allergyConflicts.isNotEmpty)
                          _AllergyCard(medicines: _allergyConflicts)
                              .animate()
                              .fadeIn()
                              .slideY(begin: -0.1),

                        // Refill banner
                        if (_p.needsRefillSoon)
                          _RefillCard(p: _p)
                              .animate()
                              .fadeIn(delay: 40.ms),

                        // Doctor info
                        _SectionLabel(text: 'Doctor Information'),
                        const SizedBox(height: 10),
                        _DoctorCard(
                          name:      _docName,
                          specialty: _docSpecialty,
                          hospital:  _docHospital,
                          phone:     _docPhone,
                        )
                            .animate()
                            .fadeIn(delay: 60.ms)
                            .slideY(begin: 0.06),

                        // Diagnosis + Notes
                        if (_p.diagnosis?.isNotEmpty == true ||
                            _p.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 20),
                          _SectionLabel(text: 'Details'),
                          const SizedBox(height: 10),
                          _DetailsCard(p: _p)
                              .animate()
                              .fadeIn(delay: 100.ms)
                              .slideY(begin: 0.06),
                        ],

                        // Prescription images (multi-page gallery)
                        if (_p.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _SectionLabel(text: s.viewImage),
                          const SizedBox(height: 10),
                          _PrescriptionGallery(urls: _p.imageUrls)
                              .animate()
                              .fadeIn(delay: 120.ms),
                        ],

                        // Medicines
                        const SizedBox(height: 20),
                        _SectionLabel(
                            text: '${s.medicines} (${_p.medicines.length})'),
                        const SizedBox(height: 10),
                        if (_p.medicines.isEmpty)
                          _EmptyMeds()
                        else
                          ...List.generate(
                            _p.medicines.length,
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MedicineTile(
                                medicine: _p.medicines[i],
                                isConflict: _allergyConflicts.contains(
                                    _p.medicines[i].medicineName),
                              ).animate()
                                  .fadeIn(delay: Duration(milliseconds: 140 + i * 40))
                                  .slideY(begin: 0.06),
                            ),
                          ),

                        const SizedBox(height: 28),
                        _ActionRow(
                          onEdit:   _edit,
                          onDelete: _delete,
                          onPdf:    _exportPdf,
                        ),
                      ],
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
            child: _SmallIconBtn(icon: Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _docName?.isNotEmpty == true
                      ? 'Dr. $_docName'
                      : s.prescription,
                  style: GoogleFonts.poppins(
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                    color:      c.textPrimary,
                  ),
                ),
                Text(
                  _fmtDate(_p.prescriptionDate),
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: c.textSec),
                ),
              ],
            ),
          ),
          _SmallIconBtn(
            icon:  Icons.share_rounded,
            color: c.cyan,
            onTap: _exportPdf,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
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

class _DoctorCard extends StatelessWidget {
  final String? name;
  final String? specialty;
  final String? hospital;
  final String? phone;

  const _DoctorCard({
    this.name,
    this.specialty,
    this.hospital,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _InfoCard(
      accentColor: c.cyan,
      child: Column(
        children: [
          _InfoRow(
            icon:      Icons.person_rounded,
            iconColor: c.cyan,
            label:     'Doctor',
            value:     name?.isNotEmpty == true ? 'Dr. $name' : '—',
          ),
          if (specialty?.isNotEmpty == true)
            _InfoRow(
              icon:      Icons.medical_services_rounded,
              iconColor: c.purpleBright,
              label:     'Specialty',
              value:     specialty!,
            ),
          if (hospital?.isNotEmpty == true)
            _InfoRow(
              icon:      Icons.local_hospital_rounded,
              iconColor: c.green,
              label:     'Hospital',
              value:     hospital!,
            ),
          if (phone?.isNotEmpty == true)
            _InfoRow(
              icon:      Icons.phone_rounded,
              iconColor: c.amber,
              label:     'Phone',
              value:     phone!,
              isLast:    true,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Prescription p;
  const _DetailsCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _InfoCard(
      accentColor: c.purpleBright,
      child: Column(
        children: [
          if (p.diagnosis?.isNotEmpty == true)
            _InfoRow(
              icon:      Icons.sick_rounded,
              iconColor: c.red,
              label:     'Diagnosis',
              value:     p.diagnosis!,
              isLast:    p.notes?.isEmpty != false,
            ),
          if (p.notes?.isNotEmpty == true)
            _InfoRow(
              icon:      Icons.notes_rounded,
              iconColor: c.amber,
              label:     'Notes',
              value:     p.notes!,
              isLast:    true,
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final Color  accentColor;

  const _InfoCard({required this.child, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color:      accentColor.withAlpha(10),
            blurRadius: 12,
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
              Container(width: 4, color: accentColor),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  final bool     isLast;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: c.textMuted)),
                    Text(value,
                        style: GoogleFonts.poppins(
                          fontSize:   13,
                          fontWeight: FontWeight.w500,
                          color:      c.textPrimary,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, endIndent: 16,
              color: context.colors.border, thickness: 1),
      ],
    );
  }
}

class _MedicineTile extends StatelessWidget {
  final PrescriptionMedicine medicine;
  final bool                 isConflict;

  const _MedicineTile({
    required this.medicine,
    required this.isConflict,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final m      = medicine;
    final accent = isConflict
        ? c.red
        : (m.isActive ? c.green : c.textMuted);

    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: c.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.medicineName,
                              style: GoogleFonts.poppins(
                                fontSize:   14,
                                fontWeight: FontWeight.w700,
                                color: isConflict
                                    ? c.red
                                    : c.textPrimary,
                              ),
                            ),
                          ),
                          if (isConflict)
                            Icon(Icons.warning_rounded,
                                size: 16, color: c.red),
                          if (m.needsRefillSoon && !isConflict)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:        c.amber.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Refill soon',
                                  style: GoogleFonts.poppins(
                                    fontSize:   9,
                                    fontWeight: FontWeight.w700,
                                    color:      c.amber,
                                  )),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (m.dose?.isNotEmpty == true)
                            _Chip(
                              label: m.dose!,
                              icon:  Icons.scale_rounded,
                              color: c.cyan,
                            ),
                          _Chip(
                            label: m.frequencyDisplay,
                            icon:  Icons.access_time_rounded,
                            color: c.purpleBright,
                          ),
                          if (m.durationDays != null)
                            _Chip(
                              label: '${m.durationDays} days',
                              icon:  Icons.timer_rounded,
                              color: c.green,
                            ),
                        ],
                      ),
                      if (m.instructions?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          m.instructions!,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: c.textSec),
                        ),
                      ],
                      if (m.endDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          m.isActive
                              ? 'Active until ${_fmtDate(m.endDate!)}'
                              : 'Expired ${_fmtDate(m.endDate!)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color:    m.isActive
                                ? c.green
                                : c.textMuted,
                          ),
                        ),
                      ],
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

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Chip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;

  const _Chip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                fontSize:   10,
                fontWeight: FontWeight.w600,
                color:      color,
              )),
        ],
      ),
    );
  }
}

class _PrescriptionGallery extends StatefulWidget {
  final List<String> urls;
  const _PrescriptionGallery({required this.urls});

  @override
  State<_PrescriptionGallery> createState() => _PrescriptionGalleryState();
}

class _PrescriptionGalleryState extends State<_PrescriptionGallery> {
  int _current = 0;
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _showFullScreen(context, i),
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: c.card,
                    child: Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: c.purpleBright, size: 36),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.urls.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.urls.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:   const EdgeInsets.symmetric(horizontal: 3),
                width:    active ? 18 : 6,
                height:   6,
                decoration: BoxDecoration(
                  color: active
                      ? c.purpleBright
                      : c.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Page ${_current + 1} of ${widget.urls.length}',
            style: GoogleFonts.poppins(fontSize: 11, color: c.textMuted),
          ),
        ],
      ],
    );
  }

  void _showFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenGallery(
        urls:         widget.urls,
        initialIndex: initialIndex,
      ),
    ));
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> urls;
  final int          initialIndex;
  const _FullScreenGallery({required this.urls, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.urls.length > 1
            ? Text(
                'Page ${_current + 1} / ${widget.urls.length}',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.white70),
              )
            : null,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => Center(
          child: InteractiveViewer(
            child: Image.network(widget.urls[i]),
          ),
        ),
      ),
    );
  }
}

class _AllergyCard extends StatelessWidget {
  final List<String> medicines;
  const _AllergyCard({required this.medicines});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        c.red.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.red.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded,
              color: c.red, size: 22),
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
                    color:      c.red,
                  ),
                ),
                Text(
                  'Conflict: ${medicines.join(', ')}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: c.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefillCard extends StatelessWidget {
  final Prescription p;
  const _RefillCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        c.amber.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.amber.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.refresh_rounded,
              color: c.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.of(context).refillSoon,
              style: GoogleFonts.poppins(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      c.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPdf;

  const _ActionRow({
    required this.onEdit,
    required this.onDelete,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            label: 'Edit',
            icon:  Icons.edit_rounded,
            color: c.purpleBright,
            onTap: onEdit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            label: s.exportPdf,
            icon:  Icons.picture_as_pdf_rounded,
            color: c.cyan,
            onTap: onPdf,
          ),
        ),
        const SizedBox(width: 10),
        _ActionBtn(
          label: 'Delete',
          icon:  Icons.delete_rounded,
          color: c.red,
          onTap: onDelete,
          square: true,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final bool         square;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.square = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height:  50,
        width:   square ? 50 : null,
        padding: square ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:        color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: color.withAlpha(60)),
        ),
        child: square
            ? Center(child: Icon(icon, color: color, size: 20))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.poppins(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      color,
                      )),
                ],
              ),
      ),
    );
  }
}

class _EmptyMeds extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.borderLight),
      ),
      child: Row(
        children: [
          Icon(Icons.medication_outlined,
              color: c.purpleBright, size: 20),
          const SizedBox(width: 10),
          Text('No medicines recorded',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: c.textSec)),
        ],
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData     icon;
  final Color?       color;
  final VoidCallback? onTap;

  const _SmallIconBtn({required this.icon, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color:        c.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: c.border, width: 1),
        ),
        child: Icon(icon, color: color ?? c.textSec, size: 20),
      ),
    );
  }
}
