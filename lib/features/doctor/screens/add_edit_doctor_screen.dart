// add_edit_doctor_screen.dart — Form to create or edit a doctor record.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../models/doctor.dart';
import '../services/doctor_service.dart';

class AddEditDoctorScreen extends StatefulWidget {
  final Doctor? existing;
  const AddEditDoctorScreen({super.key, this.existing});

  @override
  State<AddEditDoctorScreen> createState() => _AddEditDoctorScreenState();
}

class _AddEditDoctorScreenState extends State<AddEditDoctorScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _service     = DoctorService();

  final _nameCtrl    = TextEditingController();
  final _specCtrl    = TextEditingController();
  final _hospCtrl    = TextEditingController();
  final _chamberCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _feeCtrl     = TextEditingController();
  final _notesCtrl   = TextEditingController();

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _populate();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    _hospCtrl.dispose();
    _chamberCtrl.dispose();
    _phoneCtrl.dispose();
    _feeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _populate() {
    final d = widget.existing!;
    _nameCtrl.text    = d.name;
    _specCtrl.text    = d.specialty    ?? '';
    _hospCtrl.text    = d.hospital     ?? '';
    _chamberCtrl.text = d.chamberAddress ?? '';
    _phoneCtrl.text   = d.phone        ?? '';
    _feeCtrl.text     = d.fee          ?? '';
    _notesCtrl.text   = d.notes        ?? '';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final draft = Doctor(
        id:             _isEdit ? widget.existing!.id : '',
        userId:         '',
        name:           _nameCtrl.text.trim(),
        specialty:      _specCtrl.text.trim().nullIfEmpty,
        hospital:       _hospCtrl.text.trim().nullIfEmpty,
        chamberAddress: _chamberCtrl.text.trim().nullIfEmpty,
        phone:          _phoneCtrl.text.trim().nullIfEmpty,
        fee:            _feeCtrl.text.trim().nullIfEmpty,
        notes:          _notesCtrl.text.trim().nullIfEmpty,
        isFavorite:     _isEdit ? widget.existing!.isFavorite : false,
        createdAt:      DateTime.now(),
        updatedAt:      DateTime.now(),
      );
      if (_isEdit) {
        await _service.update(draft);
      } else {
        await _service.create(draft);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isEdit ? 'Doctor updated.' : 'Doctor saved.',
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
                    _SectionLabel(text: 'Doctor Info'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:     _nameCtrl,
                        label:    s.doctorName,
                        icon:     Icons.person_rounded,
                        required: true,
                      ),
                      _Field(
                        ctrl:   _specCtrl,
                        label:  s.specialty,
                        icon:   Icons.local_hospital_rounded,
                      ),
                      _Field(
                        ctrl:   _hospCtrl,
                        label:  s.hospitalClinic,
                        icon:   Icons.apartment_rounded,
                      ),
                      _Field(
                        ctrl:   _chamberCtrl,
                        label:  s.chamberAddress,
                        icon:   Icons.location_on_rounded,
                        isLast: true,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _SectionLabel(text: 'Contact & Fee'),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:  _phoneCtrl,
                        label: s.doctorPhone,
                        icon:  Icons.phone_rounded,
                      ),
                      _Field(
                        ctrl:   _feeCtrl,
                        label:  s.consultationFee,
                        icon:   Icons.payments_outlined,
                        isLast: true,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _SectionLabel(text: s.notes),
                    const SizedBox(height: 12),
                    _FormCard(children: [
                      _Field(
                        ctrl:     _notesCtrl,
                        label:    s.notes,
                        icon:     Icons.notes_rounded,
                        maxLines: 4,
                        isLast:   true,
                      ),
                    ]),

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
            _isEdit ? s.editDoctor : s.addDoctor,
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
  final bool                  required;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.isLast   = false,
    this.required = false,
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
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null,
            decoration: InputDecoration(
              labelText:  label,
              labelStyle: GoogleFonts.poppins(
                  fontSize: 12, color: c.textMuted),
              prefixIcon: Icon(icon,
                  size: 18, color: c.green),
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
          color:        c.green,
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
