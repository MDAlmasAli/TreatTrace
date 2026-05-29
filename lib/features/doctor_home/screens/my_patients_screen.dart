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
  final _svc        = DoctorPatientLinkService();
  final _searchCtrl = TextEditingController();

  List<DoctorPatientLink> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _patients = await _svc.fetchLinkedPatients();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DoctorPatientLink> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _patients;
    return _patients.where((p) {
      final name     = (p.patientName     ?? '').toLowerCase();
      final username = (p.patientUsername ?? '').toLowerCase();
      final phone    = (p.patientPhone    ?? '').toLowerCase();
      return name.contains(q) || username.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c, filtered.length),

          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Container(
              decoration: BoxDecoration(
                color:        c.card,
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: c.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                style:      GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText:       'Search by name, username or phone…',
                  hintStyle:      GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                  prefixIcon:     Icon(Icons.search_rounded, color: c.textSec, size: 20),
                  suffixIcon:     _searchCtrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => _searchCtrl.clear()),
                          child: Icon(Icons.close_rounded, color: c.textMuted, size: 18),
                        )
                      : null,
                  border:         InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5))
                : _patients.isEmpty
                    ? _EmptyState(isSearch: false)
                    : filtered.isEmpty
                        ? _EmptyState(isSearch: true)
                        : RefreshIndicator(
                            color: c.accent,
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) => _PatientTile(
                                link:  filtered[i],
                                query: _searchCtrl.text.trim(),
                                onTap: () => _openPatient(filtered[i]),
                              ).animate().fadeIn(delay: Duration(milliseconds: 40 * i)).slideY(begin: 0.05),
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

  Widget _buildHeader(ThemeColors c, int filteredCount) {
    final topPad    = MediaQuery.of(context).padding.top;
    final isFiltered = _searchCtrl.text.trim().isNotEmpty;
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
            child: Text(
              isFiltered ? '$filteredCount / ${_patients.length}' : '${_patients.length}',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: c.green),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _PatientTile extends StatelessWidget {
  final DoctorPatientLink link;
  final String            query;
  final VoidCallback      onTap;

  const _PatientTile({required this.link, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final name     = link.patientName     ?? 'Unknown Patient';
    final username = link.patientUsername;
    final phone    = link.patientPhone    ?? '—';
    final avatar   = link.patientAvatarUrl;

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
                  _HighlightText(text: name, query: query,
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (username != null && username.isNotEmpty) ...[
                        _HighlightText(
                          text:  '@$username',
                          query: query,
                          style: GoogleFonts.poppins(fontSize: 11, color: c.accent, fontWeight: FontWeight.w500),
                        ),
                        Text('  ·  ', style: GoogleFonts.poppins(fontSize: 11, color: c.textMuted)),
                      ],
                      _HighlightText(text: phone, query: query,
                          style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
                    ],
                  ),
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

// Highlights the matched portion of [text] in accent colour.
class _HighlightText extends StatelessWidget {
  final String     text;
  final String     query;
  final TextStyle  style;
  const _HighlightText({required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (query.isEmpty) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);

    final lower  = text.toLowerCase();
    final q      = query.toLowerCase();
    final start  = lower.indexOf(q);
    if (start == -1) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);

    final end    = start + q.length;
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: style, children: [
        if (start > 0) TextSpan(text: text.substring(0, start)),
        TextSpan(
          text:  text.substring(start, end),
          style: style.copyWith(
            color:      c.accent,
            background: Paint()..color = c.accent.withAlpha(20),
          ),
        ),
        if (end < text.length) TextSpan(text: text.substring(end)),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSearch;
  const _EmptyState({required this.isSearch});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.people_alt_outlined,
            size: 64, color: c.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'No patients found' : 'No patients yet',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSec),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch
                ? 'Try a different name, username\nor phone number.'
                : 'Search for a patient and\nsend a link request.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
          ),
        ],
      ).animate().fadeIn(),
    );
  }
}
