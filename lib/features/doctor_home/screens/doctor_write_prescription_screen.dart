import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/models/prescription_medicine.dart';
import '../../prescription/services/prescription_service.dart';

class DoctorWritePrescriptionScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorWritePrescriptionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DoctorWritePrescriptionScreen> createState() =>
      _DoctorWritePrescriptionScreenState();
}

class _DoctorWritePrescriptionScreenState
    extends State<DoctorWritePrescriptionScreen> {
  final _svc = PrescriptionService();

  final _nameCtrl      = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _hospitalCtrl  = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();

  DateTime         _date     = DateTime.now();
  final List<_MedEntry> _meds = [];
  bool             _saving   = false;

  @override
  void initState() {
    super.initState();
    _addMed();
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    if (meta != null) {
      _nameCtrl.text = (meta['full_name'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specialtyCtrl.dispose();
    _hospitalCtrl.dispose();
    _phoneCtrl.dispose();
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    for (final m in _meds) { m.dispose(); }
    super.dispose();
  }

  void _addMed() => setState(() => _meds.add(_MedEntry()));

  void _removeMed(int i) {
    _meds[i].dispose();
    setState(() => _meds.removeAt(i));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: context.colors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final validMeds = _meds.where((m) => m.nameCtrl.text.trim().isNotEmpty).toList();

    if (_diagnosisCtrl.text.trim().isEmpty && validMeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Add a diagnosis or at least one medicine.',
            style: GoogleFonts.poppins()),
        backgroundColor: context.colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final rx = Prescription(
        id:               '',
        userId:           widget.patientId,
        doctorName:       _nameCtrl.text.trim().isEmpty      ? null : _nameCtrl.text.trim(),
        doctorSpecialty:  _specialtyCtrl.text.trim().isEmpty ? null : _specialtyCtrl.text.trim(),
        doctorHospital:   _hospitalCtrl.text.trim().isEmpty  ? null : _hospitalCtrl.text.trim(),
        doctorPhone:      _phoneCtrl.text.trim().isEmpty     ? null : _phoneCtrl.text.trim(),
        diagnosis:        _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
        prescriptionDate: _date,
        notes:            _notesCtrl.text.trim().isEmpty     ? null : _notesCtrl.text.trim(),
        createdAt:        DateTime.now(),
      );

      final medicines = validMeds.map((e) => e.toMedicine()).toList();
      await _svc.createForPatient(
        patientId:   widget.patientId,
        prescription: rx,
        medicines:   medicines,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Prescription saved!', style: GoogleFonts.poppins()),
          backgroundColor: context.colors.green,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save. Please try again.', style: GoogleFonts.poppins()),
          backgroundColor: context.colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    final months  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${_date.day} ${months[_date.month-1]} ${_date.year}';

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
                _SectionLabel(label: 'Doctor Information', icon: Icons.person_rounded, color: c.accent),
                const SizedBox(height: 12),
                _field(_nameCtrl,      c, 'Doctor Name',      Icons.badge_rounded),
                const SizedBox(height: 10),
                _field(_specialtyCtrl, c, 'Specialty',         Icons.medical_services_rounded),
                const SizedBox(height: 10),
                _field(_hospitalCtrl,  c, 'Hospital / Clinic', Icons.local_hospital_rounded),
                const SizedBox(height: 10),
                _field(_phoneCtrl,     c, 'Doctor Phone',      Icons.phone_rounded,
                    keyboardType: TextInputType.phone),

                const SizedBox(height: 24),

                // ── Prescription info ────────────────────────────────────────
                _SectionLabel(label: 'Prescription Details', icon: Icons.description_rounded, color: c.green),
                const SizedBox(height: 12),
                _field(_diagnosisCtrl, c, 'Diagnosis / Complaint', Icons.sick_rounded),
                const SizedBox(height: 10),

                // Date row
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

                // ── Medicines ────────────────────────────────────────────────
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
                ..._meds.asMap().entries.map(
                  (e) => _MedicineCard(
                    key:      ValueKey(e.key),
                    entry:    e.value,
                    index:    e.key,
                    canRemove: _meds.length > 1,
                    onRemove: () => _removeMed(e.key),
                  ).animate().fadeIn(delay: Duration(milliseconds: 40 * e.key)),
                ),

                const SizedBox(height: 24),

                // ── Notes ────────────────────────────────────────────────────
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
                      hintText:        'Additional instructions or notes...',
                      hintStyle:       GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                      border:          InputBorder.none,
                      contentPadding:  const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Save button ───────────────────────────────────────────────
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(_saving ? 'Saving...' : 'Save Prescription',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
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

  Widget _field(
    TextEditingController ctrl,
    ThemeColors c,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.border),
      ),
      child: TextField(
        controller:   ctrl,
        keyboardType: keyboardType,
        style:        GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          hintText:       hint,
          hintStyle:      GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
          prefixIcon:     Icon(icon, color: c.textSec, size: 18),
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c) {
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
                Text('Write Prescription',
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
  final _MedEntry   entry;
  final int         index;
  final bool        canRemove;
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
    final c   = context.colors;
    final e   = widget.entry;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Name + dose row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _inlineField(e.nameCtrl, c, 'Medicine name *'),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _inlineField(e.doseCtrl, c, 'Dose (e.g. 500mg)'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Timing
          Text('Timing', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSec)),
          const SizedBox(height: 6),
          Row(
            children: [
              _TimingChip(label: 'M',   active: e.morning,   onTap: () => setState(() => e.morning   = !e.morning)),
              const SizedBox(width: 6),
              _TimingChip(label: 'A',   active: e.afternoon, onTap: () => setState(() => e.afternoon = !e.afternoon)),
              const SizedBox(width: 6),
              _TimingChip(label: 'E',   active: e.evening,   onTap: () => setState(() => e.evening   = !e.evening)),
              const SizedBox(width: 6),
              _TimingChip(label: 'N',   active: e.night,     onTap: () => setState(() => e.night     = !e.night)),
              const Spacer(),
              SizedBox(
                width: 80,
                child: _inlineField(e.durationCtrl, c, 'Days',
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
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
        color:        c.surface,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: c.border),
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
        width: 36, height: 36,
        decoration: BoxDecoration(
          color:        active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: active ? c.accent : c.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize:   12,
            fontWeight: FontWeight.w700,
            color:      active ? Colors.white : c.textSec,
          ),
        ),
      ),
    );
  }
}

// ── Mutable medicine entry for the form ───────────────────────────────────────

class _MedEntry {
  final nameCtrl     = TextEditingController();
  final doseCtrl     = TextEditingController();
  final durationCtrl = TextEditingController();
  bool morning   = false;
  bool afternoon = false;
  bool evening   = false;
  bool night     = false;

  void dispose() {
    nameCtrl.dispose();
    doseCtrl.dispose();
    durationCtrl.dispose();
  }

  PrescriptionMedicine toMedicine() => PrescriptionMedicine(
    id:              '',
    prescriptionId:  '',
    medicineName:    nameCtrl.text.trim(),
    dose:            doseCtrl.text.trim().isEmpty     ? null : doseCtrl.text.trim(),
    morning:         morning,
    afternoon:       afternoon,
    evening:         evening,
    night:           night,
    durationDays:    int.tryParse(durationCtrl.text.trim()),
  );
}
