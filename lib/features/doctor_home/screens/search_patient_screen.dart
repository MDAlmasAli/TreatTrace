import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../services/doctor_patient_link_service.dart';
import '../models/doctor_patient_link.dart';

class SearchPatientScreen extends StatefulWidget {
  const SearchPatientScreen({super.key});

  @override
  State<SearchPatientScreen> createState() => _SearchPatientScreenState();
}

class _SearchPatientScreenState extends State<SearchPatientScreen> {
  final _svc        = DoctorPatientLinkService();
  final _ctrl       = TextEditingController();

  bool   _searching  = false;
  bool   _sending    = false;
  bool   _searched   = false;

  Map<String, dynamic>? _result;
  DoctorPatientLink?    _existingLink;
  String?               _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;

    setState(() { _searching = true; _error = null; _result = null; _existingLink = null; _searched = false; });
    try {
      final found = await _svc.searchPatient(q);
      if (found != null) {
        final link = await _svc.getLinkStatus(found['id'] as String);
        setState(() { _result = found; _existingLink = link; });
      }
      setState(() { _searched = true; });
    } catch (e) {
      setState(() => _error = 'Search failed. Please try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest() async {
    final patientId = _result?['id'] as String?;
    if (patientId == null) return;
    setState(() => _sending = true);
    try {
      await _svc.sendRequest(patientId);
      final link = await _svc.getLinkStatus(patientId);
      if (mounted) {
        setState(() => _existingLink = link);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link request sent!', style: GoogleFonts.poppins()),
            backgroundColor: context.colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request.', style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search by phone number, @username, or User ID.',
                    style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 20),

                  // Search field
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.border),
                          ),
                          child: TextField(
                            controller: _ctrl,
                            style: GoogleFonts.poppins(fontSize: 14, color: c.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Phone, @username, or User ID',
                              hintStyle: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                              prefixIcon: Icon(Icons.search_rounded, color: c.accent, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onSubmitted: (_) => _search(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _searching ? null : _search,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _searching
                              ? const Center(child: SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                              : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 150.ms),

                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    _ErrorBanner(message: _error!),
                  ],

                  if (_searched && _result == null && _error == null) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.person_search_rounded, size: 56, color: c.textMuted),
                          const SizedBox(height: 16),
                          Text('No patient found.', style: GoogleFonts.poppins(fontSize: 15, color: c.textSec, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Try the exact phone number,\n@username, or the patient\'s user ID.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
                        ],
                      ),
                    ).animate().fadeIn(),
                  ],

                  if (_result != null) ...[
                    const SizedBox(height: 28),
                    Text('Patient Found', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary))
                        .animate().fadeIn(),
                    const SizedBox(height: 12),
                    _PatientResultCard(
                      result:       _result!,
                      existingLink: _existingLink,
                      sending:      _sending,
                      onSend:       _sendRequest,
                    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
                  ],
                ],
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
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      padding: EdgeInsets.only(top: topPad + 16, left: 20, right: 20, bottom: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
              child: Icon(Icons.arrow_back_rounded, color: c.textSec, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Text('Search Patient', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _PatientResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final DoctorPatientLink?   existingLink;
  final bool                 sending;
  final VoidCallback         onSend;

  const _PatientResultCard({
    required this.result,
    required this.existingLink,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final name     = result['full_name'] as String? ?? 'Unknown';
    final phone    = result['phone']     as String? ?? '—';
    final username = result['username']  as String?;
    final avatar   = result['avatar_url'] as String?;

    final link = existingLink;
    final isPending  = link?.isPending  ?? false;
    final isAccepted = link?.isAccepted ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAccepted ? c.green.withAlpha(100) : c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: c.accent.withAlpha(20),
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null ? Icon(Icons.person_rounded, color: c.accent, size: 28) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(phone, style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
                    if (username?.isNotEmpty == true) ...[
                      const SizedBox(height: 1),
                      Text('@$username', style: GoogleFonts.poppins(fontSize: 12, color: c.accent, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              if (isAccepted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.green.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                  child: Text('Linked', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: c.green)),
                ),
              if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.amber.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                  child: Text('Pending', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: c.amber)),
                ),
            ],
          ),

          if (!isAccepted && !isPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.link_rounded, size: 18),
                label: Text(sending ? 'Sending...' : 'Send Link Request',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.red.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.red.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: c.red, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12, color: c.red))),
        ],
      ),
    );
  }
}
