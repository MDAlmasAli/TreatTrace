// reminder_service.dart
// Medicine reminder scheduling via flutter_local_notifications.
// Web is a no-op (notifications not supported).

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/prescription/models/prescription.dart';
import '../../features/prescription/models/prescription_medicine.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._();
  factory ReminderService() => _instance;
  ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Initialize ────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Request Android 13+ permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── Schedule reminders for all active medicines in a prescription ─────────

  Future<void> scheduleForPrescription(Prescription prescription) async {
    if (kIsWeb) return;
    for (final med in prescription.medicines) {
      if (!med.isActive) continue;
      await _scheduleMedicineReminders(prescription.id, med);
    }
  }

  // ── Cancel all reminders for a prescription ───────────────────────────────

  Future<void> cancelForPrescription(String prescriptionId) async {
    if (kIsWeb) return;
    // IDs are encoded as prescriptionIndex * 100 + slotIndex
    // We can't enumerate them without state, so we cancel a known range.
    // Each prescription gets 400 potential IDs (index 0..399).
    // In practice we use a hash of prescriptionId to get a base.
    final base = _baseId(prescriptionId);
    for (var i = 0; i < 400; i++) {
      await _plugin.cancel(base + i);
    }
  }

  // ── Cancel all app reminders ──────────────────────────────────────────────

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static const _slots = <int, String>{
    0: '08:00', // morning
    1: '13:00', // afternoon
    2: '18:00', // evening
    3: '22:00', // night
  };

  Future<void> _scheduleMedicineReminders(
      String prescriptionId, PrescriptionMedicine med) async {
    final base = _baseId(prescriptionId);
    final medHash = med.id.hashCode.abs() % 100;

    final doseFlags = [med.morning, med.afternoon, med.evening, med.night];

    for (var slot = 0; slot < 4; slot++) {
      if (!doseFlags[slot]) continue;

      final timeParts = _slots[slot]!.split(':');
      final hour   = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final notifId = base + medHash * 4 + slot;

      final now  = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final endDate = med.endDate;
      if (endDate != null && scheduled.isAfter(endDate)) continue;

      await _plugin.zonedSchedule(
        notifId,
        'Medicine Reminder',
        '${med.medicineName}${med.dose != null ? " — ${med.dose}" : ""}',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_reminders',
            'Medicine Reminders',
            channelDescription: 'Daily medicine reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  int _baseId(String prescriptionId) =>
      prescriptionId.hashCode.abs() % 100000 * 4;
}
