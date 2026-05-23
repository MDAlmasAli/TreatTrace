import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/doctor_verification_service.dart';

class DoctorVerificationSubmitScreen extends StatefulWidget {
  final VoidCallback onSubmitted;
  final String? rejectionReason;

  const DoctorVerificationSubmitScreen({
    super.key,
    required this.onSubmitted,
    this.rejectionReason,
  });

  @override
  State<DoctorVerificationSubmitScreen> createState() =>
      _DoctorVerificationSubmitScreenState();
}

class _DoctorVerificationSubmitScreenState
    extends State<DoctorVerificationSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DoctorVerificationService();

  final _bmdcCtrl       = TextEditingController();
  final _specialtyCtrl  = TextEditingController();
  final _hospitalCtrl   = TextEditingController();
  final _nidCtrl        = TextEditingController();
  final _additionalCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _bmdcCtrl.dispose();
    _specialtyCtrl.dispose();
    _hospitalCtrl.dispose();
    _nidCtrl.dispose();
    _additionalCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _service.submitVerification(
        bmdcNumber:     _bmdcCtrl.text.trim(),
        specialty:      _specialtyCtrl.text.trim(),
        hospital:       _hospitalCtrl.text.trim(),
        nidPassport:    _nidCtrl.text.trim(),
        additionalInfo: _additionalCtrl.text.trim(),
      );
      if (mounted) widget.onSubmitted();
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to submit. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isRejected = widget.rejectionReason != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header icon
                  Center(
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: c.accent.withAlpha(15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.accent.withAlpha(40)),
                      ),
                      child: Icon(Icons.verified_user_rounded, color: c.accent, size: 32),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      isRejected ? 'Resubmit Verification' : 'Doctor Verification',
                      style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Fill in your medical credentials.\nAdmin will review and approve your account.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: c.textSec, height: 1.5),
                    ),
                  ),

                  // Rejection banner
                  if (isRejected) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.red.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.red.withAlpha(60)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.cancel_rounded, color: c.red, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rejected',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: c.red)),
                                Text(widget.rejectionReason!,
                                    style: GoogleFonts.poppins(fontSize: 12, color: c.red, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  _Field(
                    label: 'BMDC Registration No.',
                    hint: 'e.g. A-12345',
                    controller: _bmdcCtrl,
                    icon: Icons.badge_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Specialty',
                    hint: 'e.g. Cardiologist, General Physician',
                    controller: _specialtyCtrl,
                    icon: Icons.medical_services_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Hospital / Clinic',
                    hint: 'Current workplace name',
                    controller: _hospitalCtrl,
                    icon: Icons.local_hospital_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'NID / Passport No.',
                    hint: 'National ID or passport number',
                    controller: _nidCtrl,
                    icon: Icons.perm_identity_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Additional Info (Optional)',
                    hint: 'Any other credentials or notes',
                    controller: _additionalCtrl,
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: GoogleFonts.poppins(fontSize: 13, color: c.red)),
                  ],

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text('Submit for Verification',
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
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
                fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.poppins(fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
            prefixIcon: Icon(icon, color: c.textMuted, size: 20),
            filled: true,
            fillColor: c.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
