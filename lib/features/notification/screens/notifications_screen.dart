// notifications_screen.dart — In-app notification inbox.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_colors.dart';
import '../../appointment/services/appointment_service.dart';
import '../../appointment/screens/appointment_detail_screen.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service  = NotificationService();
  final _apptSvc  = AppointmentService();

  bool                  _loading = true;
  List<AppNotification> _items   = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await _service.fetchAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    if (mounted) {
      setState(() => _items = _items.map((n) => n.copyWith(isRead: true)).toList());
    }
  }

  Future<void> _clearAll() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Clear all',
            style: GoogleFonts.poppins(color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('Delete all notifications?',
            style: GoogleFonts.poppins(fontSize: 13, color: c.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: c.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteAll();
    if (mounted) setState(() => _items = []);
  }

  Future<void> _onTap(AppNotification n) async {
    if (!n.isRead) {
      await _service.markRead(n.id);
      if (mounted) {
        setState(() {
          final i = _items.indexWhere((e) => e.id == n.id);
          if (i != -1) _items[i] = _items[i].copyWith(isRead: true);
        });
      }
    }
    final apptId = n.appointmentId;
    if (apptId == null || !mounted) return;
    final appt = await _apptSvc.fetchOne(apptId);
    if (appt == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AppointmentDetailScreen(appointment: appt),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: c.statusBarIconBrightness,
    ));

    final hasUnread = _items.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c, hasUnread),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : _items.isEmpty
                    ? _EmptyState()
                    : RefreshIndicator(
                        color:     c.accent,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding:          const EdgeInsets.fromLTRB(20, 16, 20, 40),
                          itemCount:        _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _NotificationTile(
                            notification: _items[i],
                            onTap:        () => _onTap(_items[i]),
                            delay:        i * 40,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeColors c, bool hasUnread) {
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
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      padding: EdgeInsets.only(top: topPad + 16, left: 20, right: 12, bottom: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: _IconBtn(icon: Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Notifications',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
          ),
          if (_items.isNotEmpty) ...[
            if (hasUnread)
              TextButton(
                onPressed: _markAllRead,
                child: Text('Mark all read',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
              ),
            IconButton(
              onPressed: _clearAll,
              icon: Icon(Icons.delete_sweep_rounded, color: c.textMuted, size: 22),
              tooltip: 'Clear all',
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }
}

// ── Notification tile ───────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback    onTap;
  final int             delay;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.delay,
  });

  (IconData, Color) _visual(ThemeColors c) {
    switch (notification.type) {
      case 'appointment_rescheduled':
        return (Icons.event_repeat_rounded, c.amber);
      case 'appointment_cancelled':
        return (Icons.event_busy_rounded, c.red);
      default:
        return (Icons.notifications_rounded, c.accent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c            = context.colors;
    final (icon, icol) = _visual(c);
    final unread       = !notification.isRead;

    return Material(
      color:        unread ? c.accent.withAlpha(10) : c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: unread ? c.accent.withAlpha(50) : c.border, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        icol.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: icol, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.poppins(
                              fontSize:   13,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                              color:      c.textPrimary,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    if (notification.body?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body!,
                        style: GoogleFonts.poppins(fontSize: 12, color: c.textSec, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: GoogleFonts.poppins(fontSize: 10, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.06);
  }

  String _relativeTime(DateTime t) {
    final now  = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${t.day} ${months[t.month - 1]} ${t.year}';
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
            child: Icon(Icons.notifications_none_rounded, color: c.accent, size: 36),
          ),
          const SizedBox(height: 16),
          Text('No notifications yet',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSec)),
          const SizedBox(height: 4),
          Text("You're all caught up.",
              style: GoogleFonts.poppins(fontSize: 12, color: c.textMuted)),
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
