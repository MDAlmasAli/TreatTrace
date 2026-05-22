import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../models/doctor_patient_link.dart';
import '../services/doctor_patient_link_service.dart';
import 'patient_detail_screen.dart';

class MyPatientsScreen extends StatefulWidget {
  const MyPatientsScreen({super.key});

  @override
  State<MyPatientsScreen> createState() => _MyPatientsScreenState();
}

class _MyPatientsScreenState extends State<MyPatientsScreen> {
  final _svc = DoctorPatientLinkService();

  List<DoctorPatientLink> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _patients = await _svc.fetchLinkedPatients();
    } finally {
      if (mounted) setState(() => _loading = false);
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
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5))
                : _patients.isEmpty
                    ? _EmptyState()
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                          itemCount: _patients.length,
                          itemBuilder: (context, i) => _PatientTile(
                            link: _patients[i],
                            onTap: () => _openPatient(_patients[i]),
                          ).animate().fadeIn(delay: Duration(milliseconds: 60 * i)).slideY(begin: 0.06),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPatient(DoctorPatientLink link) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(
          patientId:   link.patientId,
          patientName: link.patientName ?? 'Patient',
          patientPhone: link.patientPhone,
          patientAvatarUrl: link.patientAvatarUrl,
        ),
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
          Expanded(
            child: Text('My Patients', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: c.green.withAlpha(20), borderRadius: BorderRadius.circular(20)),
            child: Text('${_patients.length}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: c.green)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _PatientTile extends StatelessWidget {
  final DoctorPatientLink link;
  final VoidCallback       onTap;

  const _PatientTile({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final name  = link.patientName   ?? 'Unknown Patient';
    final phone = link.patientPhone  ?? '—';
    final avatar = link.patientAvatarUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: c.accent.withAlpha(20),
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null ? Icon(Icons.person_rounded, color: c.accent, size: 24) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(phone, style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
                ],
              ),
            ),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: c.accent.withAlpha(15), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_forward_rounded, size: 16, color: c.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_outlined, size: 64, color: c.textMuted),
          const SizedBox(height: 16),
          Text('No patients yet', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSec)),
          const SizedBox(height: 8),
          Text('Search for a patient and\nsend a link request.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted)),
        ],
      ).animate().fadeIn(),
    );
  }
}
