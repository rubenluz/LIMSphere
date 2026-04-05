// samples_columns.dart - Column definitions for the samples data grid:
// field keys, header labels, widths.


class SampleColDef {
  final String key;
  final String label;
  final double defaultWidth;
  final bool readOnly;
  const SampleColDef(this.key, this.label, {double width = 130, this.readOnly = false})
      : defaultWidth = width;
}

const List<SampleColDef> sampleAllColumns = [
  // Identifiers
  SampleColDef('sample_code',         'Code',                    width: 60,  readOnly: true),
  SampleColDef('sample_rebeca',       'REBECA',                width: 80),
  SampleColDef('sample_ccpi',         'CCPI',                  width: 110),
  SampleColDef('sample_permit',       'Permit',                width: 120),
  SampleColDef('sample_other_code',   'Other Code',            width: 120),
  // Collection event
  SampleColDef('sample_date',         'Date',                  width: 110),
  SampleColDef('sample_collector',    'Collector',             width: 130),
  SampleColDef('sample_responsible',  'Responsible',           width: 140),
  // Geography
  SampleColDef('sample_country',      'Country',               width: 120),
  SampleColDef('sample_archipelago',  'Archipelago',           width: 130),
  SampleColDef('sample_island',       'Island',                width: 120),
  SampleColDef('sample_region',       'Region',                width: 120),
  SampleColDef('sample_municipality', 'Municipality',          width: 140),
  SampleColDef('sample_parish',       'Parish',                width: 120),
  SampleColDef('sample_local',        'Local',                 width: 150),
  SampleColDef('sample_gps',          'GPS',                   width: 180),
  SampleColDef('sample_latitude',     'Latitude',              width: 100),
  SampleColDef('sample_longitude',    'Longitude',             width: 110),
  SampleColDef('sample_altitude_m',   'Altitude (m)',          width: 110),
  // Habitat
  SampleColDef('sample_habitat_type', 'Habitat Type',          width: 130),
  SampleColDef('sample_habitat_1',    'Habitat 1',             width: 130),
  SampleColDef('sample_habitat_2',    'Habitat 2',             width: 130),
  SampleColDef('sample_habitat_3',    'Habitat 3',             width: 130),
  SampleColDef('sample_substrate',    'Substrate',             width: 120),
  SampleColDef('sample_method',       'Method',                width: 130),
  // Physical-chemical
  SampleColDef('sample_temperature',  '°C',                    width: 70),
  SampleColDef('sample_ph',           'pH',                    width: 70),
  SampleColDef('sample_conductivity', 'µS/cm',                 width: 100),
  SampleColDef('sample_oxygen',       'O₂ (mg/L)',             width: 100),
  SampleColDef('sample_salinity',     'Salinity',              width: 100),
  SampleColDef('sample_radiation',    'Solar Radiation',       width: 130),
  SampleColDef('sample_turbidity',    'Turbidity (NTU)',       width: 130),
  SampleColDef('sample_depth_m',      'Depth (m)',             width: 100),
  // Biological context
  SampleColDef('sample_bloom',        'Bloom',                 width: 120),
  SampleColDef('sample_associated_organisms', 'Associated Organisms', width: 170),
  // Logistics
  SampleColDef('sample_photos',       'Photos',                width: 100),
  SampleColDef('sample_preservation', 'Preservation',          width: 130),
  SampleColDef('sample_transport_time_h', 'Transport (h)',     width: 120),
  // Admin
  SampleColDef('sample_project',      'Project',               width: 130),
  SampleColDef('sample_observations', 'Observations',          width: 200),
];
