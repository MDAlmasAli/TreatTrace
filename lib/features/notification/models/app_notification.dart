// app_notification.dart — Pure Dart model for an in-app notification.

class AppNotification {
  final String                  id;
  final String                  userId; // recipient
  final String                  type;   // e.g. appointment_rescheduled, appointment_cancelled
  final String                  title;
  final String?                 body;
  final Map<String, dynamic>?   data;   // arbitrary payload, e.g. { appointment_id }
  final bool                    isRead;
  final DateTime                createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.data,
    this.isRead    = false,
    required this.createdAt,
  });

  // Convenience accessor for the linked appointment, if any.
  String? get appointmentId => data?['appointment_id'] as String?;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id:        m['id']        as String,
        userId:    m['user_id']   as String,
        type:      m['type']      as String,
        title:     m['title']     as String,
        body:      m['body']      as String?,
        data:      m['data']      as Map<String, dynamic>?,
        isRead:    m['is_read']   as bool? ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id:        id,
        userId:    userId,
        type:      type,
        title:     title,
        body:      body,
        data:      data,
        isRead:    isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
