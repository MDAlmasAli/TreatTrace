import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import 'doctor_write_prescription_screen.dart';

class DoctorPrescriptionViewScreen extends StatefulWidget {
  final Prescription rx;
  final bool         canEdit;
  final String       patientId;
  final String       patientName;

  const DoctorPrescriptionViewScreen({
    super.key,
    required this.rx,
    required this.canEdit,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DoctorPrescriptionViewScreen> createState() =>
      _DoctorPrescriptionViewScreenState();
}

class _DoctorPrescriptionViewScreenState
    extends State<DoctorPrescriptionViewScreen> {
  final _svc = PrescriptionService();

  List<Map<String, dynamic>> _logs     = [];
  bool                       _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await _svc.fetchEditLogs(widget.rx.id);
      if (mounted) setState(() { _logs = logs; _loadingLogs = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  Future<void> _goEdit() async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorWritePrescriptionScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
        existing:    widget.rx,
      ),
    ));
    if (result == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final rx     = widget.rx;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

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

                // ── Doctor info ──────────────────────────────────────────────
                if (rx.doctorName != null || rx.doctorSpecialty != null || rx.doctorHospital != null)
                  _InfoBanner(
                    name:      rx.doctorName,
                    specialty: rx.doctorSpecialty,
                    hospital:  rx.doctorHospital,
                  ).animate().fadeIn(delay: 40.ms),

                const SizedBox(height: 20),

                // ── Prescription details ─────────────────────────────────────
                _SectionLabel(label: 'Prescription Details', icon: Icons.description_rounded, color: c.green),
                const SizedBox(height: 12),

                _DetailCard(c: c, children: [
                  if (rx.diagnosis != null && rx.diagnosis!.isNotEmpty)
                    _DetailRow(
                      icon:  Icons.sick_rounded,
                      label: 'Diagnosis',
                      value: rx.diagnosis!,
                      color: c.accent,
                    ),
                  _DetailRow(
                    icon:  Icons.calendar_today_rounded,
                    label: 'Date',
                    value: '${rx.prescriptionDate.day} ${months[rx.prescriptionDate.month - 1]} ${rx.prescriptionDate.year}',
                    color: c.textSec,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Medicines ────────────────────────────────────────────────
                _SectionLabel(label: 'Medicines', icon: Icons.medication_rounded, color: c.accent),
                const SizedBox(height: 12),

                if (rx.medicines.isEmpty)
                  _EmptyCard(c: c, message: 'No medicines listed.')
                else
                  ...rx.medicines.asMap().entries.map((e) {
                    final m   = e.value;
                    final idx = e.key;

                    final timingParts = <String>[
                      if (m.morning)   'Morning',
                      if (m.afternoon) 'Afternoon',
                      if (m.evening)   'Evening',
                      if (m.night)     'Night',
                    ];
                    final mealLabel = m.beforeMeal ? 'Before meal'
                        : m.afterMeal              ? 'After meal'
                        : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color:        c.accent.withAlpha(15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('Med ${idx + 1}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, fontWeight: FontWeight.w700, color: c.accent)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(m.medicineName,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                              ),
                              if (m.dose != null)
                                Text(m.dose!,
                                    style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
                            ],
                          ),
                          if (timingParts.isNotEmpty || mealLabel.isNotEmpty || m.durationDays != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ...timingParts.map((t) => _Chip(label: t, color: c.accent)),
                                if (mealLabel.isNotEmpty)
                                  _Chip(label: mealLabel, color: c.green),
                                if (m.durationDays != null)
                                  _Chip(label: '${m.durationDays} days', color: c.textSec),
                              ],
                            ),
                          ],
                          if (m.instructions != null && m.instructions!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(m.instructions!,
                                style: GoogleFonts.poppins(fontSize: 11, color: c.textMuted,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 40 * idx));
                  }),

                // ── Notes ────────────────────────────────────────────────────
                if (rx.notes != null && rx.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _SectionLabel(label: 'Notes', icon: Icons.notes_rounded, color: c.textSec),
                  const SizedBox(height: 12),
                  _DetailCard(c: c, children: [
                    Text(rx.notes!,
                        style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary, height: 1.5)),
                  ]),
                ],

                // ── Files ────────────────────────────────────────────────────
                if (rx.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'Prescription Files', icon: Icons.attach_file_rounded, color: c.textSec),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: rx.imageUrls.map((url) {
                      final isImg = isImageUrl(url);
                      return GestureDetector(
                        onTap: () => isImg
                            ? _showFullImage(context, url)
                            : launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                        child: isImg
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(url, width: 90, height: 90, fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, st) => Container(
                                      width: 90, height: 90,
                                      decoration: BoxDecoration(
                                        color:        c.surface,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.broken_image_rounded, color: c.textMuted),
                                    )),
                              )
                            : Container(
                                width: 90, height: 90,
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
                                    Text(extFromUrl(url).toUpperCase(),
                                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange)),
                                  ],
                                ),
                              ),
                      );
                    }).toList(),
                  ),
                ],

                // ── Edit history ─────────────────────────────────────────────
                const SizedBox(height: 28),
                _SectionLabel(label: 'Edit History', icon: Icons.history_rounded, color: c.textSec),
                const SizedBox(height: 12),

                if (_loadingLogs)
                  Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2))
                else if (_logs.isEmpty)
                  _EmptyCard(c: c, message: 'No history yet.')
                else
                  _DetailCard(c: c, children: _logs.asMap().entries.map((e) {
                    final log     = e.value;
                    final isLast  = e.key == _logs.length - 1;
                    final rawDate = log['action_date'] as String;
                    final parts   = rawDate.split('-');
                    final dt      = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                    final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
                    final action  = log['action'] as String? ?? 'edited';
                    final isCreate = action == 'created';

                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color:        (isCreate ? c.green : c.accent).withAlpha(18),
                              shape:        BoxShape.circle,
                            ),
                            child: Icon(
                              isCreate ? Icons.add_circle_outline_rounded : Icons.edit_outlined,
                              size:  14,
                              color: isCreate ? c.green : c.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(dateStr,
                                style: GoogleFonts.poppins(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:        (isCreate ? c.green : c.accent).withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCreate ? 'Created' : 'Edited',
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isCreate ? c.green : c.accent),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()),
              ],
            ),
          ),
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
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        c.surface,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back_rounded, color: c.textSec, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prescription',
                    style: GoogleFonts.poppins(
                        fontSize: 19, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text('For ${widget.patientName}',
                    style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
              ],
            ),
          ),
          if (widget.canEdit) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _goEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        c.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text('Edit',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final String? name;
  final String? specialty;
  final String? hospital;
  const _InfoBanner({this.name, this.specialty, this.hospital});

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
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: c.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name != null ? 'Dr. $name' : 'Doctor',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
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
        ],
      ),
    );
  }
}

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
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final ThemeColors     c;
  final List<Widget>    children;
  const _DetailCard({required this.c, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _DetailRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c.textSec)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final ThemeColors c;
  final String      message;
  const _EmptyCard({required this.c, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.border),
      ),
      child: Text(message,
          style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(50)),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
