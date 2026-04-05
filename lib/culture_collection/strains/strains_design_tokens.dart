// strains_design_tokens.dart - StrainsDS: colour aliases for the strains
// module (delegates to AppDS for the unified dark palette).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io';


// Status options
const List<String> strainStatusOptions = ['ALIVE', 'INCARE', 'DEAD'];

// Preference keys
const String strainPrefSortKeys   = 'strains_sort_keys';
const String strainPrefSortDirs   = 'strains_sort_dirs';
const String strainPrefColWidths  = 'strains_col_widths';
const String strainPrefColOrder   = 'strains_col_order';
const String strainPrefHideEmpty  = 'strains_hide_empty';
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

