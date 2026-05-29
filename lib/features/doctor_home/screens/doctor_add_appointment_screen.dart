import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../appointment/models/appointment.dart';
import '../../appointment/services/appointment_service.dart';

class DoctorAddAppointmentScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorAddAppointmentScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DoctorAddAppointmentScreen> createState() =>
      _DoctorAddAppointmentScreenState();
}

class _DoctorAddAppointmentScreenState
    extends State<DoctorAddAppointmentScreen> {
  final _svc         = AppointmentService();
  final _reasonCtrl  = TextEditingController();
  final _notesCtrl   = TextEditingController();

  DateTime _date    = DateTime.now().add(const Duration(days: 1));
  String?  _doctorName;
  bool     _saving  = false;

  @override
  void initState() {
    super.initState();
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    if (meta != null) {
      _doctorName = meta['full_name'] as String?;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date,
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 365 * 2)),
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
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a visit reason.', style: GoogleFonts.poppins()),
        backgroundColor: context.colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final appt = Appointment(
        id:                 '',
        userId:             widget.patientId,
        doctorId:           null,
        doctorNameSnapshot: _doctorName ?? 'Doctor',
        appointmentDate:    _date,
        appointmentTime:    null,
        visitReason:        _reasonCtrl.text.trim(),
        status:             AppointmentStatus.scheduled,
        notes:              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt:          DateTime.now(),
        updatedAt:          DateTime.now(),
      );

      await _svc.createForPatient(patientId: widget.patientId, appt: appt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Appointment added!', style: GoogleFonts.poppins()),
          backgroundColor: context.colors.green,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Failed to save. Please try again.', style: GoogleFonts.poppins()),
          backgroundColor: context.colors.red,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [

                // ── Visit reason ─────────────────────────────────────────────
                _label('Visit Reason', c),
                const SizedBox(height: 10),
                _field(_reasonCtrl, c, 'e.g. Follow-up, Consultation', Icons.notes_rounded)
                    .animate().fadeIn(delay: 80.ms),

                const SizedBox(height: 20),

                // ── Date ─────────────────────────────────────────────────────
                _label('Date', c),
                const SizedBox(height: 10),
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
                        Text(dateStr,
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        const Spacer(),
                        Icon(Icons.edit_rounded, size: 14, color: c.textMuted),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 120.ms),

                const SizedBox(height: 20),

                // ── Notes ─────────────────────────────────────────────────────
                _label('Notes (optional)', c),
                const SizedBox(height: 10),
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
                      hintText:       'Additional notes...',
                      hintStyle:      GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                      border:         InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 32),

                // ── Save button ────────────────────────────────────────────────
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(_saving ? 'Saving...' : 'Add Appointment',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ).animate().fadeIn(delay: 240.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, ThemeColors c) {
    return Text(text,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSec));
  }

  Widget _field(TextEditingController ctrl, ThemeColors c, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: c.border),
      ),
      child: TextField(
        controller: ctrl,
        style:      GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
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
                Text('Add Appointment',
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
