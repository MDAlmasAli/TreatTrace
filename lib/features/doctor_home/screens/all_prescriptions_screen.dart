import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import 'doctor_prescription_view_screen.dart';
import 'doctor_write_prescription_screen.dart';

class AllPrescriptionsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const AllPrescriptionsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<AllPrescriptionsScreen> createState() => _AllPrescriptionsScreenState();
}

class _AllPrescriptionsScreenState extends State<AllPrescriptionsScreen> {
  final _svc = PrescriptionService();

  final String _currentDoctorId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  List<Prescription> _list    = [];
  bool               _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchForPatient(widget.patientId);
      if (mounted) setState(() => _list = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goView(Prescription rx) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorPrescriptionViewScreen(
        rx:          rx,
        canEdit:     rx.writtenByDoctorId == _currentDoctorId,
        patientId:   widget.patientId,
        patientName: widget.patientName,
      ),
    ));
    if (result == true) _load();
  }

  Future<void> _goEdit(Prescription rx) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorWritePrescriptionScreen(
        patientId:   widget.patientId,
        patientName: widget.patientName,
        existing:    rx,
      ),
    ));
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

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
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5))
                : _list.isEmpty
                    ? Center(
                        child: Text('No prescriptions found.',
                            style: GoogleFonts.poppins(fontSize: 14, color: c.textMuted)))
                    : RefreshIndicator(
                        color:    c.accent,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:     const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          itemCount:   _list.length,
                          itemBuilder: (ctx, i) => _RxTile(
                            rx:      _list[i],
                            canEdit: _list[i].writtenByDoctorId == _currentDoctorId,
                            onView:  () => _goView(_list[i]),
                            onEdit:  () => _goEdit(_list[i]),
                          ).animate().fadeIn(delay: Duration(milliseconds: 30 * i)),
                        ),
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
                Text('All Prescriptions',
                    style: GoogleFonts.poppins(
                        fontSize: 19, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text(widget.patientName,
                    style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        c.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_list.length}',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Prescription tile ─────────────────────────────────────────────────────────

class _RxTile extends StatelessWidget {
  final Prescription rx;
  final bool         canEdit;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const _RxTile({
    required this.rx,
    required this.canEdit,
    required this.onView,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final date    = rx.prescriptionDate;
    final months  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${date.day} ${months[date.month - 1]} ${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        c.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.medication_rounded, color: c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rx.diagnosis ?? (rx.medicines.isNotEmpty
                      ? rx.medicines.first.medicineName : 'Prescription'),
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(dateStr,
                    style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // View button — always visible
          GestureDetector(
            onTap: onView,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        c.accent.withAlpha(12),
                borderRadius: BorderRadius.circular(9),
                border:       Border.all(color: c.accent.withAlpha(40)),
              ),
              child: Icon(Icons.visibility_rounded, size: 15, color: c.accent),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color:        c.green.withAlpha(12),
                  borderRadius: BorderRadius.circular(9),
                  border:       Border.all(color: c.green.withAlpha(40)),
                ),
                child: Icon(Icons.edit_rounded, size: 15, color: c.green),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
