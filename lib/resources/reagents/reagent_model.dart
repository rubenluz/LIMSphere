// reagent_model.dart - ReagentModel: maps to the reagents Supabase table.
// Stock model: package_size × container_count (+ remaining amount in the
// currently opened container). Low-stock threshold applies to container_count.

class ReagentModel {
  final int id;
  final String? code;
  final String stockStatus;
  final String? name;
  final String? brand;
  final String? reference;
  final String? casNumber;
  final String? synonyms;
  final String category;
  final String? subcategory;
  final String? unit;
  final double? packageSize;
  final int? containerCount;
  final int? containerMin;
  final double? remainingAmount;
  final String? concentration;
  final String? storageTemp;
  final int? locationId;
  final String? locationName;
  final String? position;
  final String? lotNumber;
  final double? priceEur;
  final DateTime? expiryDate;
  final DateTime? receivedDate;
  final DateTime? openedDate;
  final String? supplier;
  final String? hazard;
  final String? responsible;
  final String? formula;
  final String? notes;
  final String? physicalState;
  final String contamination;
  final String? contaminationNotes;
  final DateTime? contaminationDate;
  final String? tags;
  final String? qrcode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReagentModel({
    required this.id,
    required this.category,
    this.stockStatus = 'in_stock',
    this.subcategory,
    this.name,
    this.code,
    this.brand,
    this.reference,
    this.casNumber,
    this.synonyms,
    this.unit,
    this.packageSize,
    this.containerCount,
    this.containerMin,
    this.remainingAmount,
    this.concentration,
    this.storageTemp,
    this.locationId,
    this.locationName,
    this.position,
    this.lotNumber,
    this.priceEur,
    this.expiryDate,
    this.receivedDate,
    this.openedDate,
    this.supplier,
    this.hazard,
    this.responsible,
    this.formula,
    this.notes,
    this.physicalState,
    this.contamination = 'none',
    this.contaminationNotes,
    this.contaminationDate,
    this.tags,
    this.qrcode,
    this.createdAt,
    this.updatedAt,
  });

  factory ReagentModel.fromMap(Map<String, dynamic> m) => ReagentModel(
    id: (m['reagent_id'] as num).toInt(),
    code: m['reagent_code'] as String?,
    stockStatus: normalizeStockStatus(m['reagent_stock_status'] as String?),
    name: m['reagent_name'] as String?,
    category: (m['reagent_category'] as String?) ?? 'chemical',
    subcategory: m['reagent_subcategory'] as String?,
    brand: m['reagent_brand'] as String?,
    reference: m['reagent_reference'] as String?,
    casNumber: m['reagent_cas_number'] as String?,
    synonyms: m['reagent_synonyms'] as String?,
    unit: m['reagent_unit'] as String?,
    packageSize: m['reagent_package_size'] != null
        ? (m['reagent_package_size'] as num).toDouble()
        : null,
    containerCount: m['reagent_container_count'] != null
        ? (m['reagent_container_count'] as num).toInt()
        : null,
    containerMin: m['reagent_container_min'] != null
        ? (m['reagent_container_min'] as num).toInt()
        : null,
    remainingAmount: m['reagent_remaining_amount'] != null
        ? (m['reagent_remaining_amount'] as num).toDouble()
        : null,
    concentration: m['reagent_concentration'] as String?,
    storageTemp: m['reagent_storage_temp'] as String?,
    locationId: m['reagent_location_id'] != null
        ? (m['reagent_location_id'] as num).toInt()
        : null,
    locationName: m['location_name'] as String?,
    position: m['reagent_position'] as String?,
    lotNumber: m['reagent_lot_number'] as String?,
    priceEur: m['reagent_price_eur'] != null
        ? (m['reagent_price_eur'] as num).toDouble()
        : null,
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
    contamination: (m['reagent_contamination'] as String?) ?? 'none',
    contaminationNotes: m['reagent_contamination_notes'] as String?,
    contaminationDate: m['reagent_contamination_date'] != null
        ? DateTime.tryParse(m['reagent_contamination_date'].toString())
        : null,
    tags: m['reagent_tags'] as String?,
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
    'reagent_category': category,
    if (subcategory != null) 'reagent_subcategory': subcategory,
    if (code != null) 'reagent_code': code,
    'reagent_stock_status': stockStatus,
    if (brand != null) 'reagent_brand': brand,
    if (reference != null) 'reagent_reference': reference,
    if (casNumber != null) 'reagent_cas_number': casNumber,
    if (synonyms != null) 'reagent_synonyms': synonyms,
    if (unit != null) 'reagent_unit': unit,
    if (packageSize != null) 'reagent_package_size': packageSize,
    if (containerCount != null) 'reagent_container_count': containerCount,
    if (containerMin != null) 'reagent_container_min': containerMin,
    if (remainingAmount != null) 'reagent_remaining_amount': remainingAmount,
    if (concentration != null) 'reagent_concentration': concentration,
    if (storageTemp != null) 'reagent_storage_temp': storageTemp,
    if (locationId != null) 'reagent_location_id': locationId,
    if (position != null) 'reagent_position': position,
    if (lotNumber != null) 'reagent_lot_number': lotNumber,
    if (priceEur != null) 'reagent_price_eur': priceEur,
    if (expiryDate != null)
      'reagent_expiry_date': expiryDate!.toIso8601String().substring(0, 10),
    if (receivedDate != null)
      'reagent_received_date': receivedDate!.toIso8601String().substring(0, 10),
    if (openedDate != null)
      'reagent_opened_date': openedDate!.toIso8601String().substring(0, 10),
    if (supplier != null) 'reagent_supplier': supplier,
    if (hazard != null) 'reagent_hazard': hazard,
    if (responsible != null) 'reagent_responsible': responsible,
    if (formula != null) 'reagent_formula': formula,
    if (notes != null) 'reagent_notes': notes,
    if (physicalState != null) 'reagent_physical_state': physicalState,
    'reagent_contamination': contamination,
    if (contaminationNotes != null)
      'reagent_contamination_notes': contaminationNotes,
    if (contaminationDate != null)
      'reagent_contamination_date': contaminationDate!
          .toIso8601String()
          .substring(0, 10),
    if (tags != null) 'reagent_tags': tags,
  };

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 30;
  bool get isOutOfStock => stockStatus == 'out_of_stock';
  bool get isLowStock =>
      containerCount != null &&
      containerMin != null &&
      containerCount! <= containerMin!;
  bool get isContaminated => contamination != 'none';

  double? get totalStock {
    if (packageSize == null || containerCount == null) return null;
    if (containerCount! <= 0) return 0;
    final base = (containerCount! - 1) * packageSize!;
    return base + (remainingAmount ?? packageSize!);
  }

  static String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  String get displayPackageSize {
    if (packageSize == null) return '—';
    return unit != null ? '${_fmt(packageSize!)} $unit' : _fmt(packageSize!);
  }

  String get displayRemaining {
    if (remainingAmount == null) return '—';
    return unit != null
        ? '${_fmt(remainingAmount!)} $unit'
        : _fmt(remainingAmount!);
  }

  String get displayTotalStock {
    final t = totalStock;
    if (t == null) return '—';
    return unit != null ? '${_fmt(t)} $unit' : _fmt(t);
  }

  static const categoryOptions = [
    'chemical',
    'biological',
    'consumable',
    'kit',
  ];

  // Same options sorted by display label — for UI selectors.
  static List<String> get categoryOptionsSorted {
    final list = [...categoryOptions];
    list.sort(
      (a, b) => categoryLabel(
        a,
      ).toLowerCase().compareTo(categoryLabel(b).toLowerCase()),
    );
    return list;
  }

  static List<String> subcategoryOptionsSorted(String category) {
    final list = [...?subcategoryOptions[category]];
    list.sort(
      (a, b) => subcategoryLabel(
        a,
      ).toLowerCase().compareTo(subcategoryLabel(b).toLowerCase()),
    );
    return list;
  }

  // Fixed, enumerated sub-categories per category. Sub-category values are
  // persisted as-is; use [subcategoryLabel] for display.
  static const subcategoryOptions = <String, List<String>>{
    'chemical': [
      'reagents',
      'solvent',
      'buffer',
      'stain',
      'extraction',
      'cleaning',
      'media_preparation',
      'standards_controls',
      'assays',
      'other',
    ],
    'biological': ['media', 'cell_culture', 'enzyme', 'nucleic_acid', 'other'],
    'consumable': [
      'pipette_tip',
      'tube',
      'plate',
      'flask',
      'filter',
      'ppe',
      'glassware',
      'other',
    ],
    'kit': ['extraction_kit', 'assay_kit', 'other'],
  };

  static const contaminationOptions = [
    'none',
    'bacteria',
    'fungi',
    'both',
    'suspected',
  ];

  static const stockStatusOptions = ['in_stock', 'out_of_stock'];

  static const tempOptions = ['RT', '4°C', '-20°C', '-80°C', 'liquid N2'];

  static String normalizeStockStatus(String? raw) {
    final value = raw
        ?.trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return value == 'out_of_stock' ? 'out_of_stock' : 'in_stock';
  }

  static const physicalStateOptions = ['liquid', 'solid', 'gas'];

  static String physicalStateLabel(String s) => switch (s) {
    'liquid' => 'Liquid',
    'solid' => 'Solid',
    'gas' => 'Gas',
    _ => s,
  };

  static String categoryLabel(String c) => switch (c) {
    'chemical' => 'Chemicals',
    'biological' => 'Biological',
    'consumable' => 'Consumables',
    'kit' => 'Kits',
    _ => c,
  };

  static String subcategoryLabel(String s) => switch (s) {
    'reagents' => 'Reagents',
    'solvent' => 'Solvents',
    'buffer' => 'Buffers & Solutions',
    'stain' => 'Stains & Dyes',
    'extraction' => 'Extraction Reagents',
    'cleaning' => 'Cleaning & maintenance',
    'media_preparation' => 'Media preparation',
    'media' => 'Media',
    'cell_culture' => 'Cell Culture Supplements',
    'enzyme' => 'Enzymes',
    'nucleic_acid' => 'Nucleic Acids',
    'pipette_tip' => 'Pipette Tips',
    'tube' => 'Tubes',
    'plate' => 'Plates',
    'flask' => 'Flasks',
    'filter' => 'Filters',
    'ppe' => 'PPE',
    'glassware' => 'Glassware',
    'extraction_kit' => 'Extraction Kits',
    'assay_kit' => 'Assay Kits',
    'analytical' => 'Analytical Standards',
    'control' => 'Controls',
    'standards_controls' => 'Standards and controls',
    'assays' => 'Assays',
    'other' => 'Others',
    _ =>
      s
          .replaceAll('_', ' ')
          .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m[0]!.toUpperCase()),
  };

  // Tags helpers — tags are persisted as a semicolon-separated string.
  static List<String> parseTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(';')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String? joinTags(Iterable<String> tags) {
    final cleaned = tags.map((t) => t.trim()).where((t) => t.isNotEmpty);
    return cleaned.isEmpty ? null : cleaned.join('; ');
  }

  List<String> get tagList => parseTags(tags);

  static String contaminationLabel(String c) => switch (c) {
    'none' => 'Clean',
    'bacteria' => 'Bacteria',
    'fungi' => 'Fungi',
    'both' => 'Bacteria + Fungi',
    'suspected' => 'Suspected',
    _ => c,
  };

  static String stockStatusLabel(String s) => switch (normalizeStockStatus(s)) {
    'out_of_stock' => 'Out of stock',
    _ => 'In stock',
  };
}
