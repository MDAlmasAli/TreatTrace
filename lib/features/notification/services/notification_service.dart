// notification_service.dart — Supabase CRUD + realtime for in-app notifications.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';

class NotificationService {
  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<List<AppNotification>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<int> unreadCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('is_read', false);
    return rows.length;
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  Future<void> delete(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  Future<void> deleteAll() async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('notifications').delete().eq('user_id', uid);
  }

  // Realtime: fires onInsert whenever a new notification arrives for this user.
  RealtimeChannel subscribe(void Function(AppNotification) onInsert) {
    final uid = _uid;
    final channel = _client.channel('notifications_${uid ?? 'anon'}');
    if (uid != null) {
      channel.onPostgresChanges(
        event:  PostgresChangeEvent.insert,
        schema: 'public',
        table:  'notifications',
        filter: PostgresChangeFilter(
          type:   PostgresChangeFilterType.eq,
          column: 'user_id',
          value:  uid,
        ),
        callback: (payload) => onInsert(AppNotification.fromMap(payload.newRecord)),
      );
    }
    return channel.subscribe();
  }
}
