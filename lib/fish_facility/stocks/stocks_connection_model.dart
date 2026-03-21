import '/core/fish_db_schema.dart';

// ─── FISH STOCK MODEL ─────────────────────────────────────────────────────────
class FishStock {
  final int? id;
  final String stockId;
  String line;
  int males;
  int females;
  int juveniles;
  int mortality;
  String tankId;
  String responsible;
  String status;
  String health;
  String? origin;
  String? experiment;
  String? notes;
  double? volumeL;
  final DateTime? arrivalDate;
  final DateTime created;
  DateTime? lastCleaning;
  int? cleaningIntervalDays;
  String? feedingSchedule;
  String? foodType;
  /// Date of birth from the linked fish_line record (from the FK join).
  final DateTime? lineDateBirth;
  /// Set post-construction when the FK join returned null but a name-lookup found a date.
  DateTime? lineDateBirthOverride;
  /// Editable age override (months). When 0, computed from lineDateBirth or arrivalDate.
  int _ageMonths;

  FishStock({
    this.id,
    required this.stockId,
    required this.line,
    required this.males,
    required this.females,
    required this.juveniles,
    this.mortality = 0,
    required this.tankId,
    required this.responsible,
    required this.status,
    required this.health,
    this.origin,
    this.experiment,
    this.notes,
    this.volumeL,
    this.arrivalDate,
    required this.created,
    this.lineDateBirth,
    int ageMonths = 0,
    this.lastCleaning,
    this.cleaningIntervalDays,
    this.feedingSchedule,
    this.foodType,
  }) : _ageMonths = ageMonths;

  /// Computed next cleaning date. Null if either field is missing.
  DateTime? get nextCleaning {
    if (lastCleaning == null || cleaningIntervalDays == null || cleaningIntervalDays! <= 0) return null;
    return lastCleaning!.add(Duration(days: cleaningIntervalDays!));
  }

  /// Age in days from fish_line date_birth (preferred) or arrivalDate.
  int get ageDays {
    final ref = lineDateBirth ?? lineDateBirthOverride ?? arrivalDate;
    if (ref == null) return 0;
    return DateTime.now().difference(ref).inDays;
  }

  int get ageMonths {
    if (_ageMonths > 0) return _ageMonths;
    final d = ageDays;
    return d > 0 ? (d / 30.44).floor() : 0;
  }

  set ageMonths(int v) => _ageMonths = v;

  /// Zebrafish life-stage. Null if no reference date is available.
  /// Larvae: < 30 d, Juveniles: 30–89 d, Adults: ≥ 90 d.
  String? get maturity {
    final d = ageDays;
    if (d <= 0) return null;
    if (d >= 90) return 'Adults';
    if (d >= 30) return 'Juveniles';
    return 'Larvae';
  }

  int get totalFish => males + females + juveniles;

  factory FishStock.fromMap(Map<String, dynamic> m) {
    int asInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final rawId = m[FishSch.stockId];
    final lineData = m['fish_lines'] as Map<String, dynamic>?;
    final dobRaw = lineData?[FishSch.lineDateBirth];
    return FishStock(
      id:             rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      stockId:        rawId?.toString() ?? '',
      line:           (m[FishSch.stockLine] ?? '').toString(),
      males:          asInt(m[FishSch.stockMales]),
      females:        asInt(m[FishSch.stockFemales]),
      juveniles:      asInt(m[FishSch.stockJuveniles]),
      mortality:      asInt(m[FishSch.stockMortality]),
      tankId:         (m[FishSch.stockTankId] ?? '').toString(),
      responsible:    (m[FishSch.stockResponsible] ?? '').toString(),
      status:         (m[FishSch.stockStatus] ?? 'active').toString(),
      health:         (m[FishSch.stockHealthStatus] ?? 'healthy').toString(),
      origin:         m[FishSch.stockOrigin]?.toString(),
      experiment:     m[FishSch.stockExperimentId]?.toString(),
      notes:          m[FishSch.stockNotes]?.toString(),
      arrivalDate:    m[FishSch.stockArrivalDate] != null
          ? DateTime.tryParse(m[FishSch.stockArrivalDate].toString())
          : null,
      created:        m[FishSch.stockCreatedAt] != null
          ? DateTime.tryParse(m[FishSch.stockCreatedAt].toString()) ?? DateTime.now()
          : DateTime.now(),
      lineDateBirth:  dobRaw != null ? DateTime.tryParse(dobRaw.toString()) : null,
      lastCleaning:   m[FishSch.stockLastCleaning] != null
          ? DateTime.tryParse(m[FishSch.stockLastCleaning].toString())
          : null,
      cleaningIntervalDays: m[FishSch.stockCleaningInterval] != null
          ? int.tryParse(m[FishSch.stockCleaningInterval].toString())
          : null,
      feedingSchedule: m[FishSch.stockFeedingSchedule]?.toString(),
      foodType:        m[FishSch.stockFoodType]?.toString(),
    );
  }
}
