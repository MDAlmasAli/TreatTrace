// add_edit_appointment_screen.dart — Form to create or edit an appointment.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../doctor/models/doctor.dart';
import '../../doctor/services/doctor_service.dart';
import '../../prescription/models/prescription.dart';
import '../../prescription/services/prescription_service.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';

class AddEditAppointmentScreen extends StatefulWidget {
  final Appointment? existing;
  // Pre-fill doctor when opened from DoctorDetailScreen
  final Doctor?      preselectedDoctor;

  const AddEditAppointmentScreen({
    super.key,
    this.existing,
    this.preselectedDoctor,
  });

  @override
  State<AddEditAppointmentScreen> createState() =>
      _AddEditAppointmentScreenState();
}

class _AddEditAppointmentScreenState
    extends State<AddEditAppointmentScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _apptSvc    = AppointmentService();
  final _doctorSvc  = DoctorService();
  final _prescSvc   = PrescriptionService();

  final _reasonCtrl = TextEditingController();
  final _timeCtrl   = TextEditingController();
  final _notesCtrl  = TextEditingController();

  // Doctor selection
  List<Doctor> _doctors       = [];
  Doctor?      _selectedDoctor;
  bool         _loadingDoctors = false;

  // Date
  DateTime? _date;

  // Prescription link
  List<Prescription> _prescriptions        = [];
  String?            _linkedPrescId;
  bool               _loadingPrescriptions = false;

  // Status (edit only)
  AppointmentStatus _status = AppointmentStatus.scheduled;

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadPrescriptions();
    if (_isEdit) _populate();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _timeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _loadingDoctors = true);
    try {
      _doctors = await _doctorSvc.fetchAll();
      // Apply preselected doctor if provided
      if (widget.preselectedDoctor != null && !_isEdit) {
        _selectedDoctor = _doctors.firstWhere(
          (d) => d.id == widget.preselectedDoctor!.id,
          orElse: () => widget.preselectedDoctor!,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _loadingPrescriptions = true);
    try {
      _prescriptions = await _prescSvc.fetchAll();
    } finally {
      if (mounted) setState(() => _loadingPrescriptions = false);
    }
  }

  void _populate() {
    final a = widget.existing!;
    _reasonCtrl.text  = a.visitReason ?? '';
    _timeCtrl.text    = a.appointmentTime ?? '';
    _notesCtrl.text   = a.notes ?? '';
    _date             = a.appointmentDate;
    _status           = a.status;
    _linkedPrescId    = a.prescriptionId;
    // Doctor match happens after _loadDoctors completes
    if (a.doctorId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final match = _doctors.where((d) => d.id == a.doctorId).toList();
        if (match.isNotEmpty) setState(() => _selectedDoctor = match.first);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date ?? DateTime.now(),
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   context.colors.amber,
            onPrimary: Colors.white,
            surface:   context.colors.card,
            onSurface: context.colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a date.', style: GoogleFonts.poppins()),
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final doctorName = _selectedDoctor?.name ??
          (_isEdit ? widget.existing!.doctorNameSnapshot : 'Unknown');

      final draft = Appointment(
        id:                 _isEdit ? widget.existing!.id : '',
        userId:             '',
        doctorId:           _selectedDoctor?.id,
        doctorNameSnapshot: doctorName,
        appointmentDate:    _date!,
        appointmentTime:    _timeCtrl.text.trim().nullIfEmpty,
        visitReason:        _reasonCtrl.text.trim().nullIfEmpty,
        status:             _status,
        notes:              _notesCtrl.text.trim().nullIfEmpty,
        prescriptionId:     _linkedPrescId,
        createdAt:          DateTime.now(),
        updatedAt:          DateTime.now(),
      );

      if (_isEdit) {
        await _apptSvc.update(draft);
      } else {
        await _apptSvc.create(draft);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isEdit ? 'Appointment updated.' : 'Appointment saved.',
            style: GoogleFonts.poppins(),
          ),
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
                    // ── Doctor ────────────────────────────────────────────
                    _SectionLabel(text: s.selectDoctor),
                    const SizedBox(height: 12),
                    _DoctorPicker(
                      doctors:  _doctors,
                      selected: _selectedDoctor,
                      loading:  _loadingDoctors,
                      onChanged: (d) =>
                          setState(() => _selectedDoctor = d),
                    ),

                    // ── Date & Time ───────────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: 'Date & Time'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _DateRow(
                        date:  _date,
                        label: s.appointmentDate,
                        onTap: _pickDate,
                        onClear: () => setState(() => _date = null),
                      ),
                      _Field(
                        ctrl:   _timeCtrl,
                        label:  s.appointmentTime,
                        icon:   Icons.access_time_rounded,
                        isLast: true,
                        hint:   'e.g. 10:30 AM',
                      ),
                    ]),

                    // ── Visit info ────────────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: 'Visit Info'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:  _reasonCtrl,
                        label: s.visitReason,
                        icon:  Icons.medical_services_rounded,
                      ),
                      _Field(
                        ctrl:     _notesCtrl,
                        label:    s.notes,
                        icon:     Icons.notes_rounded,
                        maxLines: 3,
                        isLast:   true,
                      ),
                    ]),

                    // ── Status (edit only) ────────────────────────────────
                    if (_isEdit) ...[
                      const SizedBox(height: 24),
                      _SectionLabel(text: 'Status'),
                      const SizedBox(height: 12),
                      _StatusPicker(
                        selected:  _status,
                        onChanged: (st) => setState(() => _status = st),
                      ),
                    ],

                    // ── Prescription link ─────────────────────────────────
                    const SizedBox(height: 24),
                    _SectionLabel(text: s.linkedPrescription),
                    const SizedBox(height: 12),
                    _PrescriptionPicker(
                      prescriptions: _prescriptions,
                      selectedId:    _linkedPrescId,
                      loading:       _loadingPrescriptions,
                      onChanged: (id) =>
                          setState(() => _linkedPrescId = id),
                    ),

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
            _isEdit ? s.editAppointment : s.addAppointment,
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

// ── Doctor picker ─────────────────────────────────────────────────────────────

class _DoctorPicker extends StatelessWidget {
  final List<Doctor>        doctors;
  final Doctor?             selected;
  final bool                loading;
  final void Function(Doctor?) onChanged;

  const _DoctorPicker({
    required this.doctors,
    required this.selected,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: c.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: loading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: c.amber, strokeWidth: 2),
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<Doctor?>(
                value:      selected,
                isExpanded: true,
                dropdownColor: c.card,
                icon: Icon(Icons.expand_more_rounded,
                    color: c.textMuted, size: 20),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: c.textPrimary),
                hint: Text(
                  s.noLinkedDoctor,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: c.textMuted),
                ),
                onChanged: onChanged,
                items: [
                  DropdownMenuItem<Doctor?>(
                    value: null,
                    child: Text(s.noLinkedDoctor,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: c.textMuted)),
                  ),
                  ...doctors.map((d) => DropdownMenuItem<Doctor?>(
                        value: d,
                        child: Text(
                          d.displayName +
                              (d.specialty?.isNotEmpty == true
                                  ? ' · ${d.specialty}'
                                  : ''),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: c.textPrimary),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}

// ── Status picker ─────────────────────────────────────────────────────────────

class _StatusPicker extends StatelessWidget {
  final AppointmentStatus             selected;
  final void Function(AppointmentStatus) onChanged;

  const _StatusPicker({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.colors;
    final options = [
      (AppointmentStatus.scheduled, s.statusScheduled, c.amber),
      (AppointmentStatus.completed, s.statusCompleted, c.green),
      (AppointmentStatus.cancelled, s.statusCancelled, c.red),
    ];

    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final (status, label, color) = opt;
        final isSelected = selected == status;
        return GestureDetector(
          onTap: () => onChanged(status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:        isSelected ? color.withAlpha(25) : context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(
                color: isSelected ? color : context.colors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color:      isSelected ? color : context.colors.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Prescription picker ───────────────────────────────────────────────────────

class _PrescriptionPicker extends StatelessWidget {
  final List<Prescription> prescriptions;
  final String?            selectedId;
  final bool               loading;
  final void Function(String?) onChanged;

  const _PrescriptionPicker({
    required this.prescriptions,
    required this.selectedId,
    required this.loading,
    required this.onChanged,
  });

  String _label(Prescription p) {
    final doc  = p.doctorName?.isNotEmpty == true
        ? 'Dr. ${p.doctorName}'
        : 'Unknown Doctor';
    final date = '${p.prescriptionDate.day.toString().padLeft(2, '0')}/'
        '${p.prescriptionDate.month.toString().padLeft(2, '0')}/'
        '${p.prescriptionDate.year}';
    return '$doc — $date';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    return Container(
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: c.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: loading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: c.amber, strokeWidth: 2),
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value:      selectedId,
                isExpanded: true,
                dropdownColor: c.card,
                icon: Icon(Icons.expand_more_rounded,
                    color: c.textMuted, size: 20),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: c.textPrimary),
                hint: Text(
                  s.noLinkedPrescription,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: c.textMuted),
                ),
                onChanged: onChanged,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(s.noLinkedPrescription,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: c.textMuted)),
                  ),
                  ...prescriptions.map((p) => DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(
                          _label(p),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: c.textPrimary),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}

// ── Shared form widgets ───────────────────────────────────────────────────────

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
  final int                   maxLines;
  final bool                  isLast;
  final String?               hint;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.isLast   = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller: ctrl,
            maxLines:   maxLines,
            style: GoogleFonts.poppins(
                fontSize: 13, color: c.textPrimary),
            decoration: InputDecoration(
              labelText:  label,
              labelStyle: GoogleFonts.poppins(
                  fontSize: 12, color: c.textMuted),
              hintText:  hint,
              hintStyle: hint != null
                  ? GoogleFonts.poppins(fontSize: 12, color: c.textMuted)
                  : null,
              prefixIcon: Icon(icon,
                  size: 18, color: c.amber),
              border:         InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1, indent: 16, endIndent: 16,
              color: c.border, thickness: 1),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime?    date;
  final String       label;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateRow({
    required this.date,
    required this.label,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18, color: c.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: c.textMuted)),
                      Text(
                        date != null
                            ? '${date!.day.toString().padLeft(2, '0')}/'
                              '${date!.month.toString().padLeft(2, '0')}/'
                              '${date!.year}'
                            : '—',
                        style: GoogleFonts.poppins(
                          fontSize:   13,
                          color: date != null
                              ? c.textPrimary
                              : c.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (date != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded,
                        size: 16, color: c.textMuted),
                  )
                else
                  Icon(Icons.edit_calendar_rounded,
                      size: 16, color: c.textMuted),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 16, endIndent: 16,
            color: c.border, thickness: 1),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool         saving;
  final VoidCallback onTap;

  const _SaveButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        width:  double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color:        c.amber,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withAlpha(8),
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

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
