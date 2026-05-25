import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../models/doctor_patient_link.dart';
import '../services/doctor_patient_link_service.dart';
class LinkedDoctorsScreen extends StatefulWidget {
  const LinkedDoctorsScreen({super.key});

  @override
  State<LinkedDoctorsScreen> createState() => _LinkedDoctorsScreenState();
}

class _LinkedDoctorsScreenState extends State<LinkedDoctorsScreen> {
  final _svc = DoctorPatientLinkService();

  List<DoctorPatientLink> _all     = [];
  bool                    _loading = true;

  List<DoctorPatientLink> get _pending  => _all.where((l) => l.isPending).toList();
  List<DoctorPatientLink> get _accepted => _all.where((l) => l.isAccepted).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _all = await _svc.fetchIncomingRequests();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(DoctorPatientLink link) async {
    try {
      await _svc.acceptRequest(link.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dr. ${link.doctorName ?? "Doctor"} linked successfully!',
              style: GoogleFonts.poppins()),
          backgroundColor: context.colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed. Please try again.', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _reject(DoctorPatientLink link) async {
    try {
      await _svc.rejectRequest(link.id);
      await _load();
    } catch (_) {}
  }

  void _showAddDoctorInfo() {
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('How to Add a Doctor',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: c.textPrimary)),
        content: Text(
          'Doctors can find and link with you from the TreatTrace Doctor Portal.\n\n'
          'Share your registered phone number or username with your doctor so they can send you a link request.',
          style: GoogleFonts.poppins(fontSize: 13, color: c.textSec, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Got it', style: GoogleFonts.poppins(color: c.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(DoctorPatientLink link) async {
    final c  = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove Doctor', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: c.textPrimary)),
        content: Text(
          'Remove Dr. ${link.doctorName ?? "this doctor"} from your linked doctors?\nThey will no longer see your health data.',
          style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: GoogleFonts.poppins(color: c.textSec))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true),  child: Text('Remove', style: GoogleFonts.poppins(color: c.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      await _svc.removeLink(link.id);
      await _load();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDoctorInfo,
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Doctor', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      body: Column(
        children: [
          _buildHeader(c),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5))
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: _buildBody(c),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeColors c) {
    if (_all.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.link_off_rounded, size: 64, color: c.textMuted),
                const SizedBox(height: 16),
                Text('No linked doctors', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSec)),
                const SizedBox(height: 8),
                Text('Doctors can request to\nlink with your account.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted)),
              ],
            ).animate().fadeIn(),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (_pending.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.notifications_active_rounded,
            title: 'Pending Requests',
            count: _pending.length,
            color: c.amber,
          ),
          const SizedBox(height: 12),
          ..._pending.asMap().entries.map((e) => _DoctorRequestTile(
                link:     e.value,
                onAccept: () => _accept(e.value),
                onReject: () => _reject(e.value),
              ).animate().fadeIn(delay: Duration(milliseconds: 60 * e.key)).slideY(begin: 0.06)),
          const SizedBox(height: 24),
        ],

        if (_accepted.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.verified_rounded,
            title: 'Linked Doctors',
            count: _accepted.length,
            color: c.green,
          ),
          const SizedBox(height: 12),
          ..._accepted.asMap().entries.map((e) => _LinkedDoctorTile(
                link:     e.value,
                onRevoke: () => _revoke(e.value),
              ).animate().fadeIn(delay: Duration(milliseconds: 60 * e.key)).slideY(begin: 0.06)),
        ],
      ],
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
          Text('My Doctors', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
          if (_pending.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.amber, borderRadius: BorderRadius.circular(20)),
              child: Text('${_pending.length} new', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final int      count;
  final Color    color;

  const _SectionHeader({required this.icon, required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class _DoctorRequestTile extends StatelessWidget {
  final DoctorPatientLink link;
  final VoidCallback       onAccept;
  final VoidCallback       onReject;

  const _DoctorRequestTile({required this.link, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final name   = link.doctorName ?? 'Unknown Doctor';
    final avatar = link.doctorAvatarUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.amber.withAlpha(80)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: c.green.withAlpha(20),
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null ? Icon(Icons.medical_services_rounded, color: c.green, size: 22) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. $name', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    Text('Wants to link with you', style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.red,
                    side: BorderSide(color: c.red.withAlpha(100)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Reject', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Accept', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkedDoctorTile extends StatelessWidget {
  final DoctorPatientLink link;
  final VoidCallback       onRevoke;

  const _LinkedDoctorTile({required this.link, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final name   = link.doctorName ?? 'Unknown Doctor';
    final avatar = link.doctorAvatarUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.green.withAlpha(60)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.green.withAlpha(20),
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null ? Icon(Icons.medical_services_rounded, color: c.green, size: 22) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. $name', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: c.green),
                    const SizedBox(width: 4),
                    Text('Linked', style: GoogleFonts.poppins(fontSize: 11, color: c.green, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRevoke,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.red.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.red.withAlpha(60)),
              ),
              child: Text('Remove', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: c.red)),
            ),
          ),
        ],
      ),
    );
  }
}
