import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/doctor_verification_service.dart';

class DoctorCredentialsScreen extends StatefulWidget {
  const DoctorCredentialsScreen({super.key});

  @override
  State<DoctorCredentialsScreen> createState() => _DoctorCredentialsScreenState();
}

class _DoctorCredentialsScreenState extends State<DoctorCredentialsScreen> {
  final _service = DoctorVerificationService();

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _editing = false;
  bool _saving  = false;
  String? _error;

  final _bmdcCtrl       = TextEditingController();
  final _specialtyCtrl  = TextEditingController();
  final _hospitalCtrl   = TextEditingController();
  final _nidCtrl        = TextEditingController();
  final _degreeCtrl     = TextEditingController();
  final _aboutCtrl      = TextEditingController();
  final _additionalCtrl = TextEditingController();
  final _formKey        = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bmdcCtrl.dispose();
    _specialtyCtrl.dispose();
    _hospitalCtrl.dispose();
    _nidCtrl.dispose();
    _degreeCtrl.dispose();
    _aboutCtrl.dispose();
    _additionalCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _editing = false; });
    try {
      final data = await _service.fetchMyVerification();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startEdit() {
    final d = _data!;
    _bmdcCtrl.text       = d['bmdc_number']    ?? '';
    _specialtyCtrl.text  = d['specialty']       ?? '';
    _hospitalCtrl.text   = d['hospital']        ?? '';
    _nidCtrl.text        = d['nid_passport']    ?? '';
    _degreeCtrl.text     = d['degree']          ?? '';
    _aboutCtrl.text      = d['about']           ?? '';
    _additionalCtrl.text = d['additional_info'] ?? '';
    setState(() { _editing = true; _error = null; });
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _service.submitEdit(
        bmdcNumber:     _bmdcCtrl.text.trim(),
        specialty:      _specialtyCtrl.text.trim(),
        hospital:       _hospitalCtrl.text.trim(),
        nidPassport:    _nidCtrl.text.trim(),
        degree:         _degreeCtrl.text.trim(),
        about:          _aboutCtrl.text.trim(),
        additionalInfo: _additionalCtrl.text.trim(),
      );
      if (mounted) setState(() => _saving = false);
      await _load();
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to submit: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Credentials',
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          if (!_loading && _data != null && !_editing && _data!['edit_status'] == null)
            TextButton.icon(
              onPressed: _startEdit,
              icon: Icon(Icons.edit_rounded, size: 16, color: c.accent),
              label: Text('Edit',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5))
          : _editing
              ? _buildEditForm(c)
              : _buildView(c),
    );
  }

  // ── View mode ─────────────────────────────────────────────────────────────
  Widget _buildView(ThemeColors c) {
    final d = _data!;
    final editStatus = d['edit_status'] as String?;
    final hasPending = editStatus == 'pending';
    final wasRejected = editStatus == 'rejected';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verification status chip
          _StatusChip(status: d['status'] as String? ?? 'pending'),
          const SizedBox(height: 20),

          // Rejected edit banner
          if (wasRejected) ...[
            _Banner(
              color: c.red,
              icon: Icons.cancel_rounded,
              title: 'Edit Rejected',
              message: d['edit_rejection_reason'] as String? ?? '',
            ),
            const SizedBox(height: 16),
          ],

          // Pending edit info banner
          if (hasPending) ...[
            _Banner(
              color: c.amber,
              icon: Icons.hourglass_top_rounded,
              title: 'Edit Pending Review',
              message: 'Your updated credentials are awaiting admin approval.',
            ),
            const SizedBox(height: 16),
          ],

          // Credential fields
          _CredentialCard(
            c: c,
            fields: [
              _FieldRow(
                label: 'BMDC Registration No.',
                icon: Icons.badge_rounded,
                current: d['bmdc_number'] ?? '-',
                pending: hasPending ? d['pending_bmdc'] : null,
              ),
              _FieldRow(
                label: 'Specialty',
                icon: Icons.medical_services_rounded,
                current: d['specialty'] ?? '-',
                pending: hasPending ? d['pending_specialty'] : null,
              ),
              _FieldRow(
                label: 'Hospital / Clinic',
                icon: Icons.local_hospital_rounded,
                current: d['hospital'] ?? '-',
                pending: hasPending ? d['pending_hospital'] : null,
              ),
              _FieldRow(
                label: 'NID / Passport No.',
                icon: Icons.perm_identity_rounded,
                current: d['nid_passport'] ?? '-',
                pending: hasPending ? d['pending_nid_passport'] : null,
              ),
              _FieldRow(
                label: 'Degree',
                icon: Icons.school_rounded,
                current: d['degree'] ?? '-',
                pending: hasPending ? d['pending_degree'] : null,
              ),
              _FieldRow(
                label: 'About Myself',
                icon: Icons.person_outline_rounded,
                current: d['about'] ?? '-',
                pending: hasPending ? d['pending_about'] : null,
              ),
              if ((d['additional_info'] as String?)?.isNotEmpty == true ||
                  (hasPending && (d['pending_additional'] as String?)?.isNotEmpty == true))
                _FieldRow(
                  label: 'Additional Info',
                  icon: Icons.notes_rounded,
                  current: d['additional_info'] ?? '-',
                  pending: hasPending ? d['pending_additional'] : null,
                ),
            ],
          ),

          if (wasRejected) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _startEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text('Update & Resubmit',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Edit form ─────────────────────────────────────────────────────────────
  Widget _buildEditForm(ThemeColors c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.accent.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.accent.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: c.accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your changes will be reviewed by admin before going live. '
                      'Your current info remains visible until approved.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: c.accent, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _EditField(label: 'BMDC Registration No.', hint: 'e.g. A-12345',
                controller: _bmdcCtrl, icon: Icons.badge_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _EditField(label: 'Specialty', hint: 'e.g. Cardiologist',
                controller: _specialtyCtrl, icon: Icons.medical_services_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _EditField(label: 'Hospital / Clinic', hint: 'Workplace name',
                controller: _hospitalCtrl, icon: Icons.local_hospital_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _EditField(label: 'NID / Passport No.', hint: 'ID number',
                controller: _nidCtrl, icon: Icons.perm_identity_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _EditField(label: 'Degree', hint: 'e.g. MBBS, MD, BDS',
                controller: _degreeCtrl, icon: Icons.school_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _EditField(label: 'About Myself', hint: 'Brief professional introduction…',
                controller: _aboutCtrl, icon: Icons.person_outline_rounded,
                maxLines: 4,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _EditField(label: 'Additional Info (Optional)', hint: 'Any other notes',
                controller: _additionalCtrl, icon: Icons.notes_rounded, maxLines: 3),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.poppins(fontSize: 13, color: c.red)),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _editing = false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: c.textSec)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submitEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text('Submit for Review',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (status) {
      'approved' => c.green,
      'rejected' => c.red,
      _          => c.amber,
    };
    final icon = switch (status) {
      'approved' => Icons.verified_rounded,
      'rejected' => Icons.cancel_rounded,
      _          => Icons.hourglass_top_rounded,
    };
    final label = switch (status) {
      'approved' => 'Verified Doctor',
      'rejected' => 'Verification Rejected',
      _          => 'Verification Pending',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String message;
  const _Banner({required this.color, required this.icon,
      required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                if (message.isNotEmpty)
                  Text(message,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: color, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialCard extends StatelessWidget {
  final ThemeColors c;
  final List<_FieldRow> fields;
  const _CredentialCard({required this.c, required this.fields});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: fields.map((f) {
          final isLast = f == fields.last;
          return Column(
            children: [
              _buildRow(f, c),
              if (!isLast) Divider(height: 20, color: c.borderLight, thickness: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRow(_FieldRow f, ThemeColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(f.icon, size: 16, color: c.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.label,
                  style: GoogleFonts.poppins(fontSize: 11, color: c.textMuted)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(f.current,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary)),
                  ),
                  if (f.pending != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.amber.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.amber.withAlpha(60)),
                      ),
                      child: Text('Pending',
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: c.amber)),
                    ),
                  ],
                ],
              ),
              if (f.pending != null && f.pending!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('→ ${f.pending}',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: c.amber,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldRow {
  final String label;
  final IconData icon;
  final String current;
  final String? pending;
  const _FieldRow({
    required this.label,
    required this.icon,
    required this.current,
    this.pending,
  });
}

class _EditField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _EditField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.poppins(fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
            prefixIcon: Icon(icon, color: c.textMuted, size: 18),
            filled: true, fillColor: c.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: c.accent, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: c.red)),
          ),
        ),
      ],
    );
  }
}
