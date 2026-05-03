// ─────────────────────────────────────────────────────────────────────────────
// health_profile.dart
//
// Pure Dart model for a user's health data. No Flutter imports.
// BMI is always auto-calculated — it is never stored in the database.
// All fields except userId are nullable so new users start with no data.
// ─────────────────────────────────────────────────────────────────────────────

class HealthProfile {
  final String  userId;
  final String? bloodGroup;
  final int?    ageYears;
  final double? heightCm;   // stored in cm; UI converts to/from ft+in
  final double? weightKg;
  final String? allergies;
  final String? ongoingTreatment;
  final String? emergencyName;
  final String? emergencyPhone;

  const HealthProfile({
    required this.userId,
    this.bloodGroup,
    this.ageYears,
    this.heightCm,
    this.weightKg,
    this.allergies,
    this.ongoingTreatment,
    this.emergencyName,
    this.emergencyPhone,
  });

  // ── Flags ─────────────────────────────────────────────────────────────────

  bool get hasVitals =>
      bloodGroup != null || ageYears != null ||
      heightCm   != null || weightKg != null;

  bool get hasHealthRecords =>
      allergies != null || ongoingTreatment != null;

  bool get hasEmergencyContact =>
      emergencyName != null || emergencyPhone != null;

  // ── BMI (auto-calculated) ─────────────────────────────────────────────────

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final hM = heightCm! / 100.0;
    return weightKg! / (hM * hM);
  }

  String get bmiLabel {
    final b = bmi;
    if (b == null) return '—';
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal Weight';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  // ── Display helpers ───────────────────────────────────────────────────────

  String get heightDisplay {
    if (heightCm == null) return '—';
    final totalInches = heightCm! / 2.54;
    final feet   = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    return "$feet' $inches\"";
  }

  String get weightDisplay =>
      weightKg == null ? '—' : '${weightKg!.toStringAsFixed(1)} kg';

  String get ageDisplay =>
      ageYears == null ? '—' : '$ageYears yrs';

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory HealthProfile.fromMap(Map<String, dynamic> m) => HealthProfile(
        userId:           m['id']                as String,
        bloodGroup:       m['blood_group']        as String?,
        ageYears:         m['age']                as int?,
        heightCm:         (m['height_cm']  as num?)?.toDouble(),
        weightKg:         (m['weight_kg']  as num?)?.toDouble(),
        allergies:        m['allergies']          as String?,
        ongoingTreatment: m['ongoing_treatment']  as String?,
        emergencyName:    m['emergency_name']     as String?,
        emergencyPhone:   m['emergency_phone']    as String?,
      );

  Map<String, dynamic> toMap() => {
        'id':                userId,
        'blood_group':       bloodGroup,
        'age':               ageYears,
        'height_cm':         heightCm,
        'weight_kg':         weightKg,
        'allergies':         allergies,
        'ongoing_treatment': ongoingTreatment,
        'emergency_name':    emergencyName,
        'emergency_phone':   emergencyPhone,
      };
}
