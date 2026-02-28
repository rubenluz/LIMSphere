import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens for Strains page
// ─────────────────────────────────────────────────────────────────────────────
class StrainsDS {
  static const double headerH = 46.0;
  static const double rowH    = 38.0;
  static const double checkW  = 44.0;
  static const double openW   = 40.0;

  static const Color headerBg     = Color(0xFF1E293B);
  static const Color headerText   = Color(0xFFCBD5E1);
  static const Color headerBorder = Color(0xFF334155);

  static const Color rowEven    = Color(0xFFFFFFFF);
  static const Color rowOdd     = Color(0xFFF8FAFC);
  static const Color selectedBg = Color(0xFFDBEAFE);

  static const Color overdueRowBg = Color(0xFFFFF1F2);
  static const Color soonRowBg    = Color(0xFFFFFBEB);

  static const Color cellBorder  = Color(0xFFE2E8F0);
  static const Color blockedBg   = Color(0xFFFFF1F2);
  static const Color blockedText = Color(0xFFEF4444);

  static const Color aliveColor  = Color(0xFF16A34A);
  static const Color deadColor   = Color(0xFFDC2626);
  static const Color incareColor = Color(0xFFD97706);

  static const TextStyle headerStyle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, color: headerText, letterSpacing: 0.4,
  );
  static const TextStyle cellStyle = TextStyle(fontSize: 12, color: Color(0xFF334155));
  static const TextStyle readOnlyStyle = TextStyle(fontSize: 12, color: Color(0xFFAEB8C2));
}

// Status options
const List<String> strainStatusOptions = ['ALIVE', 'INCARE', 'DEAD'];

// Preference keys
const String strainPrefSortKeys  = 'strains_sort_keys';
const String strainPrefSortDirs  = 'strains_sort_dirs';
const String strainPrefColWidths = 'strains_col_widths';
const String strainPrefColOrder  = 'strains_col_order';
const double strainMinColWidth   = 40.0;

// ─────────────────────────────────────────────────────────────────────────────
// Urgency enum and calculation
// ─────────────────────────────────────────────────────────────────────────────
enum StrainTransferUrgency { overdue, soon, ok, unknown }

StrainTransferUrgency calculateStrainUrgency(Map<String, dynamic> row) {
  final v = row['strain_next_transfer']?.toString();
  if (v == null || v.isEmpty) return StrainTransferUrgency.unknown;
  try {
    final d = DateTime.parse(v).difference(DateTime.now()).inDays;
    if (d < 0) return StrainTransferUrgency.overdue;
    if (d <= 7) return StrainTransferUrgency.soon;
    return StrainTransferUrgency.ok;
  } catch (_) {
    return StrainTransferUrgency.unknown;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active filter helper
// ─────────────────────────────────────────────────────────────────────────────
class ActiveFilter {
  final String column;
  final String label;
  String value;
  ActiveFilter(this.column, this.label, this.value);
}

// ──────────────────────────────────────────────────────────────────────────────
// Platform detection
// ─────────────────────────────────────────────────────────────────────────────
bool isDesktopPlatform(BuildContext context) {
  if (kIsWeb) return true;
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
  } catch (_) {}
  return MediaQuery.of(context).size.width >= 720;
}

// Alias for backwards compatibility
class _DS extends StrainsDS {}
enum _TU { overdue, soon, ok, unknown }
class _ActiveFilter extends ActiveFilter {
  _ActiveFilter(String column, String label, String value) : super(column, label, value);
}

_TU _urgency(Map<String, dynamic> row) {
  final urgency = calculateStrainUrgency(row);
  switch (urgency) {
    case StrainTransferUrgency.overdue:
      return _TU.overdue;
    case StrainTransferUrgency.soon:
      return _TU.soon;
    case StrainTransferUrgency.ok:
      return _TU.ok;
    case StrainTransferUrgency.unknown:
      return _TU.unknown;
  }
}
bool _isDesktopPlatform(BuildContext context) => isDesktopPlatform(context);
