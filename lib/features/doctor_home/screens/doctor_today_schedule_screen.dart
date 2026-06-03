import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../appointment/models/appointment.dart';
import '../../appointment/services/appointment_service.dart';
import '../../appointment/screens/appointment_detail_screen.dart';
import '../../prescription/services/prescription_service.dart';
import '../../test_report/screens/test_report_detail_screen.dart';
import 'doctor_prescription_view_screen.dart';
import 'doctor_write_prescription_screen.dart';
import 'patient_detail_screen.dart';

class DoctorTodayScheduleScreen extends StatefulWidget {
  const DoctorTodayScheduleScreen({super.key});

  @override
  State<DoctorTodayScheduleScreen> createState() =>
      _DoctorTodayScheduleScreenState();
}

enum _ScheduleFilter { today, upcoming, completed }

class _DoctorTodayScheduleScreenState extends State<DoctorTodayScheduleScreen> {
  final _apptSvc = AppointmentService();
  final _rxSvc   = PrescriptionService();
  final _client = Supabase.instance.client;

  String? get _currentDoctorId => _client.auth.currentUser?.id;

  List<Appointment> _appointments = [];
  Map<String, Map<String, dynamic>> _patientById  = {};
  Map<String, String?>              _diagnosisByRxId = {};
  _ScheduleFilter _filter = _ScheduleFilter.today;
  DateTime? _selectedUpcomingDate;
  DateTime  _completedDate = DateTime(
    DateTime.now().year, DateTime.now().month, DateTime.now().day,
  );
  final _completedSearchCtrl = TextEditingController();
  bool _loading = true;

  // Multi-select (Today + Upcoming only).
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    _completedSearchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _completedSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final appts = await _apptSvc.fetchForCurrentDoctor();
      final sorted = [...appts]..sort(_sortByDateTimeThenCreated);

      final ids = sorted.map((a) => a.userId).toSet().toList();
      Map<String, Map<String, dynamic>> patientMap = {};
      if (ids.isNotEmpty) {
        final rows =
            await _client
                    .from('profiles')
                    .select('id, full_name, phone, avatar_url')
                    .inFilter('id', ids)
                as List;
        patientMap = {
          for (final row in rows)
            (row['id'] as String): row as Map<String, dynamic>,
        };
      }

      // Batch-fetch diagnoses for completed appointments that have a linked Rx.
      final rxIds = sorted
          .where((a) =>
              a.status == AppointmentStatus.completed &&
              a.prescriptionId != null)
          .map((a) => a.prescriptionId!)
          .toSet()
          .toList();
      Map<String, String?> diagnosisMap = {};
      if (rxIds.isNotEmpty) {
        final rows = await _client
            .from('prescriptions')
            .select('id, diagnosis')
            .inFilter('id', rxIds) as List;
        diagnosisMap = {
          for (final row in rows)
            (row['id'] as String): row['diagnosis'] as String?,
        };
      }

      if (!mounted) return;
      setState(() {
        _appointments      = sorted;
        _patientById       = patientMap;
        _diagnosisByRxId   = diagnosisMap;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Multi-select helpers ────────────────────────────────────────────────
  bool get _selectionAllowed =>
      _filter == _ScheduleFilter.today || _filter == _ScheduleFilter.upcoming;

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelection(Appointment appt) {
    if (!_selectionAllowed) return;
    setState(() {
      _selectionMode = true;
      _selectedIds.add(appt.id);
    });
  }

  void _toggleSelect(Appointment appt) {
    setState(() {
      if (!_selectedIds.remove(appt.id)) _selectedIds.add(appt.id);
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _selectAll(List<Appointment> visible) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(visible.map((a) => a.id));
    });
  }

  Future<void> _bulkCancel() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Cancel appointments',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: c.textPrimary)),
        content: Text(
          'Cancel ${ids.length} selected appointment${ids.length == 1 ? '' : 's'}? '
          'The patient${ids.length == 1 ? '' : 's'} will be notified.',
          style: GoogleFonts.poppins(fontSize: 13, color: c.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep',
                style: GoogleFonts.poppins(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel them',
                style: GoogleFonts.poppins(
                    color: c.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _apptSvc.cancelMany(ids);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${ids.length} appointment${ids.length == 1 ? '' : 's'} cancelled'),
      ));
      _exitSelection();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel: $e')));
    }
  }

  Future<void> _bulkReschedule() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final c = context.colors;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: c.accent,
            onPrimary: Colors.white,
            surface: c.card,
            onSurface: c.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final date = DateTime(picked.year, picked.month, picked.day);
    try {
      await _apptSvc.proposeRescheduleMany(ids, date);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Reschedule requested for ${ids.length} appointment${ids.length == 1 ? '' : 's'}. '
            'Patients will be asked to confirm.'),
      ));
      _exitSelection();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reschedule: $e')));
    }
  }

  List<Appointment> get _visibleAppointments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_filter == _ScheduleFilter.completed) {
      var list = _appointments
          .where((a) =>
              a.status == AppointmentStatus.completed &&
              _isSameDate(a.appointmentDate, _completedDate))
          .toList()
        ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

      final q = _completedSearchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list.where((a) {
          final name      = (_patientById[a.userId]?['full_name'] as String? ?? '').toLowerCase();
          final uid       = a.userId.toLowerCase();
          final diagnosis = (a.prescriptionId != null
              ? (_diagnosisByRxId[a.prescriptionId!] ?? '')
              : '').toLowerCase();
          return name.contains(q) || uid.contains(q) || diagnosis.contains(q);
        }).toList();
      }
      return list;
    }

    if (_filter == _ScheduleFilter.today) {
      return _appointments
          .where((a) =>
              _isSameDate(a.appointmentDate, today) &&
              a.status == AppointmentStatus.scheduled)
          .toList();
    }

    var list = _appointments.where((a) {
      final d = DateTime(
        a.appointmentDate.year,
        a.appointmentDate.month,
        a.appointmentDate.day,
      );
      return !d.isBefore(today) && a.status == AppointmentStatus.scheduled;
    }).toList();

    if (_selectedUpcomingDate != null) {
      list = list
          .where((a) => _isSameDate(a.appointmentDate, _selectedUpcomingDate!))
          .toList();
    }
    return list;
  }

  int _sortByDateTimeThenCreated(Appointment a, Appointment b) {
    final aDateTime = _toComparableDateTime(a);
    final bDateTime = _toComparableDateTime(b);
    final cmp = aDateTime.compareTo(bDateTime);
    if (cmp != 0) return cmp;
    return b.createdAt.compareTo(a.createdAt);
  }

  DateTime _toComparableDateTime(Appointment appt) {
    final d = appt.appointmentDate;
    final mins = _minutesFrom12h(appt.appointmentTime) ?? 24 * 60 - 1;
    return DateTime(d.year, d.month, d.day).add(Duration(minutes: mins));
  }

  int? _minutesFrom12h(String? text) {
    if (text == null) return null;
    final raw = text.trim().toUpperCase();
    final re = RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$');
    final m = re.firstMatch(raw);
    if (m == null) return null;
    final hourRaw = int.tryParse(m.group(1)!);
    final minute = int.tryParse(m.group(2)!);
    final period = m.group(3)!;
    if (hourRaw == null || minute == null) return null;
    var hour = hourRaw % 12;
    if (period == 'PM') hour += 12;
    return hour * 60 + minute;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Live serial = how many still-scheduled patients that day are ahead, + 1.
  // Closes gaps left by cancelled / no-show / rescheduled-away appointments.
  int? _queueSerial(Appointment a) {
    if (a.status != AppointmentStatus.scheduled || a.ticketNo == null) {
      return null;
    }
    final ahead = _appointments
        .where((o) =>
            o.status == AppointmentStatus.scheduled &&
            o.ticketNo != null &&
            _isSameDate(o.appointmentDate, a.appointmentDate) &&
            o.ticketNo! < a.ticketNo!)
        .length;
    return ahead + 1;
  }

  Future<void> _pickCompletedDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _completedDate,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   context.colors.green,
            onPrimary: Colors.white,
            surface:   context.colors.card,
            onSurface: context.colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _completedDate =
        DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickUpcomingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedUpcomingDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.colors.accent,
            onPrimary: Colors.white,
            surface: context.colors.card,
            onSurface: context.colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _filter = _ScheduleFilter.upcoming;
      _selectedUpcomingDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _openPatient(Appointment appt) async {
    final prof = _patientById[appt.userId];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(
          patientId: appt.userId,
          patientName:
              (prof?['full_name'] as String?)?.trim().isNotEmpty == true
              ? (prof!['full_name'] as String)
              : 'Patient',
          patientPhone:     prof?['phone']      as String?,
          patientAvatarUrl: prof?['avatar_url'] as String?,
          appointmentId:    appt.status == AppointmentStatus.scheduled
              ? appt.id
              : null,
        ),
      ),
    );
    if (mounted) _load();
  }

  String _patientNameOf(Appointment appt) {
    final prof = _patientById[appt.userId];
    final name = (prof?['full_name'] as String?)?.trim();
    return name?.isNotEmpty == true ? name! : 'Patient';
  }

  Future<void> _openAppointmentDetail(Appointment appt) async {
    final pname = _patientNameOf(appt);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(
          appointment:  appt,
          isDoctorView: true,
          patientName:  pname,
          // Own prescription = editable; others = view only.
          onPrescriptionTapDoctor: (p) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DoctorPrescriptionViewScreen(
                rx:          p,
                canEdit:     p.writtenByDoctorId == _currentDoctorId,
                patientId:   appt.userId,
                patientName: pname,
              ),
            ),
          ),
          // Test reports are always view-only for doctors.
          onTestReportTapDoctor: (t) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TestReportDetailScreen(
                report:    t,
                canEdit:   false,
                canDelete: false,
                onPrescriptionTap: (rxId) async {
                  final p = await _rxSvc.fetchOne(rxId);
                  if (p == null || !mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DoctorPrescriptionViewScreen(
                      rx:          p,
                      canEdit:     p.writtenByDoctorId == _currentDoctorId,
                      patientId:   appt.userId,
                      patientName: pname,
                    ),
                  ));
                },
              ),
            ),
          ),
          onOpenPatientProfile: () => _openPatient(appt),
          // Write a prescription straight from the appointment.
          onWritePrescription: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => DoctorWritePrescriptionScreen(
                  patientId:     appt.userId,
                  patientName:   pname,
                  appointmentId: appt.status == AppointmentStatus.scheduled
                      ? appt.id
                      : null,
                ),
              ),
            );
            if (result == true && mounted) {
              Navigator.of(context).pop(); // close appointment detail
              _load();
            }
          },
        ),
      ),
    );
    if (mounted) _load();
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

    final visible = _visibleAppointments;
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitSelection();
      },
      child: Scaffold(
      backgroundColor: c.bg,
      bottomNavigationBar:
          _selectionMode ? _buildSelectionActionBar(c) : null,
      body: Column(
        children: [
          _buildHeader(c, visible.length),
          if (_selectionMode) _buildSelectionToolbar(c, visible),
          if (_filter == _ScheduleFilter.completed)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color:        c.card,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: c.border),
                ),
                child: TextField(
                  controller: _completedSearchCtrl,
                  style:      GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText:   'Search by name, user ID or diagnosis…',
                    hintStyle:  GoogleFonts.poppins(fontSize: 13, color: c.textMuted),
                    prefixIcon: Icon(Icons.search_rounded, color: c.textSec, size: 20),
                    suffixIcon: _completedSearchCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () => setState(() => _completedSearchCtrl.clear()),
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
                ? Center(
                    child: CircularProgressIndicator(
                      color: c.accent,
                      strokeWidth: 2.5,
                    ),
                  )
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: visible.isEmpty
                        ? _EmptyState(filter: _filter)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                            itemCount: visible.length,
                            itemBuilder: (context, i) {
                              final appt = visible[i];
                              final prof = _patientById[appt.userId];
                              return _ScheduleTile(
                                appointment: appt,
                                showDate: _filter != _ScheduleFilter.today,
                                patientName:
                                    (prof?['full_name'] as String?) ??
                                    'Patient',
                                patientPhone: prof?['phone'] as String?,
                                displaySerial: _queueSerial(appt),
                                selectionMode: _selectionMode,
                                selected: _selectedIds.contains(appt.id),
                                onTap: () => _selectionMode
                                    ? _toggleSelect(appt)
                                    : _openAppointmentDetail(appt),
                                onLongPress: _selectionAllowed
                                    ? () => _selectionMode
                                        ? _toggleSelect(appt)
                                        : _enterSelection(appt)
                                    : null,
                              ).animate().fadeIn(
                                delay: Duration(milliseconds: i * 60),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSelectionToolbar(ThemeColors c, List<Appointment> visible) {
    final allSelected =
        visible.isNotEmpty && _selectedIds.length >= visible.length;
    return Container(
      color: c.accent.withAlpha(12),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitSelection,
            child: Icon(Icons.close_rounded, size: 22, color: c.textSec),
          ),
          const SizedBox(width: 14),
          Text(
            '${_selectedIds.length} selected',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () =>
                allSelected ? _exitSelection() : _selectAll(visible),
            child: Text(
              allSelected ? 'Clear all' : 'Select all',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: c.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionActionBar(ThemeColors c) {
    final n = _selectedIds.length;
    final enabled = n > 0;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? _bulkReschedule : null,
                icon: Icon(Icons.event_repeat_rounded, size: 18, color: c.accent),
                label: Text('Reschedule',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.accent)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: c.accent.withAlpha(110)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: enabled ? _bulkCancel : null,
                icon: const Icon(Icons.cancel_rounded, size: 18),
                label: Text('Cancel',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: c.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c, int count) {
    final topPad = MediaQuery.of(context).padding.top;
    final now = DateTime.now();
    final months = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final selectedDate = _filter == _ScheduleFilter.today
        ? now
        : _filter == _ScheduleFilter.completed
            ? _completedDate
            : (_selectedUpcomingDate ?? now);
    final title = _filter == _ScheduleFilter.today
        ? "Today's Schedule"
        : _filter == _ScheduleFilter.upcoming
        ? 'Upcoming Schedule'
        : 'Completed';

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      padding: EdgeInsets.only(
        top: topPad + 16,
        left: 20,
        right: 20,
        bottom: 18,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: c.textSec,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      '${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: c.textSec,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _FilterChip(
                label: 'Today',
                selected: _filter == _ScheduleFilter.today,
                onTap: () => setState(() {
                  _filter = _ScheduleFilter.today;
                  _selectedUpcomingDate = null;
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _selectedUpcomingDate == null
                    ? 'Upcoming'
                    : 'Upcoming: ${_selectedUpcomingDate!.day}/${_selectedUpcomingDate!.month}',
                selected: _filter == _ScheduleFilter.upcoming,
                onTap: () => setState(() {
                  _filter = _ScheduleFilter.upcoming;
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Completed',
                selected: _filter == _ScheduleFilter.completed,
                onTap: () => setState(() {
                  _filter = _ScheduleFilter.completed;
                  _selectedUpcomingDate = null;
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              const Spacer(),
              if (_filter == _ScheduleFilter.upcoming)
                GestureDetector(
                  onTap: _pickUpcomingDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:        c.accent.withAlpha(16),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: c.accent.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 14, color: c.accent),
                        const SizedBox(width: 4),
                        Text('Pick Date',
                            style: GoogleFonts.poppins(
                                fontSize: 11, fontWeight: FontWeight.w600, color: c.accent)),
                      ],
                    ),
                  ),
                ),
              if (_filter == _ScheduleFilter.completed)
                GestureDetector(
                  onTap: _pickCompletedDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:        c.green.withAlpha(16),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: c.green.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 14, color: c.green),
                        const SizedBox(width: 4),
                        Text('Pick Date',
                            style: GoogleFonts.poppins(
                                fontSize: 11, fontWeight: FontWeight.w600, color: c.green)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ScheduleTile extends StatelessWidget {
  final Appointment appointment;
  final bool showDate;
  final String patientName;
  final String? patientPhone;
  final int? displaySerial;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  const _ScheduleTile({
    required this.appointment,
    required this.showDate,
    required this.patientName,
    required this.patientPhone,
    this.displaySerial,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = appointment.status == AppointmentStatus.scheduled
        ? c.accent
        : appointment.status == AppointmentStatus.completed
        ? c.green
        : appointment.status == AppointmentStatus.noShow
        ? c.amber
        : c.red;
    final statusText = appointment.status == AppointmentStatus.scheduled
        ? 'Scheduled'
        : appointment.status == AppointmentStatus.completed
        ? 'Completed'
        : appointment.status == AppointmentStatus.noShow
        ? 'No-show'
        : 'Cancelled';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? c.accent.withAlpha(16) : c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? c.accent : c.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? c.accent : c.textMuted,
                ),
                const SizedBox(width: 10),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withAlpha(70)),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              if (displaySerial != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.green.withAlpha(70)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.confirmation_number_rounded,
                          size: 11, color: c.green),
                      const SizedBox(width: 3),
                      Text(
                        '#$displaySerial',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: c.green),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if ((appointment.appointmentTime ?? '').isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: c.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.appointmentTime!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textSec,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (showDate) ...[
            Row(
              children: [
                Icon(Icons.event_rounded, size: 13, color: c.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${appointment.appointmentDate.day}/${appointment.appointmentDate.month}/${appointment.appointmentDate.year}',
                  style: GoogleFonts.poppins(fontSize: 12, color: c.textSec),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            patientName,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          if ((patientPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              patientPhone!,
              style: GoogleFonts.poppins(fontSize: 12, color: c.textSec),
            ),
          ],
          if ((appointment.visitReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              appointment.visitReason!,
              style: GoogleFonts.poppins(fontSize: 13, color: c.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if ((appointment.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes_rounded, size: 13, color: c.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    appointment.notes!,
                    style: GoogleFonts.poppins(fontSize: 12, color: c.textSec),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (!selectionMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(
                  Icons.event_note_rounded,
                  size: 16,
                  color: c.accent,
                ),
                label: Text(
                  'View Appointment',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.accent,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: c.accent.withAlpha(90)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _ScheduleFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, title, sub) = switch (filter) {
      _ScheduleFilter.today     => (Icons.event_busy_rounded,     'No schedule for today',       'Today has no appointments yet.'),
      _ScheduleFilter.upcoming  => (Icons.event_busy_rounded,     'No upcoming schedule found',  'No appointments found for upcoming dates.'),
      _ScheduleFilter.completed => (Icons.check_circle_outline_rounded, 'No completed appointments', 'Prescriptions you write will appear here.'),
    };
    return ListView(
      children: [
        const SizedBox(height: 90),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 66, color: c.textMuted),
              const SizedBox(height: 14),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600, color: c.textSec)),
              const SizedBox(height: 6),
              Text(sub, style: GoogleFonts.poppins(fontSize: 13, color: c.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accent.withAlpha(20) : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.accent : c.textSec,
          ),
        ),
      ),
    );
  }
}
