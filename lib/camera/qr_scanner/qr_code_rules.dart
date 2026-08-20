// qr_code_rules.dart - Canonical format for all LIMS Sphere QR codes.
//
// Format:  limsphere://<projectCode>/<category>/<uniqueId>
//
//   scheme      : "limsphere"  (always for newly generated codes)
//   projectCode : Supabase project ref (e.g. "jtckynsibyxhshvcnpcm") or "local"
//                 Used to reject codes from a different LIMS instance.
//   type        : one of the recognised entity types listed in [QrRules.validTypes]
//   id          : positive integer primary key of the record
//
// Examples:
//   limsphere://jtckynsibyxhshvcnpcm/reagents/42
//   limsphere://jtckynsibyxhshvcnpcm/machines/7
//   limsphere://jtckynsibyxhshvcnpcm/locations/15
//
// Generation — always use [QrRules.build]; never hand-craft the string.
// Validation — [QrRules.parse] returns null on any format violation.

class QrRules {
  QrRules._();

  static const String scheme = 'limsphere';
  static const String legacyScheme = 'bluelims';

  /// All entity types that can be encoded in a QR code.
  static const List<String> validTypes = [
    'reagents',
    'machines',
    'locations',
    'strains',
    'samples',
    'fish_lines',
    'fish_stocks',
    'sops',
    'users',
  ];

  // ── Generation ─────────────────────────────────────────────────────────────

  /// Build a QR payload string for [type] / [id] in [projectCode].
  ///
  /// Throws [ArgumentError] if [type] is not in [validTypes] or [id] < 1.
  static String build(String projectCode, String type, int id) {
    if (!validTypes.contains(type)) {
      throw ArgumentError.value(type, 'type', 'unknown QR category');
    }
    if (id < 1) {
      throw ArgumentError.value(id, 'id', 'must be a positive integer');
    }
    final normalizedProjectCode = projectCode.trim().toLowerCase();
    if (normalizedProjectCode.isEmpty) {
      throw ArgumentError.value(projectCode, 'projectCode', 'cannot be empty');
    }
    return '$scheme://$normalizedProjectCode/$type/$id';
  }

  // ── Parsing / validation ────────────────────────────────────────────────────

  /// Parse and validate a raw scanned string.
  ///
  /// Returns a [QrPayload] on success, or [null] if the string does not conform
  /// to the LIMS Sphere QR format (wrong scheme, unknown type, non-integer id).
  static QrPayload? parse(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme != scheme && uri.scheme != legacyScheme) return null;
    if (uri.host.isEmpty) return null;

    final segments = uri.pathSegments;
    if (segments.length != 2) return null;

    final type = segments[0];
    if (!validTypes.contains(type)) return null;

    final id = int.tryParse(segments[1]);
    if (id == null || id < 1) return null;

    return QrPayload(projectCode: uri.host, type: type, id: id);
  }

  /// Returns true if [raw] is a valid LIMS Sphere QR code string.
  static bool isValid(String raw) => parse(raw) != null;

  /// Whether [raw] already uses the current LIMSphere scheme.
  static bool isCanonical(String raw) {
    final uri = Uri.tryParse(raw);
    return uri?.scheme == scheme && parse(raw) != null;
  }

  static bool belongsToProject(QrPayload payload, String projectCode) =>
      payload.projectCode.toLowerCase() == projectCode.trim().toLowerCase();
}

// ── Payload ───────────────────────────────────────────────────────────────────

class QrPayload {
  final String projectCode;
  final String type;
  final int id;

  const QrPayload({
    required this.projectCode,
    required this.type,
    required this.id,
  });
}
