// reagent_model.dart - ReagentModel: maps to the reagents Supabase table;
// expiry tracking, quantity, minimum-quantity threshold, fromMap serialisation.

class ReagentModel {
  final int id;
  final String? code;
  final String? name;
  final String? brand;
  final String? reference;
  final String? casNumber;
  final String type;
  final String? unit;
  final double? quantity;
  final double? quantityMin;
  final String? concentration;
  final String? storageTemp;
  final int? locationId;
  final String? locationName;
  final String? position;
  final String? lotNumber;
  final DateTime? expiryDate;
  final DateTime? receivedDate;
  final DateTime? openedDate;
  final String? supplier;
  final String? hazard;
  final String? responsible;
  final String? formula;
  final String? notes;
  final String? physicalState;
  final String? qrcode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReagentModel({
    required this.id,
    required this.type,
    this.name,
    this.code,
    this.brand,
    this.reference,
    this.casNumber,
    this.unit,
    this.quantity,
    this.quantityMin,
    this.concentration,
    this.storageTemp,
    this.locationId,
    this.locationName,
    this.position,
    this.lotNumber,
    this.expiryDate,
    this.receivedDate,
    this.openedDate,
    this.supplier,
    this.hazard,
    this.responsible,
    this.formula,
    this.notes,
    this.physicalState,
    this.qrcode,
    this.createdAt,
    this.updatedAt,
  });

  factory ReagentModel.fromMap(Map<String, dynamic> m) => ReagentModel(
        id: (m['reagent_id'] as num).toInt(),
        code: m['reagent_code'] as String?,
        name: m['reagent_name'] as String?,
        type: (m['reagent_type'] as String?) ?? 'biological',
        brand: m['reagent_brand'] as String?,
        reference: m['reagent_reference'] as String?,
        casNumber: m['reagent_cas_number'] as String?,
        unit: m['reagent_unit'] as String?,
        quantity: m['reagent_quantity'] != null
            ? (m['reagent_quantity'] as num).toDouble()
            : null,
        quantityMin: m['reagent_quantity_min'] != null
            ? (m['reagent_quantity_min'] as num).toDouble()
            : null,
        concentration: m['reagent_concentration'] as String?,
        storageTemp: m['reagent_storage_temp'] as String?,
        locationId: m['reagent_location_id'] != null
            ? (m['reagent_location_id'] as num).toInt()
            : null,
        locationName: m['location_name'] as String?,
        position: m['reagent_position'] as String?,
        lotNumber: m['reagent_lot_number'] as String?,
        expiryDate: m['reagent_expiry_date'] != null
            ? DateTime.tryParse(m['reagent_expiry_date'].toString())
            : null,
        receivedDate: m['reagent_received_date'] != null
            ? DateTime.tryParse(m['reagent_received_date'].toString())
            : null,
        openedDate: m['reagent_opened_date'] != null
            ? DateTime.tryParse(m['reagent_opened_date'].toString())
            : null,
        supplier: m['reagent_supplier'] as String?,
        hazard: m['reagent_hazard'] as String?,
        responsible: m['reagent_responsible'] as String?,
        formula: m['reagent_formula'] as String?,
        notes: m['reagent_notes'] as String?,
        physicalState: m['reagent_physical_state'] as String?,
        qrcode: m['reagent_qrcode'] as String?,
        createdAt: m['reagent_created_at'] != null
            ? DateTime.tryParse(m['reagent_created_at'].toString())
            : null,
        updatedAt: m['reagent_updated_at'] != null
            ? DateTime.tryParse(m['reagent_updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toInsertMap() => {
        if (name != null) 'reagent_name': name,
        'reagent_type': type,
        if (code != null) 'reagent_code': code,
        if (brand != null) 'reagent_brand': brand,
        if (reference != null) 'reagent_reference': reference,
        if (casNumber != null) 'reagent_cas_number': casNumber,
        if (unit != null) 'reagent_unit': unit,
        if (quantity != null) 'reagent_quantity': quantity,
        if (quantityMin != null) 'reagent_quantity_min': quantityMin,
        if (concentration != null) 'reagent_concentration': concentration,
        if (storageTemp != null) 'reagent_storage_temp': storageTemp,
        if (locationId != null) 'reagent_location_id': locationId,
        if (position != null) 'reagent_position': position,
        if (lotNumber != null) 'reagent_lot_number': lotNumber,
        if (expiryDate != null)
          'reagent_expiry_date': expiryDate!.toIso8601String().substring(0, 10),
        if (receivedDate != null)
          'reagent_received_date':
              receivedDate!.toIso8601String().substring(0, 10),
        if (openedDate != null)
          'reagent_opened_date':
              openedDate!.toIso8601String().substring(0, 10),
        if (supplier != null) 'reagent_supplier': supplier,
        if (hazard != null) 'reagent_hazard': hazard,
        if (responsible != null) 'reagent_responsible': responsible,
        if (formula != null) 'reagent_formula': formula,
        if (notes != null) 'reagent_notes': notes,
        if (physicalState != null) 'reagent_physical_state': physicalState,
      };

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 30;
  bool get isLowStock =>
      quantity != null && quantityMin != null && quantity! <= quantityMin!;

  String get displayQuantity {
    if (quantity == null) return '—';
    final q = quantity! % 1 == 0
        ? quantity!.toInt().toString()
        : quantity!.toStringAsFixed(2);
    return unit != null ? '$q $unit' : q;
  }

  static const typeOptions = [
    'biological',
    'consumables',
    'ppe',
    'bioactivity_assays',
    'analytical_chemistry',
    'media_preparation',
    'cleaning_maintenance',
    'standards',
  ];
  static const tempOptions = ['RT', '4°C', '-20°C', '-80°C', 'liquid N2'];
  static const physicalStateOptions = ['liquid', 'solid', 'gas'];

  static String physicalStateLabel(String s) => switch (s) {
        'liquid' => 'Liquid',
        'solid'  => 'Solid',
        'gas'    => 'Gas',
        _        => s,
      };

  static String typeLabel(String t) => switch (t) {
        'chemicals_general'    => 'Chemicals (General)',
        'biological'           => 'Biological',
        'consumables'          => 'Consumables',
        'ppe'                  => 'PPE',
        'bioactivity_assays'   => 'Assays',
        'analytical_chemistry' => 'Analytical & Chemistry',
        'media_preparation'    => 'Media Preparation',
        'cleaning_maintenance' => 'Cleaning & Maintenance',
        'standards'            => 'Standarts',
        'standarts'            => 'Standarts',
        // legacy fallbacks
        'chemical'   => 'Chemicals (General)',
        'kit'        => 'Assays',
        'media'      => 'Media Preparation',
        'gas'        => 'Chemicals (General)',
        'consumable' => 'Consumables',
        _            => t,
      };
}
