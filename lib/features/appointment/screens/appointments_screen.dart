// appointments_screen.dart — Tabbed view: Upcoming / Past / Cancelled.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';
import 'add_edit_appointment_screen.dart';
import 'appointment_detail_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _service    = AppointmentService();
  final _searchCtrl = TextEditingController();
  late  TabController _tabCtrl;

  bool              _loading = true;
  List<Appointment> _all     = [];
  String            _query   = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _all = await _service.fetchAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  List<Appointment> _forTab(int tab) {
    List<Appointment> list;
    switch (tab) {
      case 0:
        list = _all.where((a) => a.isUpcoming).toList();
      case 1:
        list = _all.where((a) => a.isPast).toList();
      default:
        list = _all.where((a) => a.isCancelled).toList();
    }
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((a) {
      return a.doctorNameSnapshot.toLowerCase().contains(q) ||
          (a.visitReason?.toLowerCase().contains(q) ?? false) ||
          (a.notes?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditAppointmentScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _openDetail(Appointment a) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => AppointmentDetailScreen(appointment: a)),
    );
    if (changed == true) _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          _buildSearch(c, s),
          _buildTabs(c, s),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [0, 1, 2].map((tab) {
                if (_loading) {
                  return Center(
                    child: CircularProgressIndicator(color: c.accent),
                  );
                }
                final items = _forTab(tab);
                if (items.isEmpty) {
                  return _EmptyState(
                    message: _query.isNotEmpty
                        ? 'No results found'
                        : s.noAppointments,
                    tab: tab,
                  );
                }
                return RefreshIndicator(
                  color: c.accent,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount:        items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _AppointmentCard(
                      appt:  items[i],
                      onTap: () => _openDetail(items[i]),
                      delay: i * 40,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:       _openAdd,
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c, S s) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(8),
            blurRadius: 12,
            offset:     const Offset(0, 2),
          ),
        ],
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
          Expanded(
            child: Text(
              s.appointments,
              style: GoogleFonts.poppins(
                fontSize:   22,
                fontWeight: FontWeight.w700,
                color:      c.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        c.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: c.accent.withAlpha(60)),
            ),
            child: Text(
              '${_all.length}',
              style: GoogleFonts.poppins(
                fontSize:   12,
                fontWeight: FontWeight.w700,
                color:      c.accent,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }

  Widget _buildSearch(ThemeColors c, S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color:        c.card,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: c.border, width: 1),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged:  (v) => setState(() => _query = v.trim()),
          style:      GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
          decoration: InputDecoration(
            hintText:  s.searchAppointments,
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
            prefixIcon: Icon(Icons.search_rounded,
                color: c.accent, size: 20),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                    child: Icon(Icons.close_rounded,
                        color: c.textMuted, size: 18),
                  )
                : null,
            border:         InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(ThemeColors c, S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color:        c.card,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: c.border, width: 1),
        ),
        child: TabBar(
          controller:       _tabCtrl,
          labelColor:       Colors.white,
          unselectedLabelColor: c.textMuted,
          labelStyle:       GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          indicator: BoxDecoration(
            color:        c.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize:  TabBarIndicatorSize.tab,
          dividerColor:   Colors.transparent,
          padding:        const EdgeInsets.all(3),
          tabs: [
            Tab(text: s.upcoming),
            Tab(text: s.past),
            Tab(text: s.statusCancelled),
          ],
        ),
      ),
    );
  }
}

// ── Appointment card ──────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment  appt;
  final VoidCallback onTap;
  final int          delay;

  const _AppointmentCard({
    required this.appt,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = appt;
    final barColor = appt.status == AppointmentStatus.scheduled ? c.accent
        : appt.status == AppointmentStatus.completed ? c.green
        : c.red;

    return Material(
      color:        c.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor:  barColor.withAlpha(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withAlpha(6),
                blurRadius: 8,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: barColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Dr. ${a.doctorNameSnapshot}',
                                  style: GoogleFonts.poppins(
                                    fontSize:   15,
                                    fontWeight: FontWeight.w700,
                                    color:      c.textPrimary,
                                  ),
                                ),
                              ),
                              _StatusBadge(status: a.status),
                            ],
                          ),
                          if (a.visitReason?.isNotEmpty == true) ...[
                            const SizedBox(height: 3),
                            Text(
                              a.visitReason!,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: c.textSec),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 12, color: c.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                _fmtDate(a.appointmentDate),
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: c.textMuted),
                              ),
                              if (a.appointmentTime?.isNotEmpty == true) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.access_time_rounded,
                                    size: 12, color: c.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  a.appointmentTime!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: c.textMuted),
                                ),
                              ],
                              if (a.prescriptionIds.isNotEmpty ||
                                  a.testReportIds.isNotEmpty) ...[
                                const Spacer(),
                                if (a.prescriptionIds.isNotEmpty)
                                  Icon(Icons.link_rounded,
                                      size: 12, color: c.purpleBright),
                                if (a.testReportIds.isNotEmpty) ...[
                                  if (a.prescriptionIds.isNotEmpty)
                                    const SizedBox(width: 4),
                                  Icon(Icons.science_rounded,
                                      size: 12, color: c.cyan),
                                ],
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(Icons.chevron_right_rounded,
                        color: c.textMuted, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideY(begin: 0.06);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

class _StatusBadge extends StatelessWidget {
  final AppointmentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final label = status == AppointmentStatus.scheduled
        ? s.statusScheduled
        : status == AppointmentStatus.completed
            ? s.statusCompleted
            : s.statusCancelled;
    final c = context.colors;
    final color = status == AppointmentStatus.scheduled
        ? c.accent
        : status == AppointmentStatus.completed
            ? c.green
            : c.red;

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final int    tab;
  const _EmptyState({required this.message, required this.tab});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icons = [
      Icons.event_available_rounded,
      Icons.history_rounded,
      Icons.event_busy_rounded,
    ];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color:        c.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icons[tab],
                color: c.accent, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
          ),
        ],
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
