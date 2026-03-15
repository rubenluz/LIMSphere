/// Single source of truth for fish facility DB table names and column names.
///
/// Usage: reference these constants in models (fromMap/toMap) and in page
/// queries, so that renaming a column in core_tables_sql.dart only requires
/// updating the matching constant here — all models and queries update
/// automatically via the Dart constant reference.
///
/// Always keep in sync with core_tables_sql.dart.
abstract class FishSch {
  // ── Table names ────────────────────────────────────────────────────────────
  static const linesTable  = 'fish_lines';
  static const stocksTable = 'fish_stocks';

  // ── fish_lines columns ─────────────────────────────────────────────────────
  static const lineId                 = 'fish_line_id';
  static const lineName               = 'fish_line_name';
  static const lineAlias              = 'fish_line_alias';
  static const lineType               = 'fish_line_type';
  static const lineStatus             = 'fish_line_status';
  static const lineGenotype           = 'fish_line_genotype';
  static const lineZygosity           = 'fish_line_zygosity';
  static const lineGeneration         = 'fish_line_generation';
  static const lineAffectedGene       = 'fish_line_affected_gene';
  static const lineAffectedChromosome = 'fish_line_affected_chromosome';
  static const lineMutationType       = 'fish_line_mutation_type';
  static const lineMutationDesc       = 'fish_line_mutation_description';
  static const lineTransgene          = 'fish_line_transgene';
  static const lineConstruct          = 'fish_line_construct';
  static const linePromoter           = 'fish_line_promoter';
  static const lineReporter           = 'fish_line_reporter';
  static const lineTargetTissue       = 'fish_line_target_tissue';
  static const lineOriginLab          = 'fish_line_origin_lab';
  static const lineOriginPerson       = 'fish_line_origin_person';
  static const lineDateBirth          = 'fish_line_date_birth';
  static const lineDateReceived       = 'fish_line_date_received';
  static const lineSource             = 'fish_line_source';
  static const lineImportPermit       = 'fish_line_import_permit';
  static const lineMta                = 'fish_line_mta';
  static const lineZfinId             = 'fish_line_zfin_id';
  static const linePubmed             = 'fish_line_pubmed';
  static const lineDoi                = 'fish_line_doi';
  static const lineCryopreserved      = 'fish_line_cryopreserved';
  static const lineCryoLocation       = 'fish_line_cryo_location';
  static const lineCryoDate           = 'fish_line_cryo_date';
  static const lineCryoMethod         = 'fish_line_cryo_method';
  static const linePhenotype          = 'fish_line_phenotype';
  static const lineLethality          = 'fish_line_lethality';
  static const lineHealthNotes        = 'fish_line_health_notes';
  static const lineSpfStatus          = 'fish_line_spf_status';
  static const lineRiskLevel          = 'fish_line_risk_level';
  static const lineResponsibleId      = 'fish_line_responsible_id';
  static const lineTankCount          = 'fish_line_tank_count';
  static const lineQrcode             = 'fish_line_qrcode';
  static const lineBarcode            = 'fish_line_barcode';
  static const lineCreatedAt          = 'fish_line_created_at';
  static const lineUpdatedAt          = 'fish_line_updated_at';
  static const lineBreeders           = 'fish_line_breeders';
  static const lineNotes              = 'fish_line_notes';

  // ── fish_stocks columns ────────────────────────────────────────────────────
  static const stockId               = 'fish_stocks_id';
  static const stockTankId           = 'fish_stocks_tank_id';
  static const stockTankType         = 'fish_stocks_tank_type';
  static const stockRack             = 'fish_stocks_rack';
  static const stockRow              = 'fish_stocks_row';
  static const stockColumn           = 'fish_stocks_column';
  static const stockCapacity         = 'fish_stocks_capacity';
  static const stockVolumeL          = 'fish_stocks_volume_l';
  static const stockLine             = 'fish_stocks_line';
  static const stockLineId           = 'fish_stocks_line_id';
  static const stockMales            = 'fish_stocks_males';
  static const stockFemales          = 'fish_stocks_females';
  static const stockJuveniles        = 'fish_stocks_juveniles';
  static const stockMortality        = 'fish_stocks_mortality';
  static const stockArrivalDate      = 'fish_stocks_arrival_date';
  static const stockOrigin           = 'fish_stocks_origin';
  static const stockResponsible      = 'fish_stocks_responsible';
  static const stockResponsibleId    = 'fish_stocks_responsible_id';
  static const stockStatus           = 'fish_stocks_status';
  static const stockSentinelStatus   = 'fish_stocks_sentinel_status';
  static const stockLightCycle       = 'fish_stocks_light_cycle';
  static const stockTemperatureC     = 'fish_stocks_temperature_c';
  static const stockConductivity     = 'fish_stocks_conductivity';
  static const stockPh               = 'fish_stocks_ph';
  static const stockLastCleaning     = 'fish_stocks_last_tank_cleaning';
  static const stockCleaningInterval = 'fish_stocks_cleaning_interval_days';
  static const stockFoodType         = 'fish_stocks_food_type';
  static const stockFoodSource       = 'fish_stocks_food_source';
  static const stockFoodAmount       = 'fish_stocks_food_amount';
  static const stockFeedingSchedule  = 'fish_stocks_feeding_schedule';
  static const stockLastHealthCheck  = 'fish_stocks_last_health_check';
  static const stockHealthStatus     = 'fish_stocks_health_status';
  static const stockTreatment        = 'fish_stocks_treatment';
  static const stockLastBreeding     = 'fish_stocks_last_breeding';
  static const stockCrossId          = 'fish_stocks_cross_id';
  static const stockBreedingGroup    = 'fish_stocks_breeding_group';
  static const stockLastCountDate    = 'fish_stocks_last_count_date';
  static const stockExperimentId     = 'fish_stocks_experiment_id';
  static const stockEthicsApproval   = 'fish_stocks_ethics_approval';
  static const stockNotes            = 'fish_stocks_notes';
  static const stockCreatedAt        = 'fish_stocks_created_at';
  static const stockUpdatedAt        = 'fish_stocks_updated_at';
}
