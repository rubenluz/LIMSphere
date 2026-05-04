const List<String> mirriMicroorganismHeaders = [
  'AccessionNumber',
  'OrganismType',
  'Genus',
  'Species',
  'UseRestrictions',
  'NagoyaConditions',
  'RiskGroup',
  'FormOfSupply',
  'RecommendedMediumGrowth',
  'RecommendedTempGrowth',
  'EUQuarantine',
  'GMO',
  'GMOConstructionInfo',
  'DualUse',
  'SexualState',
  'TestedTempGrowthRange',
  'TypeStrain',
  'Status',
  'Literature',
  'SequenceLiterature',
  'GeoOrigin',
  'Collector',
  'CollectionDate',
  'Depositor',
  'DepositDate',
  'Isolator',
  'IsolationDate',
  'InclusionDate',
  'Substrate',
  'IsolationHabitat',
  'RegisteredCollection',
  'OtherCCNumbers',
  'ABSRelatedFiles',
  'InfrasubspecificNames',
  'CommentOnTaxonomy',
  'HistoryOfDeposit',
  'OtherDenomination',
  'MutantInformation',
  'Genotype',
  'Ploidy',
  'InterspecificHybrid',
  'Pathogenicity',
  'EnzymeProduction',
  'ProductionOfMetabolites',
  'Applications',
  'Remarks',
  'Plasmids',
  'PlasmidsCollectionsFields',
  'OntobiotopeTerms',
  'Links',
  'QPS',
  'Axenic',
  'IdentificationTechnique',
  'AvailableForDis',
  'AvailableAtCC',
  'Clinical',
  'PublicData',
];

String buildMirriMicroorganismsCsv(List<Map<String, dynamic>> rows) {
  final buffer = StringBuffer()..writeln(_csvLine(mirriMicroorganismHeaders));
  for (final row in rows) {
    buffer.writeln(_csvLine(_buildMirriMicroorganismRow(row)));
  }
  return buffer.toString();
}

List<String> _buildMirriMicroorganismRow(Map<String, dynamic> row) => [
  _text(row['strain_code']),
  _text(row['strain_organism_type']),
  _text(row['strain_genus']),
  _text(row['strain_species']),
  _mirriFlag(row['strain_use_restrictions'], trueValue: '2', falseValue: '1'),
  _mirriTriState(row['strain_nagoya_conditions']),
  _riskGroup(row),
  _text(row['strain_form_of_supply']),
  _text(row['strain_medium']),
  _number(row['strain_temperature_c']),
  _mirriFlag(row['strain_eu_quarantine']),
  _mirriFlag(row['strain_gmo']),
  _text(row['strain_gmo_construction_info']),
  _mirriFlag(row['strain_dual_use']),
  _text(row['strain_sexual_state']),
  _text(row['strain_tested_temp_growth_range']),
  _mirriFlag(row['strain_type_strain']),
  _text(row['strain_type_status']),
  _text(row['strain_literature_ids']).isNotEmpty
      ? _text(row['strain_literature_ids'])
      : _text(row['strain_publications']),
  _text(row['strain_sequence_literature_ids']),
  _geoOrigin(row),
  _text(row['s_collector']),
  _text(row['s_date']),
  _text(row['strain_depositor']),
  _text(row['strain_deposit_date']),
  _text(row['strain_isolation_responsible']),
  _text(row['strain_isolation_date']),
  _text(row['strain_inclusion_date']),
  _text(row['s_substrate']),
  _isolationHabitat(row),
  _mirriFlag(row['strain_registered_collection']),
  _text(row['strain_other_codes']),
  _text(row['strain_abs_related_files']),
  _text(row['strain_infrasubspecific_names']),
  _text(row['strain_taxonomy_comments']),
  _text(row['strain_deposit_history']),
  _text(row['strain_other_names']),
  _text(row['strain_mutant_information']),
  _text(row['strain_genotype']),
  _text(row['strain_ploidy']),
  _mirriFlag(row['strain_interspecific_hybrid']),
  _text(row['strain_pathogenicity']),
  _text(row['strain_enzyme_production']),
  _text(row['strain_metabolites']),
  _text(row['strain_applications']).isNotEmpty
      ? _text(row['strain_applications'])
      : _text(row['strain_industrial_use']),
  _text(row['strain_notes']),
  _text(row['strain_plasmids']),
  _text(row['strain_plasmids_collection_fields']),
  _text(row['strain_ontobiotope_terms']),
  _text(row['strain_external_links']),
  _mirriFlag(row['strain_qps']),
  _axenicValue(row['strain_axenic']),
  _text(row['strain_identification_method']),
  _mirriWorkbookFlag(row['strain_available_for_distribution']),
  _mirriWorkbookFlag(row['strain_available_at_cc']),
  _mirriWorkbookFlag(row['strain_clinical']),
  _mirriWorkbookFlag(
    _text(row['strain_public_data']).isNotEmpty
        ? row['strain_public_data']
        : row['strain_public'],
  ),
];

String _text(dynamic value) => value?.toString().trim() ?? '';

String _number(dynamic value) {
  if (value == null) return '';
  if (value is int) return value.toString();
  if (value is double) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
  return _text(value);
}

String _mirriFlag(
  dynamic value, {
  String trueValue = '2',
  String falseValue = '1',
}) {
  final raw = _text(value);
  if (raw.isEmpty) return '';
  final lower = raw.toLowerCase();
  if (raw == trueValue || raw == falseValue) return raw;
  if (['yes', 'y', 'true'].contains(lower)) return trueValue;
  if (['no', 'n', 'false'].contains(lower)) return falseValue;
  return raw;
}

String _mirriTriState(dynamic value) {
  final raw = _text(value);
  if (raw.isEmpty) return '';
  if (['1', '2', '3'].contains(raw)) return raw;
  return switch (raw.toLowerCase()) {
    'no known restrictions under the nagoya protocol' => '1',
    'documents providing proof of legal access and terms of use available at the collection' =>
      '2',
    'strain probably in scope, please contact the culture collection' => '3',
    _ => raw,
  };
}

String _mirriWorkbookFlag(dynamic value) {
  final raw = _text(value);
  if (raw.isEmpty) return '';
  final lower = raw.toLowerCase();
  if (['1', '2', '3', '4'].contains(raw)) return raw;
  if (['yes', 'y', 'true', 'public'].contains(lower)) return '2';
  if (['no', 'n', 'false', 'private', 'restricted'].contains(lower)) return '1';
  return raw;
}

String _axenicValue(dynamic value) {
  final raw = _text(value);
  if (raw.isEmpty) return '';
  final lower = raw.toLowerCase();
  if (lower == 'axenic' || lower == 'not axenic') return raw;
  if (['yes', 'y', 'true', '1', '2'].contains(lower)) return 'Axenic';
  if (['no', 'n', 'false', '0'].contains(lower)) return 'Not axenic';
  return raw;
}

String _riskGroup(Map<String, dynamic> row) {
  final direct = _text(row['strain_risk_group']);
  if (direct.isNotEmpty) return direct;
  final biosafety = _text(row['strain_biosafety_level']);
  final match = RegExp(r'(\d+)').firstMatch(biosafety);
  return match?.group(1) ?? '';
}

String _geoOrigin(Map<String, dynamic> row) {
  final parts = <String>[
    _text(row['s_local']),
    _text(row['s_municipality']),
    _text(row['s_island']),
    _text(row['s_archipelago']),
    _text(row['s_region']),
    _text(row['s_country']),
  ].where((value) => value.isNotEmpty).toList();
  if (parts.isEmpty) return _text(row['strain_origin']);
  return _dedupe(parts).join(', ');
}

String _isolationHabitat(Map<String, dynamic> row) {
  final parts = <String>[
    _text(row['s_habitat_type']),
    _text(row['s_habitat_1']),
    _text(row['s_habitat_2']),
    _text(row['s_habitat_3']),
  ].where((value) => value.isNotEmpty).toList();
  return _dedupe(parts).join('; ');
}

List<String> _dedupe(List<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final key = value.toLowerCase();
    if (seen.add(key)) result.add(value);
  }
  return result;
}

String _csvLine(List<String> values) {
  return values.map((value) => '"${value.replaceAll('"', '""')}"').join(',');
}
