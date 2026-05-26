import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/doctor_verification_service.dart';
import '../../../core/services/reminder_service.dart';
import '../../appointment/services/appointment_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../services/doctor_patient_link_service.dart';
import 'doctor_today_schedule_screen.dart';
import 'my_patients_screen.dart';
import 'search_patient_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  final void Function(String) onThemeChanged;
  final void Function(String) onLocaleChanged;
  final String currentTheme;
  final String currentLocale;
  final String verificationStatus;

  const DoctorHomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.currentTheme,
    required this.currentLocale,
    this.verificationStatus = 'approved',
  });

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final _authService = AuthService();
  final _apptSvc     = AppointmentService();
  final _linkSvc     = DoctorPatientLinkService();
  final _verifySvc   = DoctorVerificationService();

  String? _avatarUrl;
  int _todayAppointments = 0;
  int _totalPatients = 0;
  int _pendingTasks = 0;

  List<Map<String, dynamic>> _patientRequests = [];
  int?    _visitingFee;
  String? _visitingHours;
  String? _chamber;
  RealtimeChannel? _apptChannel;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadDashboardStats();
    _loadPendingRequests();
    _loadVisitingInfo();
    _subscribeToAppointments();
    _handleLaunchNotification();
  }

  @override
  void dispose() {
    _apptChannel?.unsubscribe();
    ReminderService.onNotificationTapped = null;
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final profile = await _authService.fetchProfile();
    if (mounted) setState(() => _avatarUrl = profile?['avatar_url'] as String?);
  }

  // ── Realtime: subscribe to new appointments for this doctor ──────────────

  void _subscribeToAppointments() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _apptChannel = Supabase.instance.client
        .channel('doctor_appts_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'doctor_user_id',
            value: uid,
          ),
          callback: (payload) => _onNewAppointment(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _onNewAppointment(Map<String, dynamic> record) async {
    final userId = record['user_id'] as String?;
    final date = (record['appointment_date'] as String?) ?? '';

    String patientName = 'A patient';
    if (userId != null) {
      try {
        final row = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        patientName = (row?['full_name'] as String?) ?? 'A patient';
      } catch (_) {}
    }

    await ReminderService().showAppointmentNotification(
      patientName: patientName,
      appointmentDate: date,
      payload: 'appointment:${userId ?? ''}',
    );

    if (mounted) {
      _loadDashboardStats();
      _loadPendingRequests();
    }
  }

  // ── Notification tap handler ──────────────────────────────────────────────

  void _handleLaunchNotification() async {
    ReminderService.onNotificationTapped = _navigateFromNotification;
    final payload = await ReminderService().getLaunchPayload();
    if (payload != null && payload.startsWith('appointment:')) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _navigateFromNotification(payload),
      );
    }
  }

  void _navigateFromNotification(String? payload) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchPatientScreen()),
    );
  }

  // ── Patient Requests: patients who booked appointments but aren't linked ──

  Future<void> _loadVisitingInfo() async {
    try {
      final data = await _verifySvc.fetchMyVerification();
      if (!mounted || data == null) return;
      setState(() {
        _visitingFee   = data['visiting_fee']   as int?;
        _visitingHours = data['visiting_hours'] as String?;
        _chamber       = data['chamber']        as String?;
      });
    } catch (_) {}
  }

  Future<void> _loadPendingRequests() async {
    try {
      final requests = await _linkSvc.fetchPatientRequests();
      if (mounted) setState(() => _patientRequests = requests);
    } catch (_) {}
  }

  Future<void> _handlePatientRequestAction(
      BuildContext ctx, Map<String, dynamic> data) async {
    final c = ctx.colors;
    final name = (data['full_name'] as String?) ?? 'this patient';
    final patientId = data['id'] as String;
    final linkStatus = data['link_status'] as String?;
    final linkId = data['link_id'] as String?;

    // Already sent — show status sheet with cancel option
    if (linkStatus == 'pending') {
      await showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: Colors.transparent,
        builder: (_) => _RequestStatusSheet(
          name: name,
          avatarUrl: data['avatar_url'] as String?,
          onCancel: () async {
            Navigator.of(ctx).pop();
            if (linkId != null) await _linkSvc.revokeLink(linkId);
            _loadPendingRequests();
          },
        ),
      );
      return;
    }

    // Not sent yet (or rejected) — confirm then send request
    final send = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text('Send Link Request',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: c.textPrimary)),
        content: Text(
          'Send a link request to $name?\n\nThey will be able to accept or reject it from their My Doctors page.',
          style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text('Send Request',
                style: GoogleFonts.poppins(
                    color: c.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (send == true && mounted) {
      try {
        await _linkSvc.sendRequest(patientId);
        _loadPendingRequests();
      } catch (_) {}
    }
  }

  String get _firstName {
    final meta = _authService.currentUser?.userMetadata;
    final full = meta?['full_name'] as String?;
    return full?.split(' ').first ?? 'Doctor';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _showVisitingInfoSheet() async {
    final c = context.colors;
    final feeCtrl     = TextEditingController(text: _visitingFee?.toString() ?? '');
    final hoursCtrl   = TextEditingController(text: _visitingHours ?? '');
    final chamberCtrl = TextEditingController(text: _chamber ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          bool saving = false;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: c.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.schedule_rounded, color: c.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Visiting Information',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SheetField(
                    label: 'Visiting Fee (BDT)',
                    hint: 'e.g. 500',
                    controller: feeCtrl,
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    c: c,
                  ),
                  const SizedBox(height: 14),
                  _SheetField(
                    label: 'Visiting Hours',
                    hint: 'e.g. Sat–Thu 9am–5pm',
                    controller: hoursCtrl,
                    icon: Icons.access_time_rounded,
                    c: c,
                  ),
                  const SizedBox(height: 14),
                  _SheetField(
                    label: 'Chamber / Location',
                    hint: 'e.g. Room 203, City Hospital',
                    controller: chamberCtrl,
                    icon: Icons.location_on_rounded,
                    c: c,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: StatefulBuilder(
                      builder: (ctx2, setSave) => ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setSave(() => saving = true);
                                try {
                                  final fee = int.tryParse(feeCtrl.text.trim());
                                  await _verifySvc.updateVisitingInfo(
                                    fee:     fee,
                                    hours:   hoursCtrl.text,
                                    chamber: chamberCtrl.text,
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _visitingFee   = fee;
                                    _visitingHours = hoursCtrl.text.trim().isEmpty
                                        ? null : hoursCtrl.text.trim();
                                    _chamber       = chamberCtrl.text.trim().isEmpty
                                        ? null : chamberCtrl.text.trim();
                                  });
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                } catch (_) {
                                  if (ctx2.mounted) setSave(() => saving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Text('Save',
                                style: GoogleFonts.poppins(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    feeCtrl.dispose();
    hoursCtrl.dispose();
    chamberCtrl.dispose();
  }

  Future<void> _goMyPatients() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MyPatientsScreen()));
    _loadDashboardStats();
  }

  Future<void> _goTodaySchedule() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DoctorTodayScheduleScreen()),
    );
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final results = await Future.wait([
        _apptSvc.countTodayForCurrentDoctor(),
        _linkSvc.fetchLinkedPatients(),
        _linkSvc.fetchOutgoingRequests(),
      ]);
      final today = results[0] as int;
      final linked = results[1] as List;
      final outgoing = results[2] as List;
      final pending = outgoing
          .where((row) => (row as dynamic).status == 'pending')
          .length;
      if (!mounted) return;
      setState(() {
        _todayAppointments = today;
        _totalPatients = linked.length;
        _pendingTasks = pending;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todayAppointments = 0;
        _totalPatients = 0;
        _pendingTasks = 0;
      });
    }
  }

  Future<void> _goToProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          onThemeChanged: widget.onThemeChanged,
          onLocaleChanged: widget.onLocaleChanged,
          currentTheme: widget.currentTheme,
          currentLocale: widget.currentLocale,
        ),
      ),
    );
    _loadAvatar();
  }

  Future<void> _confirmLogout() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Log Out',
              style: GoogleFonts.poppins(
                color: c.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.statusBarIconBrightness,
      ),
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _DoctorHeader(
            greeting: _greeting,
            firstName: _firstName,
            onLogout: _confirmLogout,
            verificationStatus: widget.verificationStatus,
          ),
          Expanded(
            child: widget.verificationStatus == 'pending'
                ? _PendingBody()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatsRow(
                          todayAppointments: _todayAppointments,
                          totalPatients: _totalPatients,
                          pendingTasks: _pendingTasks,
                        ).animate().fadeIn(delay: 100.ms),

                        const SizedBox(height: 28),

                        Text(
                          'Quick Actions',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ).animate().fadeIn(delay: 140.ms),

                        const SizedBox(height: 16),

                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child:
                                    _ActionCard(
                                          icon: Icons.calendar_today_rounded,
                                          label: "Today's Schedule",
                                          subtitle: 'View appointments',
                                          accentColor: c.accent,
                                          onTap: _goTodaySchedule,
                                        )
                                        .animate()
                                        .fadeIn(delay: 180.ms)
                                        .slideY(begin: 0.08),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child:
                                    _ActionCard(
                                          icon: Icons.people_alt_rounded,
                                          label: 'My Patients',
                                          subtitle: 'Patient records',
                                          accentColor: c.green,
                                          onTap: _goMyPatients,
                                        )
                                        .animate()
                                        .fadeIn(delay: 220.ms)
                                        .slideY(begin: 0.08),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        _ActionCard(
                          icon: Icons.edit_document,
                          label: 'Write Prescription',
                          subtitle: 'Select a patient to write',
                          accentColor: c.amber,
                          onTap: _goMyPatients,
                          fullWidth: true,
                        ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.08),

                        const SizedBox(height: 32),

                        // ── Visiting Information ──────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Visiting Information',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: _showVisitingInfoSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: c.accent.withAlpha(15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: c.accent.withAlpha(40)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded, size: 13, color: c.accent),
                                    const SizedBox(width: 4),
                                    Text('Edit',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: c.accent)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 280.ms),

                        const SizedBox(height: 12),

                        _VisitingInfoCard(
                          fee:     _visitingFee,
                          hours:   _visitingHours,
                          chamber: _chamber,
                          onEdit:  _showVisitingInfoSheet,
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.06),

                        const SizedBox(height: 32),

                        // ── Patient Requests ──────────────────────────────
                        Row(
                          children: [
                            Text(
                              'Patient Requests',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            if (_patientRequests.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_patientRequests.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 12),

                        if (_patientRequests.isEmpty)
                          _EmptyRequests()
                              .animate()
                              .fadeIn(delay: 340.ms)
                        else
                          ..._patientRequests.asMap().entries.map((e) {
                            return _PatientRequestTile(
                              data: e.value,
                              onAction: () => _handlePatientRequestAction(
                                  context, e.value),
                            )
                                .animate()
                                .fadeIn(delay: (340 + e.key * 40).ms)
                                .slideY(begin: 0.06);
                          }),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _DoctorBottomBar(
        onProfileTap: _goToProfile,
        avatarUrl: _avatarUrl,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DoctorHeader
// ══════════════════════════════════════════════════════════════════════════════
class _DoctorHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final VoidCallback onLogout;
  final String verificationStatus;

  const _DoctorHeader({
    required this.greeting,
    required this.firstName,
    required this.onLogout,
    required this.verificationStatus,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            border: Border(bottom: BorderSide(color: c.border, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: topPad + 18,
            left: 24,
            right: 24,
            bottom: 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: c.textSec,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dr. $firstName',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HeaderIcon(icon: Icons.notifications_outlined),
                  const SizedBox(width: 10),
                  _HeaderIcon(icon: Icons.logout_rounded, onTap: onLogout),
                ],
              ),
              const SizedBox(height: 20),
              // Verification status badge
              _VerificationBadge(status: verificationStatus),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.06, end: 0, duration: 500.ms);
  }
}

class _VerificationBadge extends StatelessWidget {
  final String status;
  const _VerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPending = status == 'pending';
    final badgeColor = isPending ? c.amber : c.green;
    final icon = isPending
        ? Icons.hourglass_top_rounded
        : Icons.verified_rounded;
    final label = isPending
        ? 'Pending Verification'
        : 'Verified Healthcare Professional';
    final badge = isPending ? 'Pending' : 'Doctor';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.amber.withAlpha(15),
                shape: BoxShape.circle,
                border: Border.all(color: c.amber.withAlpha(50)),
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                color: c.amber,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Verification Pending',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your medical credentials are under review by our admin team. '
              'You will get full access once approved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: c.textSec,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Icon(icon, color: c.textSec, size: 21),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _StatsRow
// ══════════════════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  final int todayAppointments;
  final int totalPatients;
  final int pendingTasks;

  const _StatsRow({
    required this.todayAppointments,
    required this.totalPatients,
    required this.pendingTasks,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            icon: Icons.event_available_rounded,
            label: "Today's\nAppointments",
            value: '$todayAppointments',
            color: context.colors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatPill(
            icon: Icons.people_alt_rounded,
            label: 'Total\nPatients',
            value: '$totalPatients',
            color: context.colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatPill(
            icon: Icons.pending_actions_rounded,
            label: 'Pending\nTasks',
            value: '$pendingTasks',
            color: context.colors.amber,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: c.textSec,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ActionCard
// ══════════════════════════════════════════════════════════════════════════════
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.fullWidth = false,
  });

  Widget _arrowBox(Color color) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(Icons.arrow_forward_rounded, size: 16, color: color),
      );

  Widget _iconBox(Color color) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40), width: 1),
        ),
        child: Icon(icon, color: color, size: 26),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final inner = fullWidth
        // Horizontal layout — no Spacer needed, works without bounded height
        ? Row(
            children: [
              _iconBox(accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: c.textSec),
                    ),
                  ],
                ),
              ),
              _arrowBox(accentColor),
            ],
          )
        // Vertical layout — must be inside IntrinsicHeight for Spacer to work
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(accentColor),
              const SizedBox(height: 14),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 11, color: c.textSec),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: _arrowBox(accentColor),
              ),
            ],
          );

    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        splashColor: accentColor.withAlpha(15),
        highlightColor: accentColor.withAlpha(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: inner,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _EmptyRequests
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyRequests extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 36, color: c.textSec.withAlpha(80)),
          const SizedBox(height: 10),
          Text(
            'No pending requests',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: c.textSec,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use Search Patient to send a link request',
            style: GoogleFonts.poppins(fontSize: 11, color: c.textSec),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PatientRequestTile
// data keys: id, full_name, phone, avatar_url, link_status, link_id
// link_status: null = not sent, 'pending' = sent, 'rejected' = rejected
// ══════════════════════════════════════════════════════════════════════════════
class _PatientRequestTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAction;

  const _PatientRequestTile({required this.data, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = (data['full_name'] as String?) ?? 'Unknown Patient';
    final phone = data['phone'] as String?;
    final avatarUrl = data['avatar_url'] as String?;
    final linkStatus = data['link_status'] as String?;

    final Color badgeColor;
    final String badgeLabel;
    if (linkStatus == 'pending') {
      badgeColor = c.amber;
      badgeLabel = 'Pending';
    } else if (linkStatus == 'rejected') {
      badgeColor = c.red;
      badgeLabel = 'Resend';
    } else {
      badgeColor = c.accent;
      badgeLabel = 'Link';
    }

    return GestureDetector(
      onTap: onAction,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.accent.withAlpha(15),
                shape: BoxShape.circle,
                border: Border.all(color: c.accent.withAlpha(40)),
              ),
              child: avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) =>
                            Icon(Icons.person_rounded, color: c.accent, size: 22),
                      ),
                    )
                  : Icon(Icons.person_rounded, color: c.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  if (phone != null) ...[
                    const SizedBox(height: 2),
                    Text(phone,
                        style:
                            GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withAlpha(60)),
              ),
              child: Text(
                badgeLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: c.textSec, size: 18),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _RequestStatusSheet — shown when doctor taps a 'pending' request
// ══════════════════════════════════════════════════════════════════════════════
class _RequestStatusSheet extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final VoidCallback onCancel;

  const _RequestStatusSheet({
    required this.name,
    required this.avatarUrl,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.amber.withAlpha(15),
              shape: BoxShape.circle,
              border: Border.all(color: c.amber.withAlpha(50)),
            ),
            child: avatarUrl != null
                ? ClipOval(
                    child: Image.network(avatarUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, e, s) =>
                            Icon(Icons.person_rounded, color: c.amber, size: 30)),
                  )
                : Icon(Icons.person_rounded, color: c.amber, size: 30),
          ),
          const SizedBox(height: 14),
          Text(name,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Link request sent. Waiting for $name to accept from their My Doctors page.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: c.textSec, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.red,
                side: BorderSide(color: c.red.withAlpha(120)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text('Cancel Request',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close',
                style: GoogleFonts.poppins(color: c.textSec, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DoctorBottomBar
// ══════════════════════════════════════════════════════════════════════════════
class _DoctorBottomBar extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final String? avatarUrl;

  const _DoctorBottomBar({this.onProfileTap, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomPad + 14,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        border: Border(top: BorderSide(color: c.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Doctor badge
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medical_services_rounded,
                    color: c.green,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Doctor Portal',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Profile button
          GestureDetector(
            onTap: onProfileTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: avatarUrl != null
                          ? c.accent.withAlpha(120)
                          : c.border,
                      width: avatarUrl != null ? 1.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => Icon(
                              Icons.person_rounded,
                              color: c.accent,
                              size: 22,
                            ),
                          )
                        : Icon(Icons.person_rounded, color: c.accent, size: 22),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'My\nProfile',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: c.textSec,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.06);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _VisitingInfoCard
// ══════════════════════════════════════════════════════════════════════════════
class _VisitingInfoCard extends StatelessWidget {
  final int?     fee;
  final String?  hours;
  final String?  chamber;
  final VoidCallback onEdit;

  const _VisitingInfoCard({
    this.fee,
    this.hours,
    this.chamber,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasData = fee != null ||
        (hours?.isNotEmpty == true) ||
        (chamber?.isNotEmpty == true);

    if (!hasData) {
      return GestureDetector(
        onTap: onEdit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              Icon(Icons.schedule_rounded, size: 32,
                  color: c.textSec.withAlpha(80)),
              const SizedBox(height: 8),
              Text('No visiting info yet',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: c.textSec,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Tap Edit to add your visiting hours, fee, and chamber',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 11, color: c.textSec)),
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[];
    if (fee != null) {
      rows.add(_InfoRow(
        icon: Icons.payments_rounded,
        label: 'Visiting Fee',
        value: 'BDT $fee',
        color: c.green,
        c: c,
      ));
    }
    if (hours?.isNotEmpty == true) {
      if (rows.isNotEmpty) {
        rows.add(Divider(height: 1, color: c.border, indent: 16, endIndent: 16));
      }
      rows.add(_InfoRow(
        icon: Icons.access_time_rounded,
        label: 'Visiting Hours',
        value: hours!,
        color: c.accent,
        c: c,
      ));
    }
    if (chamber?.isNotEmpty == true) {
      if (rows.isNotEmpty) {
        rows.add(Divider(height: 1, color: c.border, indent: 16, endIndent: 16));
      }
      rows.add(_InfoRow(
        icon: Icons.location_on_rounded,
        label: 'Chamber',
        value: chamber!,
        color: c.amber,
        c: c,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: rows),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData    icon;
  final String      label;
  final String      value;
  final Color       color;
  final ThemeColors c;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
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
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SheetField — text field used inside the visiting info bottom sheet
// ══════════════════════════════════════════════════════════════════════════════
class _SheetField extends StatelessWidget {
  final String             label;
  final String?            hint;
  final TextEditingController controller;
  final IconData           icon;
  final TextInputType?     keyboardType;
  final ThemeColors        c;

  const _SheetField({
    required this.label,
    this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
            prefixIcon: Icon(icon, color: c.textMuted, size: 18),
            filled: true,
            fillColor: c.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.accent, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
