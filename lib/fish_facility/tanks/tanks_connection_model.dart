// tanks_connection_model.dart - ZebrafishTank data model: maps to the
// fish_stocks Supabase table; from/toMap serialisation, copyWith helper.

import '/core/fish_db_schema.dart';

// ─── ZEBRAFISH TANK MODEL ─────────────────────────────────────────────────────
// Maps to the fish_stocks table in the database.
class ZebrafishTank {
  final int? zebraId;
  final String zebraTankId;
  final String? zebraTankType;
  final String? zebraRack;
  final String? zebraRow;
  final String? zebraColumn;
  final int? zebraCapacity;
  final double? zebraVolumeL;
  final String? zebraLine;
  final int? zebraLineId;
  final int? zebraMales;
  final int? zebraFemales;
  final int? zebraJuveniles;
  final String? zebraResponsible;
  final String? zebraStatus;
  final String? zebraLightCycle;
  final double? zebraTemperatureC;
  final double? zebraConductivity;
  final double? zebraPh;
  final DateTime? zebraLastTankCleaning;
  final int? zebraCleaningIntervalDays;
  final String? zebraFoodType;
  final String? zebraFoodSource;
  final double? zebraFoodAmount;
  final String? zebraFeedingAmountUnit;
  final String? zebraFeedingSchedule;
  final DateTime? zebraLastHealthCheck;
  final String? zebraHealthStatus;
  final String? zebraTreatment;
  final String? zebraExperimentId;
  final String? zebraEthicsApproval;
  final DateTime? zebraLastBreeding;
  final String? zebraNotes;
  final DateTime? zebraCreatedAt;

  // UI helpers
  final bool isEightLiter;
  final bool isTopRow;
  final int rackRowIndex;
  final int rackColIndex;

  ZebrafishTank({
    this.zebraId,
    required this.zebraTankId,
    this.zebraTankType,
    this.zebraRack,
    this.zebraRow,
    this.zebraColumn,
    this.zebraCapacity,
    this.zebraVolumeL,
    this.zebraLine,
    this.zebraLineId,
    this.zebraMales,
    this.zebraFemales,
    this.zebraJuveniles,
    this.zebraResponsible,
    this.zebraStatus,
    this.zebraLightCycle,
    this.zebraTemperatureC,
    this.zebraConductivity,
    this.zebraPh,
    this.zebraLastTankCleaning,
    this.zebraCleaningIntervalDays,
    this.zebraFoodType,
    this.zebraFoodSource,
    this.zebraFoodAmount,
    this.zebraFeedingAmountUnit,
    this.zebraFeedingSchedule,
    this.zebraLastHealthCheck,
    this.zebraHealthStatus,
    this.zebraTreatment,
    this.zebraExperimentId,
    this.zebraEthicsApproval,
    this.zebraLastBreeding,
    this.zebraNotes,
    this.zebraCreatedAt,
    this.isEightLiter = false,
    this.isTopRow = false,
    this.rackRowIndex = 0,
    this.rackColIndex = 0,
  });

  factory ZebrafishTank.fromMap(Map<String, dynamic> m) => ZebrafishTank(
    zebraId:               m[FishSch.stockId] as int?,
    zebraTankId:           m[FishSch.stockTankId] as String,
    zebraTankType:         m[FishSch.stockTankType] as String?,
    zebraRack:             m[FishSch.stockRack] as String?,
    zebraRow:              m[FishSch.stockRow] as String?,
    zebraColumn:           m[FishSch.stockColumn] as String?,
    zebraCapacity:         m[FishSch.stockCapacity] as int?,
    zebraVolumeL:          (m[FishSch.stockVolumeL] as num?)?.toDouble(),
    zebraLine:             m[FishSch.stockLine] as String?,
    zebraLineId:           m[FishSch.stockLineId] as int?,
    zebraMales:            m[FishSch.stockMales] as int?,
    zebraFemales:          m[FishSch.stockFemales] as int?,
    zebraJuveniles:        m[FishSch.stockJuveniles] as int?,
    zebraResponsible:      m[FishSch.stockResponsible] as String?,
    zebraStatus:           m[FishSch.stockStatus] as String?,
    zebraLightCycle:       m[FishSch.stockLightCycle] as String?,
    zebraTemperatureC:     (m[FishSch.stockTemperatureC] as num?)?.toDouble(),
    zebraConductivity:     (m[FishSch.stockConductivity] as num?)?.toDouble(),
    zebraPh:               (m[FishSch.stockPh] as num?)?.toDouble(),
    zebraLastTankCleaning: m[FishSch.stockLastCleaning] != null
        ? DateTime.tryParse(m[FishSch.stockLastCleaning]) : null,
    zebraCleaningIntervalDays: m[FishSch.stockCleaningInterval] as int?,
    zebraFoodType:         m[FishSch.stockFoodType] as String?,
    zebraFoodSource:       m[FishSch.stockFoodSource] as String?,
    zebraFoodAmount:       (m[FishSch.stockFoodAmount] as num?)?.toDouble(),
    zebraFeedingAmountUnit: m[FishSch.stockFeedingAmountUnit] as String?,
    zebraFeedingSchedule:  m[FishSch.stockFeedingSchedule] as String?,
    zebraLastHealthCheck:  m[FishSch.stockLastHealthCheck] != null
        ? DateTime.tryParse(m[FishSch.stockLastHealthCheck]) : null,
    zebraHealthStatus:     m[FishSch.stockHealthStatus] as String?,
    zebraTreatment:        m[FishSch.stockTreatment] as String?,
    zebraExperimentId:     m[FishSch.stockExperimentId] as String?,
    zebraEthicsApproval:   m[FishSch.stockEthicsApproval] as String?,
    zebraLastBreeding:     m[FishSch.stockLastBreeding] != null
        ? DateTime.tryParse(m[FishSch.stockLastBreeding]) : null,
    zebraNotes:            m[FishSch.stockNotes] as String?,
    zebraCreatedAt:        m[FishSch.stockCreatedAt] != null
        ? DateTime.tryParse(m[FishSch.stockCreatedAt]) : null,
  );

  Map<String, dynamic> toMap() => {
    if (zebraId != null) FishSch.stockId: zebraId,
    FishSch.stockTankId:           zebraTankId,
    FishSch.stockTankType:         zebraTankType,
    FishSch.stockRack:             zebraRack,
    FishSch.stockRow:              zebraRow,
    FishSch.stockColumn:           zebraColumn,
    FishSch.stockCapacity:         zebraCapacity,
    FishSch.stockVolumeL:          zebraVolumeL,
    FishSch.stockLine:             zebraLine,
    FishSch.stockLineId:           zebraLineId,
    FishSch.stockMales:            zebraMales,
    FishSch.stockFemales:          zebraFemales,
    FishSch.stockJuveniles:        zebraJuveniles,
    FishSch.stockResponsible:      zebraResponsible,
    FishSch.stockStatus:           zebraStatus,
    FishSch.stockLightCycle:       zebraLightCycle,
    FishSch.stockTemperatureC:     zebraTemperatureC,
    FishSch.stockConductivity:     zebraConductivity,
    FishSch.stockPh:               zebraPh,
    FishSch.stockLastCleaning:     zebraLastTankCleaning?.toIso8601String(),
    FishSch.stockCleaningInterval: zebraCleaningIntervalDays,
    FishSch.stockFoodType:         zebraFoodType,
    FishSch.stockFoodSource:       zebraFoodSource,
    FishSch.stockFoodAmount:       zebraFoodAmount,
    FishSch.stockFeedingAmountUnit: zebraFeedingAmountUnit,
    FishSch.stockFeedingSchedule:  zebraFeedingSchedule,
    FishSch.stockLastHealthCheck:  zebraLastHealthCheck?.toIso8601String(),
    FishSch.stockHealthStatus:     zebraHealthStatus,
    FishSch.stockTreatment:        zebraTreatment,
    FishSch.stockExperimentId:     zebraExperimentId,
    FishSch.stockEthicsApproval:   zebraEthicsApproval,
    FishSch.stockLastBreeding:     zebraLastBreeding?.toIso8601String(),
    FishSch.stockNotes:            zebraNotes,
  };

  ZebrafishTank copyWith({
    int? zebraId,
    String? zebraTankId, String? zebraTankType, String? zebraRack,
    String? zebraRow, String? zebraColumn, int? zebraCapacity,
    double? zebraVolumeL, String? zebraLine, int? zebraLineId,
    int? zebraMales, int? zebraFemales, int? zebraJuveniles,
    String? zebraResponsible, String? zebraStatus, String? zebraLightCycle,
    double? zebraTemperatureC, double? zebraPh, double? zebraConductivity,
    String? zebraHealthStatus, String? zebraExperimentId,
    String? zebraTreatment, String? zebraFoodType, String? zebraFoodSource,
    double? zebraFoodAmount, String? zebraFeedingAmountUnit, String? zebraFeedingSchedule,
    String? zebraNotes, bool? isEightLiter, DateTime? zebraLastTankCleaning,
    DateTime? zebraLastBreeding,
  }) => ZebrafishTank(
    zebraId:               zebraId ?? this.zebraId,
    zebraTankId:           zebraTankId ?? this.zebraTankId,
    zebraTankType:         zebraTankType ?? this.zebraTankType,
    zebraRack:             zebraRack ?? this.zebraRack,
    zebraRow:              zebraRow ?? this.zebraRow,
    zebraColumn:           zebraColumn ?? this.zebraColumn,
    zebraCapacity:         zebraCapacity ?? this.zebraCapacity,
    zebraVolumeL:          zebraVolumeL ?? this.zebraVolumeL,
    zebraLine:             zebraLine ?? this.zebraLine,
    zebraLineId:           zebraLineId ?? this.zebraLineId,
    zebraMales:            zebraMales ?? this.zebraMales,
    zebraFemales:          zebraFemales ?? this.zebraFemales,
    zebraJuveniles:        zebraJuveniles ?? this.zebraJuveniles,
    zebraResponsible:      zebraResponsible ?? this.zebraResponsible,
    zebraStatus:           zebraStatus ?? this.zebraStatus,
    zebraLightCycle:       zebraLightCycle ?? this.zebraLightCycle,
    zebraTemperatureC:     zebraTemperatureC ?? this.zebraTemperatureC,
    zebraConductivity:     zebraConductivity ?? this.zebraConductivity,
    zebraPh:               zebraPh ?? this.zebraPh,
    zebraLastTankCleaning: zebraLastTankCleaning ?? this.zebraLastTankCleaning,
    zebraCleaningIntervalDays: zebraCleaningIntervalDays,
    zebraFoodType:         zebraFoodType ?? this.zebraFoodType,
    zebraFoodSource:       zebraFoodSource ?? this.zebraFoodSource,
    zebraFoodAmount:       zebraFoodAmount ?? this.zebraFoodAmount,
    zebraFeedingAmountUnit: zebraFeedingAmountUnit ?? this.zebraFeedingAmountUnit,
    zebraFeedingSchedule:  zebraFeedingSchedule ?? this.zebraFeedingSchedule,
    zebraLastHealthCheck:  zebraLastHealthCheck,
    zebraHealthStatus:     zebraHealthStatus ?? this.zebraHealthStatus,
    zebraTreatment:        zebraTreatment ?? this.zebraTreatment,
    zebraExperimentId:     zebraExperimentId ?? this.zebraExperimentId,
    zebraEthicsApproval:   zebraEthicsApproval,
    zebraLastBreeding:     zebraLastBreeding ?? this.zebraLastBreeding,
    zebraNotes:            zebraNotes ?? this.zebraNotes,
    zebraCreatedAt:        zebraCreatedAt,
    isEightLiter:          isEightLiter ?? this.isEightLiter,
    isTopRow:              isTopRow,
    rackRowIndex:          rackRowIndex,
    rackColIndex:          rackColIndex,
  );

  int get totalFish => (zebraMales ?? 0) + (zebraFemales ?? 0) + (zebraJuveniles ?? 0);
  bool get isEmpty => zebraStatus == 'empty' || zebraLine == null;
  String get volumeLabel => isTopRow ? '1.5L' : isEightLiter ? '8L' : '3.5L';
}
