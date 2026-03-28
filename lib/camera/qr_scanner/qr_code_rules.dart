// qr_code_rules.dart - Canonical format for all BlueOpenLIMS QR codes.
//
// Format:  bluelims://<projectRef>/<type>/<id>
//
//   scheme      : "bluelims"  (always)
//   projectRef  : Supabase project ref (e.g. "jtckynsibyxhshvcnpcm") or "local"
//                 Used to reject codes from a different LIMS instance.
//   type        : one of the recognised entity types listed in [QrRules.validTypes]
//   id          : positive integer primary key of the record
//
// Examples:
//   bluelims://jtckynsibyxhshvcnpcm/reagents/42
//   bluelims://jtckynsibyxhshvcnpcm/machines/7
//   bluelims://jtckynsibyxhshvcnpcm/locations/15
//
// Generation — always use [QrRules.build]; never hand-craft the string.
// Validation — [QrRules.parse] returns null on any format violation.

class QrRules {
  QrRules._();

  static const String scheme = 'bluelims';

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

  /// Build a QR payload string for [type] / [id] in [projectRef].
  ///
  /// Throws [ArgumentError] if [type] is not in [validTypes] or [id] < 1.
  static String build(String projectRef, String type, int id) {
    assert(validTypes.contains(type),
        'QrRules.build: unknown type "$type". Add it to QrRules.validTypes.');
    assert(id > 0, 'QrRules.build: id must be a positive integer, got $id.');
    return '$scheme://$projectRef/$type/$id';
  }

  // ── Parsing / validation ────────────────────────────────────────────────────

  /// Parse and validate a raw scanned string.
  ///
  /// Returns a [QrPayload] on success, or [null] if the string does not conform
  /// to the BlueOpenLIMS QR format (wrong scheme, unknown type, non-integer id).
  static QrPayload? parse(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme != scheme) return null;

    final segments = uri.pathSegments;
    if (segments.length < 2) return null;

    final type = segments[0];
    if (!validTypes.contains(type)) return null;

    final id = int.tryParse(segments[1]);
    if (id == null || id < 1) return null;

    return QrPayload(projectRef: uri.host, type: type, id: id);
  }

  /// Returns true if [raw] is a valid BlueOpenLIMS QR code string.
  static bool isValid(String raw) => parse(raw) != null;
}

// ── Payload ───────────────────────────────────────────────────────────────────

class QrPayload {
  final String projectRef;
  final String type;
  final int id;

  const QrPayload({
    required this.projectRef,
    required this.type,
    required this.id,
  });
}
