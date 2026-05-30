import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../appointment/models/appointment.dart';
import '../../appointment/services/appointment_service.dart';

class AllAppointmentsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const AllAppointmentsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<AllAppointmentsScreen> createState() => _AllAppointmentsScreenState();
}

class _AllAppointmentsScreenState extends State<AllAppointmentsScreen> {
  final _svc        = AppointmentService();
  final _searchCtrl = TextEditingController();

  List<Appointment> _list      = [];
  bool              _loading   = true;
  bool              _sortNewest = true;

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
      final list = await _svc.fetchForPatient(widget.patientId);
      if (mounted) setState(() => _list = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Appointment> get _filteredList {
    var result = List<Appointment>.from(_list);

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((a) {
        final reason = (a.visitReason ?? '').toLowerCase();
        final doctor = a.doctorNameSnapshot.toLowerCase();
        return reason.contains(q) || doctor.contains(q);
      }).toList();
    }

    result.sort((a, b) => _sortNewest
        ? b.appointmentDate.compareTo(a.appointmentDate)
        : a.appointmentDate.compareTo(b.appointmentDate));

    return result;
  }

  bool get _hasActiveFilter => _searchCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final filtered = _filteredList;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c),

          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
                  hintText:   'Search by reason or doctor…',
                  hintStyle:  GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: c.textSec, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
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

          // ── Filter row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _sortNewest = !_sortNewest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color:        c.card,
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sortNewest
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size:  13,
                          color: c.textSec,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _sortNewest ? 'Newest' : 'Oldest',
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w600, color: c.textSec),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _hasActiveFilter
                      ? '${filtered.length} / ${_list.length}'
                      : '${_list.length}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted),
                ),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.amber, strokeWidth: 2.5))
                : filtered.isEmpty
                    ? _EmptyState(hasFilter: _hasActiveFilter)
                    : RefreshIndicator(
                        color:     c.amber,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:     const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount:   filtered.length,
                          itemBuilder: (ctx, i) => _AppointmentTile(appt: filtered[i])
                              .animate()
                              .fadeIn(delay: Duration(milliseconds: 25 * i)),
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
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      padding: EdgeInsets.only(top: topPad + 16, left: 20, right: 20, bottom: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        c.surface,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back_rounded, color: c.textSec, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Appointments',
                    style: GoogleFonts.poppins(
                        fontSize: 19, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text(widget.patientName,
                    style: GoogleFonts.poppins(fontSize: 12, color: c.textSec)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        c.amber.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_list.length}',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.amber)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter ? Icons.search_off_rounded : Icons.calendar_month_outlined,
            size: 56, color: c.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'No results found' : 'No appointments found',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600, color: c.textSec),
          ),
          const SizedBox(height: 4),
          Text(
            hasFilter
                ? 'Try adjusting your search.'
                : 'No appointments have been booked yet.',
            style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Appointment tile ──────────────────────────────────────────────────────────

class _AppointmentTile extends StatelessWidget {
  final Appointment appt;
  const _AppointmentTile({required this.appt});

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final months  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d       = appt.appointmentDate;
    final dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';

    final statusColor = appt.isUpcoming  ? c.green
        : appt.isCancelled ? c.red
        : c.textSec;
    final statusLabel = appt.isUpcoming  ? 'Scheduled'
        : appt.isCancelled ? 'Cancelled'
        : 'Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        c.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        c.amber.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_month_rounded, color: c.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.visitReason ?? appt.doctorNameSnapshot,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateStr + (appt.appointmentTime != null ? ' · ${appt.appointmentTime}' : ''),
                  style: GoogleFonts.poppins(fontSize: 11, color: c.textSec),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        statusColor.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusLabel,
                style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ],
      ),
    );
  }
}
