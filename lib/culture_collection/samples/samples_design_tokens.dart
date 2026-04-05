// samples_design_tokens.dart - SamplesDS: colour aliases for the samples
// module (delegates to AppDS for the unified dark palette).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io';


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

bool _isDesktop(BuildContext context) => isSampleDesktop(context);
