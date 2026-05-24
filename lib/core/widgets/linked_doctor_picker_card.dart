// linked_doctor_picker_card.dart
// Reusable widget: shows a tap-to-open card that lets the patient pick one of
// their linked (accepted) doctors. Used in prescription and lab-report forms.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_colors.dart';
import '../../features/doctor_home/models/doctor_patient_link.dart';
import '../../features/doctor_home/services/doctor_patient_link_service.dart';

class LinkedDoctorPickerCard extends StatefulWidget {
  /// Currently selected doctor's user-id (null = none selected).
  final String? selectedDoctorId;

  /// Called with the new doctor-id when the user selects one, or null to clear.
  final void Function(DoctorPatientLink?) onChanged;

  const LinkedDoctorPickerCard({
    super.key,
    required this.selectedDoctorId,
    required this.onChanged,
  });

  @override
  State<LinkedDoctorPickerCard> createState() => _LinkedDoctorPickerCardState();
}

class _LinkedDoctorPickerCardState extends State<LinkedDoctorPickerCard> {
  final _linkSvc = DoctorPatientLinkService();
  List<DoctorPatientLink> _doctors = [];
  bool _loading = true;

  DoctorPatientLink? get _selected =>
      _doctors.where((d) => d.doctorId == widget.selectedDoctorId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final links = await _linkSvc.fetchIncomingRequests();
    if (mounted) {
      setState(() {
        _doctors = links.where((l) => l.isAccepted).toList();
        _loading = false;
      });
    }
  }

  Future<void> _openPicker() async {
    final c = context.colors;
    final picked = await showModalBottomSheet<DoctorPatientLink?>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DoctorPickerSheet(
        doctors:    _doctors,
        selectedId: widget.selectedDoctorId,
      ),
    );
    // picked == null means the sheet was dismissed without selection.
    // picked == _clearSentinel means user tapped "Clear".
    if (picked == _clearSentinel) {
      widget.onChanged(null);
    } else if (picked != null) {
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sel = _selected;

    return GestureDetector(
      onTap: _loading ? null : _openPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        c.card,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: c.border, width: 1),
        ),
        child: _loading
            ? Row(children: [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(color: c.cyan, strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('Loading doctors…',
                    style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted)),
              ])
            : _doctors.isEmpty
                ? Row(children: [
                    Icon(Icons.person_search_rounded, size: 18, color: c.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No linked doctors — add from My Doctors first',
                        style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
                      ),
                    ),
                  ])
                : Row(children: [
                    Icon(Icons.person_rounded,
                        size: 18,
                        color: sel != null ? c.cyan : c.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: sel != null
                          ? Text(
                              'Dr. ${sel.doctorName ?? "Unknown"}',
                              style: GoogleFonts.poppins(
                                fontSize:   13,
                                color:      c.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : Text(
                              'Select Doctor',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: c.textMuted),
                            ),
                    ),
                    if (sel != null) ...[
                      Icon(Icons.verified_rounded, size: 16, color: c.green),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => widget.onChanged(null),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: c.textMuted),
                        ),
                      ),
                    ] else
                      Icon(Icons.expand_more_rounded,
                          size: 20, color: c.textMuted),
                  ]),
      ),
    );
  }
}

// Sentinel instance returned when the user taps "Clear selection".
final _clearSentinel = DoctorPatientLink(
  id: '__clear__', doctorId: '', patientId: '', status: '',
  requestedAt: DateTime(2000),
);

// ── Bottom sheet ─────────────────────────────────────────────────────────────

class _DoctorPickerSheet extends StatelessWidget {
  final List<DoctorPatientLink> doctors;
  final String?                 selectedId;

  const _DoctorPickerSheet({
    required this.doctors,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Select Doctor',
                style: GoogleFonts.poppins(
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                  color:      c.textPrimary,
                )),
          ),
          const SizedBox(height: 12),
          ...doctors.asMap().entries.map((e) {
            final idx    = e.key;
            final link   = e.value;
            final isLast = idx == doctors.length - 1;
            final isSel  = link.doctorId == selectedId;
            return Column(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(link),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color:        c.cyan.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.person_rounded,
                              color: c.cyan, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${link.doctorName ?? "Unknown"}',
                                style: GoogleFonts.poppins(
                                  fontSize:   13,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSel ? c.cyan : c.textPrimary,
                                ),
                              ),
                              if ((link.doctorHospital ?? '').isNotEmpty)
                                Text(
                                  link.doctorHospital!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: c.textMuted),
                                ),
                            ],
                          ),
                        ),
                        if (isSel)
                          Icon(Icons.check_circle_rounded,
                              color: c.green, size: 18),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(height: 1, indent: 20, endIndent: 20,
                      color: c.border, thickness: 1),
              ],
            );
          }),
          if (selectedId != null) ...[
            Divider(height: 1, color: c.border, thickness: 1),
            InkWell(
              onTap: () => Navigator.of(context).pop(_clearSentinel),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                    const SizedBox(width: 12),
                    Text('Clear selection',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: c.textMuted)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
