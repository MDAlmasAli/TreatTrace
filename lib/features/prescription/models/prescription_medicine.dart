// prescription_medicine.dart — Pure Dart model. No Flutter imports.

class PrescriptionMedicine {
  final String   id;
  final String   prescriptionId;
  final String   medicineName;
  final String?  dose;
  final bool     morning;
  final bool     afternoon;
  final bool     evening;
  final bool     night;
  final bool     beforeMeal;
  final bool     afterMeal;
  final int?     durationDays;
  final String?  instructions;
  final DateTime? startDate;

  const PrescriptionMedicine({
    required this.id,
    required this.prescriptionId,
    required this.medicineName,
    this.dose,
    this.morning    = false,
    this.afternoon  = false,
    this.evening    = false,
    this.night      = false,
    this.beforeMeal = false,
    this.afterMeal  = false,
    this.durationDays,
    this.instructions,
    this.startDate,
  });

  // ── Computed ──────────────────────────────────────────────────────────────

  String get frequencyDisplay {
    final parts = <String>[];
    if (morning)   parts.add('Morning');
    if (afternoon) parts.add('Afternoon');
    if (evening)   parts.add('Evening');
    if (night)     parts.add('Night');
    return parts.isEmpty ? 'As directed' : parts.join(' · ');
  }

  String get mealDisplay {
    if (beforeMeal) return 'Before meal';
    if (afterMeal)  return 'After meal';
    return 'Any time';
  }

  // e.g. "1-0-0-1" (morning-afternoon-evening-night)
  String get frequencyCode =>
      '${morning ? 1 : 0}-${afternoon ? 1 : 0}-${evening ? 1 : 0}-${night ? 1 : 0}';

  int get dosesPerDay =>
      (morning ? 1 : 0) + (afternoon ? 1 : 0) + (evening ? 1 : 0) + (night ? 1 : 0);

  DateTime? get endDate {
    if (startDate == null || durationDays == null) return null;
    return startDate!.add(Duration(days: durationDays!));
  }

  bool get isActive {
    final end = endDate;
    if (end == null) return true;
    return end.isAfter(DateTime.now());
  }

  bool get needsRefillSoon {
    final end = endDate;
    if (end == null) return false;
    final daysLeft = end.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 3;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory PrescriptionMedicine.fromMap(Map<String, dynamic> m) =>
      PrescriptionMedicine(
        id:             m['id']              as String,
        prescriptionId: m['prescription_id'] as String,
        medicineName:   m['medicine_name']   as String,
        dose:           m['dose']            as String?,
        morning:        (m['morning']        as bool?) ?? false,
        afternoon:      (m['afternoon']      as bool?) ?? false,
        evening:        (m['evening']        as bool?) ?? false,
        night:          (m['night']          as bool?) ?? false,
        beforeMeal:     (m['before_meal']    as bool?) ?? false,
        afterMeal:      (m['after_meal']     as bool?) ?? false,
        durationDays:   m['duration_days']   as int?,
        instructions:   m['instructions']    as String?,
        startDate: m['start_date'] != null
            ? DateTime.tryParse(m['start_date'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'prescription_id': prescriptionId,
        'medicine_name':   medicineName,
        'dose':            dose,
        'morning':         morning,
        'afternoon':       afternoon,
        'evening':         evening,
        'night':           night,
        'before_meal':     beforeMeal,
        'after_meal':      afterMeal,
        'duration_days':   durationDays,
        'instructions':    instructions,
        'start_date':      startDate?.toIso8601String().substring(0, 10),
      };

  PrescriptionMedicine copyWith({
    String?   id,
    String?   prescriptionId,
    String?   medicineName,
    String?   dose,
    bool?     morning,
    bool?     afternoon,
    bool?     evening,
    bool?     night,
    bool?     beforeMeal,
    bool?     afterMeal,
    int?      durationDays,
    String?   instructions,
    DateTime? startDate,
  }) =>
      PrescriptionMedicine(
        id:             id             ?? this.id,
        prescriptionId: prescriptionId ?? this.prescriptionId,
        medicineName:   medicineName   ?? this.medicineName,
        dose:           dose           ?? this.dose,
        morning:        morning        ?? this.morning,
        afternoon:      afternoon      ?? this.afternoon,
        evening:        evening        ?? this.evening,
        night:          night          ?? this.night,
        beforeMeal:     beforeMeal     ?? this.beforeMeal,
        afterMeal:      afterMeal      ?? this.afterMeal,
        durationDays:   durationDays   ?? this.durationDays,
        instructions:   instructions   ?? this.instructions,
        startDate:      startDate      ?? this.startDate,
      );
}
