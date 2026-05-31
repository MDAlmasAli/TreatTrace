// notification_bell.dart — Header bell with live unread badge + inbox launcher.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/services/reminder_service.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../screens/notifications_screen.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _service = NotificationService();
  RealtimeChannel? _channel;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _channel = _service.subscribe(_onNewNotification);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _refresh() async {
    final n = await _service.unreadCount();
    if (mounted) setState(() => _unread = n);
  }

  void _onNewNotification(AppNotification n) {
    if (mounted) setState(() => _unread += 1);
    // Surface a local notification while the app is open (no-op on web).
    ReminderService().showNotification(
      title:   n.title,
      body:    n.body ?? '',
      payload: 'notification:${n.id}',
    );
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: _open,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        c.surface,
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: c.border, width: 1),
            ),
            child: Icon(Icons.notifications_outlined, color: c.textSec, size: 21),
          ),
          if (_unread > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color:        c.red,
                  borderRadius: BorderRadius.circular(9),
                  border:       Border.all(color: c.card, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    _unread > 99 ? '99+' : '$_unread',
                    style: GoogleFonts.poppins(
                      fontSize:   9,
                      fontWeight: FontWeight.w700,
                      color:      Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
