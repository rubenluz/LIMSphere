// lib/models/connection_model.dart

class ConnectionModel {
  String name;
  String url;
  String anonKey;
  DateTime? lastConnected;

  ConnectionModel({
    required this.name,
    required this.url,
    required this.anonKey,
    this.lastConnected,
  });

  factory ConnectionModel.fromJson(Map<String, dynamic> json) => ConnectionModel(
        name: json['name'] as String,
        url: json['url'] as String,
        anonKey: json['anonKey'] as String,
        lastConnected: json['lastConnected'] != null
            ? DateTime.tryParse(json['lastConnected'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'anonKey': anonKey,
        'lastConnected': lastConnected?.toIso8601String(),
      };
}
// ─── ZEBRAFISH TANK MODEL ─────────────────────────────────────────────────────
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
  final String? zebraGenotype;
  final int? zebraMales;
  final int? zebraFemales;
  final int? zebraJuveniles;
  final DateTime? zebraDob;
  final String? zebraResponsible;
  final String? zebraStatus;
  final String? zebraLightCycle;
  final double? zebraTemperatureC;
  final double? zebraConductivity;
  final double? zebraPh;
  final DateTime? zebraLastTankCleaning;
  final int? zebraCleaningIntervalDays;
  final String? zebraFeedingSchedule;
  final DateTime? zebraLastHealthCheck;
  final String? zebraHealthStatus;
  final String? zebraTreatment;
  final String? zebraExperimentId;
  final String? zebraEthicsApproval;
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
    this.zebraGenotype,
    this.zebraMales,
    this.zebraFemales,
    this.zebraJuveniles,
    this.zebraDob,
    this.zebraResponsible,
    this.zebraStatus,
    this.zebraLightCycle,
    this.zebraTemperatureC,
    this.zebraConductivity,
    this.zebraPh,
    this.zebraLastTankCleaning,
    this.zebraCleaningIntervalDays,
    this.zebraFeedingSchedule,
    this.zebraLastHealthCheck,
    this.zebraHealthStatus,
    this.zebraTreatment,
    this.zebraExperimentId,
    this.zebraEthicsApproval,
    this.zebraNotes,
    this.zebraCreatedAt,
    this.isEightLiter = false,
    this.isTopRow = false,
    this.rackRowIndex = 0,
    this.rackColIndex = 0,
  });

  factory ZebrafishTank.fromMap(Map<String, dynamic> m) => ZebrafishTank(
    zebraId: m['zebra_id'] as int?,
    zebraTankId: m['zebra_tank_id'] as String,
    zebraTankType: m['zebra_tank_type'] as String?,
    zebraRack: m['zebra_rack'] as String?,
    zebraRow: m['zebra_row'] as String?,
    zebraColumn: m['zebra_column'] as String?,
    zebraCapacity: m['zebra_capacity'] as int?,
    zebraVolumeL: (m['zebra_volume_l'] as num?)?.toDouble(),
    zebraLine: m['zebra_line'] as String?,
    zebraGenotype: m['zebra_genotype'] as String?,
    zebraMales: m['zebra_males'] as int?,
    zebraFemales: m['zebra_females'] as int?,
    zebraJuveniles: m['zebra_juveniles'] as int?,
    zebraDob: m['zebra_dob'] != null ? DateTime.tryParse(m['zebra_dob']) : null,
    zebraResponsible: m['zebra_responsible'] as String?,
    zebraStatus: m['zebra_status'] as String?,
    zebraLightCycle: m['zebra_light_cycle'] as String?,
    zebraTemperatureC: (m['zebra_temperature_c'] as num?)?.toDouble(),
    zebraConductivity: (m['zebra_conductivity'] as num?)?.toDouble(),
    zebraPh: (m['zebra_ph'] as num?)?.toDouble(),
    zebraLastTankCleaning: m['zebra_last_tank_cleaning'] != null
        ? DateTime.tryParse(m['zebra_last_tank_cleaning']) : null,
    zebraCleaningIntervalDays: m['zebra_cleaning_interval_days'] as int?,
    zebraFeedingSchedule: m['zebra_feeding_schedule'] as String?,
    zebraLastHealthCheck: m['zebra_last_health_check'] != null
        ? DateTime.tryParse(m['zebra_last_health_check']) : null,
    zebraHealthStatus: m['zebra_health_status'] as String?,
    zebraTreatment: m['zebra_treatment'] as String?,
    zebraExperimentId: m['zebra_experiment_id'] as String?,
    zebraEthicsApproval: m['zebra_ethics_approval'] as String?,
    zebraNotes: m['zebra_notes'] as String?,
    zebraCreatedAt: m['zebra_created_at'] != null
        ? DateTime.tryParse(m['zebra_created_at']) : null,
  );

  Map<String, dynamic> toMap() => {
    if (zebraId != null) 'zebra_id': zebraId,
    'zebra_tank_id': zebraTankId,
    'zebra_tank_type': zebraTankType,
    'zebra_rack': zebraRack,
    'zebra_row': zebraRow,
    'zebra_column': zebraColumn,
    'zebra_capacity': zebraCapacity,
    'zebra_volume_l': zebraVolumeL,
    'zebra_line': zebraLine,
    'zebra_genotype': zebraGenotype,
    'zebra_males': zebraMales,
    'zebra_females': zebraFemales,
    'zebra_juveniles': zebraJuveniles,
    'zebra_dob': zebraDob?.toIso8601String(),
    'zebra_responsible': zebraResponsible,
    'zebra_status': zebraStatus,
    'zebra_light_cycle': zebraLightCycle,
    'zebra_temperature_c': zebraTemperatureC,
    'zebra_conductivity': zebraConductivity,
    'zebra_ph': zebraPh,
    'zebra_last_tank_cleaning': zebraLastTankCleaning?.toIso8601String(),
    'zebra_cleaning_interval_days': zebraCleaningIntervalDays,
    'zebra_feeding_schedule': zebraFeedingSchedule,
    'zebra_last_health_check': zebraLastHealthCheck?.toIso8601String(),
    'zebra_health_status': zebraHealthStatus,
    'zebra_treatment': zebraTreatment,
    'zebra_experiment_id': zebraExperimentId,
    'zebra_ethics_approval': zebraEthicsApproval,
    'zebra_notes': zebraNotes,
  };

  ZebrafishTank copyWith({
    String? zebraTankId, String? zebraTankType, String? zebraRack,
    String? zebraRow, String? zebraColumn, int? zebraCapacity,
    double? zebraVolumeL, String? zebraLine, String? zebraGenotype,
    int? zebraMales, int? zebraFemales, int? zebraJuveniles,
    String? zebraResponsible, String? zebraStatus, String? zebraLightCycle,
    double? zebraTemperatureC, double? zebraPh, double? zebraConductivity,
    String? zebraHealthStatus, String? zebraExperimentId,
    String? zebraTreatment, String? zebraNotes, bool? isEightLiter,
  }) => ZebrafishTank(
    zebraId: zebraId,
    zebraTankId: zebraTankId ?? this.zebraTankId,
    zebraTankType: zebraTankType ?? this.zebraTankType,
    zebraRack: zebraRack ?? this.zebraRack,
    zebraRow: zebraRow ?? this.zebraRow,
    zebraColumn: zebraColumn ?? this.zebraColumn,
    zebraCapacity: zebraCapacity ?? this.zebraCapacity,
    zebraVolumeL: zebraVolumeL ?? this.zebraVolumeL,
    zebraLine: zebraLine ?? this.zebraLine,
    zebraGenotype: zebraGenotype ?? this.zebraGenotype,
    zebraMales: zebraMales ?? this.zebraMales,
    zebraFemales: zebraFemales ?? this.zebraFemales,
    zebraJuveniles: zebraJuveniles ?? this.zebraJuveniles,
    zebraDob: zebraDob,
    zebraResponsible: zebraResponsible ?? this.zebraResponsible,
    zebraStatus: zebraStatus ?? this.zebraStatus,
    zebraLightCycle: zebraLightCycle ?? this.zebraLightCycle,
    zebraTemperatureC: zebraTemperatureC ?? this.zebraTemperatureC,
    zebraConductivity: zebraConductivity ?? this.zebraConductivity,
    zebraPh: zebraPh ?? this.zebraPh,
    zebraLastTankCleaning: zebraLastTankCleaning,
    zebraCleaningIntervalDays: zebraCleaningIntervalDays,
    zebraFeedingSchedule: zebraFeedingSchedule,
    zebraLastHealthCheck: zebraLastHealthCheck,
    zebraHealthStatus: zebraHealthStatus ?? this.zebraHealthStatus,
    zebraTreatment: zebraTreatment ?? this.zebraTreatment,
    zebraExperimentId: zebraExperimentId ?? this.zebraExperimentId,
    zebraEthicsApproval: zebraEthicsApproval,
    zebraNotes: zebraNotes ?? this.zebraNotes,
    zebraCreatedAt: zebraCreatedAt,
    isEightLiter: isEightLiter ?? this.isEightLiter,
    isTopRow: isTopRow,
    rackRowIndex: rackRowIndex,
    rackColIndex: rackColIndex,
  );

  int get totalFish => (zebraMales ?? 0) + (zebraFemales ?? 0) + (zebraJuveniles ?? 0);
  bool get isEmpty => zebraStatus == 'empty' || zebraLine == null;
  String get volumeLabel => isTopRow ? '1.5L' : isEightLiter ? '8L' : '3.5L';
}

// ─── FISH STOCK MODEL ─────────────────────────────────────────────────────────
// Stocks are a logical grouping / view over tanks — stored in zebrafish_facility
// with extra stock metadata. We treat it as a separate UI entity here.
class FishStock {
  final int? id;
  final String stockId;
  String line;
  String genotype;
  int ageMonths;
  int males;
  int females;
  int juveniles;
  String tankId;
  String responsible;
  String status;
  String health;
  String? experiment;
  String? notes;
  final DateTime created;

  FishStock({
    this.id,
    required this.stockId,
    required this.line,
    required this.genotype,
    required this.ageMonths,
    required this.males,
    required this.females,
    required this.juveniles,
    required this.tankId,
    required this.responsible,
    required this.status,
    required this.health,
    this.experiment,
    this.notes,
    required this.created,
  });

  factory FishStock.fromMap(Map<String, dynamic> m) {
    int asInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final fishId = m['fish_id'] ?? m['id'];
    final ageDays = asInt(m['fish_age_days'] ?? m['age_days']);

    return FishStock(
      id: fishId is int ? fishId : int.tryParse(fishId?.toString() ?? ''),
      stockId: fishId?.toString() ?? '',
      line: (m['fish_line'] ?? m['line'] ?? '').toString(),
      genotype: (m['fish_genotype'] ?? m['genotype'] ?? 'unknown').toString(),
      ageMonths: (ageDays / 30).floor(),
      males: asInt(m['fish_males'] ?? m['males']),
      females: asInt(m['fish_females'] ?? m['females']),
      juveniles: asInt(m['fish_juveniles'] ?? m['juveniles']),
      tankId: (m['fish_tank_id'] ?? m['tank_id'] ?? '').toString(),
      responsible: (m['fish_responsible'] ?? m['responsible'] ?? '').toString(),
      status: (m['fish_status'] ?? m['status'] ?? 'active').toString(),
      health: (m['fish_health_status'] ?? m['health'] ?? 'healthy').toString(),
      experiment: (m['fish_experiment_id'] ?? m['experiment'])?.toString(),
      notes: (m['fish_notes'] ?? m['notes'])?.toString(),
      created: m['fish_created_at'] != null
          ? DateTime.tryParse(m['fish_created_at'].toString()) ?? DateTime.now()
          : (m['created'] != null
              ? DateTime.tryParse(m['created'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  int get totalFish => males + females + juveniles;
}

// ─── FISH LINE MODEL ──────────────────────────────────────────────────────────
class FishLine {
  final int? fishlineId;
  String fishlineName;
  String? fishlineAlias;
  String? fishlineType;
  String? fishlineStatus;
  String? fishlineGenotype;
  String? fishlineZygosity;
  String? fishlineGeneration;
  String? fishlineAffectedGene;
  String? fishlineAffectedChromosome;
  String? fishlineMutationType;
  String? fishlineMutationDescription;
  String? fishlineTransgene;
  String? fishlineConstruct;
  String? fishlinePromoter;
  String? fishlineReporter;
  String? fishlineTargetTissue;
  String? fishlineOriginLab;
  String? fishlineOriginPerson;
  DateTime? fishlineDateCreated;
  DateTime? fishlineDateReceived;
  String? fishlineSource;
  String? fishlineImportPermit;
  String? fishlineMta;
  String? fishlineZfinId;
  String? fishlinePubmed;
  String? fishlineDoi;
  bool fishlineCryopreserved;
  String? fishlineCryoLocation;
  DateTime? fishlineCryoDate;
  String? fishlineCryoMethod;
  String? fishlinePhenotype;
  String? fishlineLethality;
  String? fishlineHealthNotes;
  String? fishlineSpfStatus;
  String? fishlineRiskLevel;
  String? fishlineQrcode;
  String? fishlineBarcode;
  final DateTime? fishlineCreatedAt;
  DateTime? fishlineUpdatedAt;
  String? fishlineNotes;

  FishLine({
    this.fishlineId,
    required this.fishlineName,
    this.fishlineAlias,
    this.fishlineType,
    this.fishlineStatus,
    this.fishlineGenotype,
    this.fishlineZygosity,
    this.fishlineGeneration,
    this.fishlineAffectedGene,
    this.fishlineAffectedChromosome,
    this.fishlineMutationType,
    this.fishlineMutationDescription,
    this.fishlineTransgene,
    this.fishlineConstruct,
    this.fishlinePromoter,
    this.fishlineReporter,
    this.fishlineTargetTissue,
    this.fishlineOriginLab,
    this.fishlineOriginPerson,
    this.fishlineDateCreated,
    this.fishlineDateReceived,
    this.fishlineSource,
    this.fishlineImportPermit,
    this.fishlineMta,
    this.fishlineZfinId,
    this.fishlinePubmed,
    this.fishlineDoi,
    this.fishlineCryopreserved = false,
    this.fishlineCryoLocation,
    this.fishlineCryoDate,
    this.fishlineCryoMethod,
    this.fishlinePhenotype,
    this.fishlineLethality,
    this.fishlineHealthNotes,
    this.fishlineSpfStatus,
    this.fishlineRiskLevel,
    this.fishlineQrcode,
    this.fishlineBarcode,
    this.fishlineCreatedAt,
    this.fishlineUpdatedAt,
    this.fishlineNotes,
  });

  factory FishLine.fromMap(Map<String, dynamic> m) => FishLine(
    fishlineId: m['fishline_id'] as int?,
    fishlineName: m['fishline_name'] as String,
    fishlineAlias: m['fishline_alias'] as String?,
    fishlineType: m['fishline_type'] as String?,
    fishlineStatus: m['fishline_status'] as String?,
    fishlineGenotype: m['fishline_genotype'] as String?,
    fishlineZygosity: m['fishline_zygosity'] as String?,
    fishlineGeneration: m['fishline_generation'] as String?,
    fishlineAffectedGene: m['fishline_affected_gene'] as String?,
    fishlineAffectedChromosome: m['fishline_affected_chromosome'] as String?,
    fishlineMutationType: m['fishline_mutation_type'] as String?,
    fishlineMutationDescription: m['fishline_mutation_description'] as String?,
    fishlineTransgene: m['fishline_transgene'] as String?,
    fishlineConstruct: m['fishline_construct'] as String?,
    fishlinePromoter: m['fishline_promoter'] as String?,
    fishlineReporter: m['fishline_reporter'] as String?,
    fishlineTargetTissue: m['fishline_target_tissue'] as String?,
    fishlineOriginLab: m['fishline_origin_lab'] as String?,
    fishlineOriginPerson: m['fishline_origin_person'] as String?,
    fishlineDateCreated: m['fishline_date_created'] != null
        ? DateTime.tryParse(m['fishline_date_created']) : null,
    fishlineDateReceived: m['fishline_date_received'] != null
        ? DateTime.tryParse(m['fishline_date_received']) : null,
    fishlineSource: m['fishline_source'] as String?,
    fishlineImportPermit: m['fishline_import_permit'] as String?,
    fishlineMta: m['fishline_mta'] as String?,
    fishlineZfinId: m['fishline_zfin_id'] as String?,
    fishlinePubmed: m['fishline_pubmed'] as String?,
    fishlineDoi: m['fishline_doi'] as String?,
    fishlineCryopreserved: m['fishline_cryopreserved'] as bool? ?? false,
    fishlineCryoLocation: m['fishline_cryo_location'] as String?,
    fishlineCryoDate: m['fishline_cryo_date'] != null
        ? DateTime.tryParse(m['fishline_cryo_date']) : null,
    fishlineCryoMethod: m['fishline_cryo_method'] as String?,
    fishlinePhenotype: m['fishline_phenotype'] as String?,
    fishlineLethality: m['fishline_lethality'] as String?,
    fishlineHealthNotes: m['fishline_health_notes'] as String?,
    fishlineSpfStatus: m['fishline_spf_status'] as String?,
    fishlineRiskLevel: m['fishline_risk_level'] as String?,
    fishlineQrcode: m['fishline_qrcode'] as String?,
    fishlineBarcode: m['fishline_barcode'] as String?,
    fishlineCreatedAt: m['fishline_created_at'] != null
        ? DateTime.tryParse(m['fishline_created_at']) : null,
    fishlineUpdatedAt: m['fishline_updated_at'] != null
        ? DateTime.tryParse(m['fishline_updated_at']) : null,
    fishlineNotes: m['fishline_notes'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (fishlineId != null) 'fishline_id': fishlineId,
    'fishline_name': fishlineName,
    'fishline_alias': fishlineAlias,
    'fishline_type': fishlineType,
    'fishline_status': fishlineStatus,
    'fishline_genotype': fishlineGenotype,
    'fishline_zygosity': fishlineZygosity,
    'fishline_generation': fishlineGeneration,
    'fishline_affected_gene': fishlineAffectedGene,
    'fishline_affected_chromosome': fishlineAffectedChromosome,
    'fishline_mutation_type': fishlineMutationType,
    'fishline_mutation_description': fishlineMutationDescription,
    'fishline_transgene': fishlineTransgene,
    'fishline_construct': fishlineConstruct,
    'fishline_promoter': fishlinePromoter,
    'fishline_reporter': fishlineReporter,
    'fishline_target_tissue': fishlineTargetTissue,
    'fishline_origin_lab': fishlineOriginLab,
    'fishline_origin_person': fishlineOriginPerson,
    'fishline_date_created': fishlineDateCreated?.toIso8601String().split('T')[0],
    'fishline_date_received': fishlineDateReceived?.toIso8601String().split('T')[0],
    'fishline_source': fishlineSource,
    'fishline_import_permit': fishlineImportPermit,
    'fishline_mta': fishlineMta,
    'fishline_zfin_id': fishlineZfinId,
    'fishline_pubmed': fishlinePubmed,
    'fishline_doi': fishlineDoi,
    'fishline_cryopreserved': fishlineCryopreserved,
    'fishline_cryo_location': fishlineCryoLocation,
    'fishline_cryo_date': fishlineCryoDate?.toIso8601String().split('T')[0],
    'fishline_cryo_method': fishlineCryoMethod,
    'fishline_phenotype': fishlinePhenotype,
    'fishline_lethality': fishlineLethality,
    'fishline_health_notes': fishlineHealthNotes,
    'fishline_spf_status': fishlineSpfStatus,
    'fishline_risk_level': fishlineRiskLevel,
    'fishline_qrcode': fishlineQrcode,
    'fishline_barcode': fishlineBarcode,
    'fishline_notes': fishlineNotes,
  };
}
