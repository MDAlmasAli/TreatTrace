import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../appointment/screens/add_edit_appointment_screen.dart';
import '../../doctor/models/doctor.dart';
import '../../doctor/services/doctor_service.dart';
import '../../doctor_home/services/doctor_patient_link_service.dart';

class DoctorPublicProfileScreen extends StatefulWidget {
  final String  doctorId;
  final String? initialName;
  final String? initialAvatarUrl;

  const DoctorPublicProfileScreen({
    super.key,
    required this.doctorId,
    this.initialName,
    this.initialAvatarUrl,
  });

  @override
  State<DoctorPublicProfileScreen> createState() =>
      _DoctorPublicProfileScreenState();
}

class _DoctorPublicProfileScreenState
    extends State<DoctorPublicProfileScreen> {
  final _linkSvc   = DoctorPatientLinkService();
  final _doctorSvc = DoctorService();

  Map<String, dynamic>? _profile;
  bool _loading          = true;
  bool _addingMyDoctor   = false;
  bool _alreadyInMyDocs  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _linkSvc.fetchDoctorPublicProfile(widget.doctorId),
      _doctorSvc.fetchAll(),
    ]);

    final profile   = results[0] as Map<String, dynamic>?;
    final myDoctors = results[1] as List<Doctor>;

    final alreadyIn = myDoctors.any((d) => d.sourceId == widget.doctorId);

    if (mounted) {
      setState(() {
        _profile        = profile;
        _alreadyInMyDocs = alreadyIn;
        _loading        = false;
      });
    }
  }

  Future<void> _addToMyDoctors() async {
    if (_addingMyDoctor || _alreadyInMyDocs || _profile == null) return;
    setState(() => _addingMyDoctor = true);
    try {
      final d = _profile!;
      await _doctorSvc.create(
        Doctor(
          id:        '',
          userId:    '',
          name:      ((d['full_name'] as String?)?.trim().isNotEmpty == true
              ? d['full_name'] as String
              : 'Unknown'),
          specialty: (d['specialty'] as String?)?.trim(),
          hospital:  (d['hospital'] as String?)?.trim(),
          imageUrl:  d['avatar_url'] as String?,
          sourceId:  widget.doctorId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _alreadyInMyDocs = true;
        _addingMyDoctor  = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Doctor added to My Doctors.', style: GoogleFonts.poppins()),
        backgroundColor: context.colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _addingMyDoctor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to add doctor.', style: GoogleFonts.poppins()),
      ));
    }
  }

  Future<void> _takeAppointment() async {
    if (_profile == null) return;
    final d    = _profile!;
    final name = (d['full_name'] as String?)?.trim();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditAppointmentScreen(
          prefilledDoctorName:     name?.isEmpty == true ? null : name,
          prefilledDoctorHospital: d['hospital'] as String?,
          prefilledDoctorUserId:   widget.doctorId,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:            Colors.transparent,
      statusBarIconBrightness:   Brightness.light,
    ));

    return Scaffold(
      backgroundColor: c.bg,
      body: _loading ? _buildLoading(c) : _buildContent(c),
    );
  }

  // ── Loading skeleton ──────────────────────────────────────────────────────

  Widget _buildLoading(ThemeColors c) {
    final topPad = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Container(height: 230 + topPad, color: c.accent),
        SafeArea(child: _backBtn(light: true)),
        const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
      ],
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────

  Widget _buildContent(ThemeColors c) {
    final d = _profile;
    if (d == null) {
      return SafeArea(
        child: Column(
          children: [
            _backBtn(light: false),
            Expanded(
              child: Center(
                child: Text('Doctor not found.', style: GoogleFonts.poppins(color: c.textSec)),
              ),
            ),
          ],
        ),
      );
    }

    final name        = d['full_name'] as String? ?? 'Unknown';
    final specialty   = d['specialty'] as String?;
    final hospital    = d['hospital']  as String?;
    final degree      = d['degree']    as String?;
    final visitingFee = d['visiting_fee'] as int?;
    final about       = d['about']     as String?;
    final email       = d['email']     as String?;
    final avatar      = d['avatar_url'] as String?;

    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return CustomScrollView(
      slivers: [
        // ── Hero ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(height: 220 + topPad, color: c.accent),
              Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _backBtn(light: true))),
              Positioned(
                bottom: -52,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.card, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: c.accent.withAlpha(20),
                      backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                      child: avatar == null
                          ? Icon(Icons.medical_services_rounded, color: c.accent, size: 46)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms),
        ),

        // ── Name + specialty + fee ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 0),
            child: Column(
              children: [
                Text(
                  'Dr. $name',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                if (specialty?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    specialty!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.accent,
                    ),
                  ),
                ],
                if (visitingFee != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.green.withAlpha(15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.green.withAlpha(55)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_rounded, size: 15, color: c.green),
                        const SizedBox(width: 6),
                        Text(
                          'Visiting Fee: BDT $visitingFee',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04),
          ),
        ),

        // ── Info card ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: _InfoCard(
              c: c,
              items: [
                if (hospital?.isNotEmpty == true)
                  (Icons.local_hospital_rounded, 'Hospital', hospital!),
                if (degree?.isNotEmpty == true)
                  (Icons.school_rounded, 'Degree', degree!),
                if (email?.isNotEmpty == true)
                  (Icons.email_outlined, 'Email', email!),
              ],
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.04),
          ),
        ),

        // ── About ─────────────────────────────────────────────────────────
        if (about?.isNotEmpty == true)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _AboutCard(c: c, about: about!).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04),
            ),
          ),

        // ── Action buttons ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, botPad + 24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addingMyDoctor || _alreadyInMyDocs
                        ? null
                        : _addToMyDoctors,
                    icon: _addingMyDoctor
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            _alreadyInMyDocs
                                ? Icons.check_circle_rounded
                                : Icons.person_add_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _alreadyInMyDocs ? 'Added to My Doctors' : 'Add to My Doctors',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _alreadyInMyDocs ? c.green.withAlpha(170) : c.green.withAlpha(120),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _takeAppointment,
                    icon: const Icon(Icons.event_available_rounded, size: 18),
                    label: Text(
                      'Take Appointment',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.04),
          ),
        ),
      ],
    );
  }

  // ── Back button ───────────────────────────────────────────────────────────

  Widget _backBtn({required bool light}) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: light ? Colors.white.withAlpha(30) : c.surface,
              borderRadius: BorderRadius.circular(12),
              border: light ? null : Border.all(color: c.border),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: light ? Colors.white : c.textSec,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Info card (hospital / degree / email) ─────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final ThemeColors c;
  final List<(IconData, String, String)> items;

  const _InfoCard({required this.c, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: c.accent),
              Expanded(
                child: Column(
                  children: items.asMap().entries.map((e) {
                    final (icon, label, value) = e.value;
                    final isLast = e.key == items.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: c.accent.withAlpha(15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, size: 18, color: c.accent),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(label,
                                        style: GoogleFonts.poppins(fontSize: 11, color: c.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(value,
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: c.textPrimary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(height: 1, indent: 16, endIndent: 16, color: c.border, thickness: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── About card ────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final ThemeColors c;
  final String about;

  const _AboutCard({required this.c, required this.about});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline_rounded, size: 18, color: c.accent),
              ),
              const SizedBox(width: 12),
              Text('About',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            about,
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec, height: 1.65),
          ),
        ],
      ),
    );
  }
}
