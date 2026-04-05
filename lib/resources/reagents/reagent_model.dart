// reagent_model.dart - ReagentModel: maps to the reagents Supabase table;
// expiry tracking, quantity, minimum-quantity threshold, fromMap serialisation.

class ReagentModel {
  final int id;
  final String? code;
  final String name;
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
  final String? notes;
  final String? qrcode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReagentModel({
    required this.id,
    required this.name,
    required this.type,
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
    this.notes,
    this.qrcode,
    this.createdAt,
    this.updatedAt,
  });

  factory ReagentModel.fromMap(Map<String, dynamic> m) => ReagentModel(
        id: (m['reagent_id'] as num).toInt(),
        code: m['reagent_code'] as String?,
        name: m['reagent_name'] as String,
        type: (m['reagent_type'] as String?) ?? 'chemical',
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
        notes: m['reagent_notes'] as String?,
        qrcode: m['reagent_qrcode'] as String?,
        createdAt: m['reagent_created_at'] != null
            ? DateTime.tryParse(m['reagent_created_at'].toString())
            : null,
        updatedAt: m['reagent_updated_at'] != null
            ? DateTime.tryParse(m['reagent_updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'reagent_name': name,
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
        if (notes != null) 'reagent_notes': notes,
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
    'chemical',
    'biological',
    'kit',
    'media',
    'gas',
    'consumable'
  ];
  static const tempOptions = ['RT', '4°C', '-20°C', '-80°C', 'liquid N2'];

  static String typeLabel(String t) => switch (t) {
        'chemical' => 'Chemical',
        'biological' => 'Biological',
        'kit' => 'Kit',
        'media' => 'Media',
        'gas' => 'Gas',
        'consumable' => 'Consumable',
        _ => t,
      };
}
