import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens for Samples page
// ─────────────────────────────────────────────────────────────────────────────
class SamplesDS {
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
  static const Color cellBorder = Color(0xFFE2E8F0);

  static const TextStyle headerStyle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, color: headerText, letterSpacing: 0.4,
  );
  static const TextStyle cellStyle = TextStyle(fontSize: 12, color: Color(0xFF334155));
  static const TextStyle readOnlyStyle = TextStyle(fontSize: 12, color: Color(0xFFAEB8C2));
}

// Preference keys
const String samplePrefSortKeys  = 'samples_sort_keys';
const String samplePrefSortDirs  = 'samples_sort_dirs';
const String samplePrefColWidths = 'samples_col_widths';
const String samplePrefColOrder  = 'samples_col_order';
const double sampleMinColWidth   = 40.0;

// ──────────────────────────────────────────────────────────────────────────────
// Platform detection
// ─────────────────────────────────────────────────────────────────────────────
bool isSampleDesktop(BuildContext context) {
  if (kIsWeb) return true;
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
  } catch (_) {}
  return MediaQuery.of(context).size.width >= 720;
}

// Aliases for backwards compatibility
class _DS extends SamplesDS {}
bool _isDesktop(BuildContext context) => isSampleDesktop(context);
