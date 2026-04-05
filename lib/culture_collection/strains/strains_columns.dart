// strains_columns.dart - Column definitions for the strains grid: field key,
// header label, width, sortability, editability.


class StrainColDef {
  final String key;
  final String label;
  final double defaultWidth;
  final bool readOnly;
  final Set<String>? onlyFor;

  const StrainColDef(this.key, this.label,
      {double width = 130, this.readOnly = false, this.onlyFor})
      : defaultWidth = width;
}

const List<StrainColDef> strainAllColumns = [
  // Identity & status
  StrainColDef('strain_code',               'Code',                   width: 100, readOnly: true),
  StrainColDef('strain_status',             'Status',                 width: 100),
  StrainColDef('strain_origin',             'Origin',                 width: 60,  readOnly: true),
  StrainColDef('strain_toxins',             'Toxins',                 width: 100),
  StrainColDef('strain_situation',          'Situation',              width: 110),
  StrainColDef('strain_last_checked',       'Last Checked',           width: 120),
  StrainColDef('strain_public',             'Public',                 width: 60),
  StrainColDef('strain_private_collection', 'Private Collection',     width: 160),
  StrainColDef('strain_type_strain',        'Type Strain',            width: 110),
  StrainColDef('strain_biosafety_level',    'Biosafety Level',        width: 120),
  StrainColDef('strain_other_codes',        'Other Codes',            width: 130),
  // Taxonomy
  StrainColDef('strain_empire',             'Empire',                 width: 100),
  StrainColDef('strain_kingdom',            'Kingdom',                width: 110),
  StrainColDef('strain_phylum',             'Phylum',                 width: 110),
  StrainColDef('strain_class',              'Class',                  width: 110),
  StrainColDef('strain_order',              'Order',                  width: 110),
  StrainColDef('strain_family',             'Family',                 width: 120),
  StrainColDef('strain_genus',              'Genus',                  width: 120),
  StrainColDef('strain_species',            'Species',                width: 140),
  StrainColDef('strain_subspecies',         'Subspecies',             width: 130),
  StrainColDef('strain_variety',            'Variety',                width: 110),
  StrainColDef('strain_scientific_name',    'Scientific Name',        width: 180),
  StrainColDef('strain_authority',          'Authority',              width: 140),
  StrainColDef('strain_other_names',        'Other Names / Old ID',   width: 170),
  StrainColDef('strain_taxonomist',         'Taxonomist',             width: 130),
  StrainColDef('strain_identification_method', 'ID Method',           width: 130),
  StrainColDef('strain_identification_date',   'ID Date',             width: 120),
  // Morphology
  StrainColDef('strain_morphology',         'Morphology',             width: 120),
  StrainColDef('strain_cell_shape',         'Cell Shape',             width: 110),
  StrainColDef('strain_cell_size_um',       'Cell Size (µm)',         width: 120),
  StrainColDef('strain_motility',           'Motility',               width: 100),
  StrainColDef('strain_pigments',           'Pigments',               width: 110),
  StrainColDef('strain_colonial_morphology','Colonial Morphology',    width: 160),
  // Photos
  StrainColDef('strain_photo',              'Photo',                  width: 100),
  StrainColDef('strain_public_photo',       'Public Photo',           width: 120),
  StrainColDef('strain_microscopy_photo',   'Microscopy Photo',       width: 150),
  // Herbarium
  StrainColDef('strain_herbarium_code',     'Herbarium Code',         width: 130),
  StrainColDef('strain_herbarium_name',     'Herbarium Name',         width: 150),
  StrainColDef('strain_herbarium_status',   'Herbarium Status',       width: 140),
  StrainColDef('strain_herbarium_date',     'Herbarium Date',         width: 130),
  StrainColDef('strain_herbarium_method',   'Herbarium Method',       width: 140),
  StrainColDef('strain_herbarium_notes',    'Herbarium Notes',        width: 160),
  // Culture maintenance
  StrainColDef('strain_last_transfer',      'Last Transfer',          width: 120),
  StrainColDef('strain_periodicity',        'Cycle (Days)',           width: 100),
  StrainColDef('strain_next_transfer',      'Next Transfer',          width: 120, readOnly: true),
  StrainColDef('strain_medium',             'Medium',                 width: 110),
  StrainColDef('strain_medium_salinity',    'Medium Salinity',        width: 130),
  StrainColDef('strain_light_cycle',        'Light Cycle',            width: 110),
  StrainColDef('strain_light_intensity_umol', 'Light (µmol)',         width: 110),
  StrainColDef('strain_temperature_c',      'Incubation °C',          width: 110),
  StrainColDef('strain_co2_pct',            'CO₂ (%)',                width: 90),
  StrainColDef('strain_aeration',           'Aeration',               width: 100),
  StrainColDef('strain_culture_vessel',     'Culture Vessel',         width: 130),
  StrainColDef('strain_room',               'Room',                   width: 100),
  // Cryopreservation
  StrainColDef('strain_cryo_date',          'Cryo Date',              width: 110),
  StrainColDef('strain_cryo_method',        'Cryo Method',            width: 120),
  StrainColDef('strain_cryo_location',      'Cryo Location',          width: 130),
  StrainColDef('strain_cryo_vials',         'Cryo Vials',             width: 100),
  StrainColDef('strain_cryo_responsible',   'Cryo Responsible',       width: 150),
  // Isolation
  StrainColDef('strain_isolation_responsible', 'Isolation Responsible', width: 170),
  StrainColDef('strain_isolation_date',     'Isolation Date',         width: 120),
  StrainColDef('strain_isolation_method',   'Isolation Method',       width: 140),
  StrainColDef('strain_deposit_date',       'Deposit Date',           width: 120),
  // Molecular — prokaryotes
  StrainColDef('strain_seq_16s_bp',         '16S (bp)',               width: 90),
  StrainColDef('strain_its',                'ITS',                    width: 80),
  StrainColDef('strain_its_bands',          'ITS Bands',              width: 160),
  StrainColDef('strain_cloned_gel',         'Cloned/GelExtraction',   width: 170),
  StrainColDef('strain_genbank_16s_its',    'GenBank (16S+ITS)',      width: 160),
  StrainColDef('strain_genbank_status',     'GenBank Status',         width: 130),
  StrainColDef('strain_genome_pct',         'Genome (%)',             width: 100),
  StrainColDef('strain_genome_cont',        'Genome (Cont.)',         width: 130),
  StrainColDef('strain_genome_16s',         'Genome (16S)',           width: 120),
  StrainColDef('strain_gca_accession',      'GCA Accession',          width: 130),
  // Molecular — eukaryotes
  StrainColDef('strain_seq_18s_bp',         '18S (bp)',               width: 90),
  StrainColDef('strain_genbank_18s',        'GenBank (18S)',          width: 130),
  StrainColDef('strain_its2_bp',            'ITS2 (bp)',              width: 90),
  StrainColDef('strain_genbank_its2',       'GenBank (ITS2)',         width: 130),
  StrainColDef('strain_rbcl_bp',            'rbcL (bp)',              width: 90),
  StrainColDef('strain_genbank_rbcl',       'GenBank (rbcL)',         width: 130),
  StrainColDef('strain_tufa_bp',            'tufA (bp)',              width: 90),
  StrainColDef('strain_genbank_tufa',       'GenBank (tufA)',         width: 130),
  StrainColDef('strain_cox1_bp',            'COX1 (bp)',              width: 90),
  StrainColDef('strain_genbank_cox1',       'GenBank (COX1)',         width: 130),
  // Bioactivity & references
  StrainColDef('strain_bioactivity',        'Bioactivity',            width: 130),
  StrainColDef('strain_metabolites',        'Metabolites',            width: 130),
  StrainColDef('strain_industrial_use',     'Industrial Use',         width: 130),
  StrainColDef('strain_growth_rate',        'Growth Rate',            width: 120),
  StrainColDef('strain_publications',       'Publications',           width: 150),
  StrainColDef('strain_external_links',     'External Links',         width: 150),
  StrainColDef('strain_notes',              'Notes',                  width: 180),
  StrainColDef('strain_qrcode',             'QR Code',                width: 100),
  // Sample mirror fields (read-only, joined from samples table)
  StrainColDef('s_rebeca',        'Sample REBECA',       width: 130, readOnly: true),
  StrainColDef('s_ccpi',          'Sample CCPI',         width: 110, readOnly: true),
  StrainColDef('s_date',          'Sample Date',         width: 110, readOnly: true),
  StrainColDef('s_country',       'Country',             width: 120, readOnly: true),
  StrainColDef('s_archipelago',   'Archipelago',         width: 130, readOnly: true),
  StrainColDef('s_island',        'Island',              width: 110, readOnly: true),
  StrainColDef('s_municipality',  'Municipality',        width: 140, readOnly: true),
  StrainColDef('s_local',         'Local',               width: 140, readOnly: true),
  StrainColDef('s_habitat_type',  'Habitat Type',        width: 120, readOnly: true),
  StrainColDef('s_habitat_1',     'Habitat 1',           width: 120, readOnly: true),
  StrainColDef('s_habitat_2',     'Habitat 2',           width: 120, readOnly: true),
  StrainColDef('s_habitat_3',     'Habitat 3',           width: 120, readOnly: true),
  StrainColDef('s_method',        'Method',              width: 120, readOnly: true),
  StrainColDef('s_gps',           'GPS',                 width: 160, readOnly: true),
  StrainColDef('s_temperature',   '°C',                  width: 70,  readOnly: true),
  StrainColDef('s_ph',            'pH',                  width: 70,  readOnly: true),
  StrainColDef('s_conductivity',  'µS/cm',               width: 90,  readOnly: true),
  StrainColDef('s_oxygen',        'O₂ (mg/L)',           width: 90,  readOnly: true),
  StrainColDef('s_salinity',      'Salinity',            width: 100, readOnly: true),
  StrainColDef('s_radiation',     'Solar Radiation',     width: 130, readOnly: true),
  StrainColDef('s_responsible',   'Sampling Responsible',width: 160, readOnly: true),
  StrainColDef('s_observations',  'Sample Observations', width: 180, readOnly: true),
];
