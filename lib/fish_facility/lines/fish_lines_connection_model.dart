// fish_lines_connection_model.dart - FishLine data model: maps to the
// fish_lines Supabase table; genetics/transgene fields, fromMap serialisation.

import '/core/fish_db_schema.dart';

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
  DateTime? fishlineDateBirth;
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
  String? fishlineBreeders;
  String? fishlineNotes;

  /// Aggregated from fish_stocks — populated post-load, not stored in DB.
  int stockMales     = 0;
  int stockFemales   = 0;
  int stockJuveniles = 0;
  int stockTotal     = 0;

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
    this.fishlineDateBirth,
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
    this.fishlineBreeders,
    this.fishlineNotes,
  });

  factory FishLine.fromMap(Map<String, dynamic> m) => FishLine(
    fishlineId:               m[FishSch.lineId] as int?,
    fishlineName:             m[FishSch.lineName] as String,
    fishlineAlias:            m[FishSch.lineAlias] as String?,
    fishlineType:             m[FishSch.lineType] as String?,
    fishlineStatus:           m[FishSch.lineStatus] as String?,
    fishlineGenotype:         m[FishSch.lineGenotype] as String?,
    fishlineZygosity:         m[FishSch.lineZygosity] as String?,
    fishlineGeneration:       m[FishSch.lineGeneration] as String?,
    fishlineAffectedGene:     m[FishSch.lineAffectedGene] as String?,
    fishlineAffectedChromosome: m[FishSch.lineAffectedChromosome] as String?,
    fishlineMutationType:     m[FishSch.lineMutationType] as String?,
    fishlineMutationDescription: m[FishSch.lineMutationDesc] as String?,
    fishlineTransgene:        m[FishSch.lineTransgene] as String?,
    fishlineConstruct:        m[FishSch.lineConstruct] as String?,
    fishlinePromoter:         m[FishSch.linePromoter] as String?,
    fishlineReporter:         m[FishSch.lineReporter] as String?,
    fishlineTargetTissue:     m[FishSch.lineTargetTissue] as String?,
    fishlineOriginLab:        m[FishSch.lineOriginLab] as String?,
    fishlineOriginPerson:     m[FishSch.lineOriginPerson] as String?,
    fishlineDateBirth: m[FishSch.lineDateBirth] != null
        ? DateTime.tryParse(m[FishSch.lineDateBirth]) : null,
    fishlineDateReceived: m[FishSch.lineDateReceived] != null
        ? DateTime.tryParse(m[FishSch.lineDateReceived]) : null,
    fishlineSource:           m[FishSch.lineSource] as String?,
    fishlineImportPermit:     m[FishSch.lineImportPermit] as String?,
    fishlineMta:              m[FishSch.lineMta] as String?,
    fishlineZfinId:           m[FishSch.lineZfinId] as String?,
    fishlinePubmed:           m[FishSch.linePubmed] as String?,
    fishlineDoi:              m[FishSch.lineDoi] as String?,
    fishlineCryopreserved:    m[FishSch.lineCryopreserved] as bool? ?? false,
    fishlineCryoLocation:     m[FishSch.lineCryoLocation] as String?,
    fishlineCryoDate: m[FishSch.lineCryoDate] != null
        ? DateTime.tryParse(m[FishSch.lineCryoDate]) : null,
    fishlineCryoMethod:       m[FishSch.lineCryoMethod] as String?,
    fishlinePhenotype:        m[FishSch.linePhenotype] as String?,
    fishlineLethality:        m[FishSch.lineLethality] as String?,
    fishlineHealthNotes:      m[FishSch.lineHealthNotes] as String?,
    fishlineSpfStatus:        m[FishSch.lineSpfStatus] as String?,
    fishlineRiskLevel:        m[FishSch.lineRiskLevel] as String?,
    fishlineQrcode:           m[FishSch.lineQrcode] as String?,
    fishlineBarcode:          m[FishSch.lineBarcode] as String?,
    fishlineCreatedAt: m[FishSch.lineCreatedAt] != null
        ? DateTime.tryParse(m[FishSch.lineCreatedAt]) : null,
    fishlineUpdatedAt: m[FishSch.lineUpdatedAt] != null
        ? DateTime.tryParse(m[FishSch.lineUpdatedAt]) : null,
    fishlineBreeders:         m[FishSch.lineBreeders] as String?,
    fishlineNotes:            m[FishSch.lineNotes] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (fishlineId != null) FishSch.lineId: fishlineId,
    FishSch.lineName:               fishlineName,
    FishSch.lineAlias:              fishlineAlias,
    FishSch.lineType:               fishlineType,
    FishSch.lineStatus:             fishlineStatus,
    FishSch.lineGenotype:           fishlineGenotype,
    FishSch.lineZygosity:           fishlineZygosity,
    FishSch.lineGeneration:         fishlineGeneration,
    FishSch.lineAffectedGene:       fishlineAffectedGene,
    FishSch.lineAffectedChromosome: fishlineAffectedChromosome,
    FishSch.lineMutationType:       fishlineMutationType,
    FishSch.lineMutationDesc:       fishlineMutationDescription,
    FishSch.lineTransgene:          fishlineTransgene,
    FishSch.lineConstruct:          fishlineConstruct,
    FishSch.linePromoter:           fishlinePromoter,
    FishSch.lineReporter:           fishlineReporter,
    FishSch.lineTargetTissue:       fishlineTargetTissue,
    FishSch.lineOriginLab:          fishlineOriginLab,
    FishSch.lineOriginPerson:       fishlineOriginPerson,
    FishSch.lineDateBirth:     fishlineDateBirth?.toIso8601String().split('T')[0],
    FishSch.lineDateReceived:  fishlineDateReceived?.toIso8601String().split('T')[0],
    FishSch.lineSource:             fishlineSource,
    FishSch.lineImportPermit:       fishlineImportPermit,
    FishSch.lineMta:                fishlineMta,
    FishSch.lineZfinId:             fishlineZfinId,
    FishSch.linePubmed:             fishlinePubmed,
    FishSch.lineDoi:                fishlineDoi,
    FishSch.lineCryopreserved:      fishlineCryopreserved,
    FishSch.lineCryoLocation:       fishlineCryoLocation,
    FishSch.lineCryoDate:      fishlineCryoDate?.toIso8601String().split('T')[0],
    FishSch.lineCryoMethod:         fishlineCryoMethod,
    FishSch.linePhenotype:          fishlinePhenotype,
    FishSch.lineLethality:          fishlineLethality,
    FishSch.lineHealthNotes:        fishlineHealthNotes,
    FishSch.lineSpfStatus:          fishlineSpfStatus,
    FishSch.lineRiskLevel:          fishlineRiskLevel,
    FishSch.lineQrcode:             fishlineQrcode,
    FishSch.lineBarcode:            fishlineBarcode,
    FishSch.lineBreeders:           fishlineBreeders,
    FishSch.lineNotes:              fishlineNotes,
  };
}
