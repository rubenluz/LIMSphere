// theme.dart - AppDS design tokens (fixed dark-chrome colors, text helpers)
// and AppThemeContext extension (context.app* adaptive getters for content areas).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Centralized app design tokens ───────────────────────────────────────────
class AppDS {
  // ── Dark chrome (toolbars, sidebars, table headers) ─────────────────────────
  static const Color bg       = Color(0xFF0F172A);
  static const Color surface  = Color(0xFF1E293B);
  static const Color surface2 = Color(0xFF1A2438);
  static const Color surface3 = Color(0xFF243044);
  static const Color border   = Color(0xFF334155);
  static const Color border2  = Color(0xFF2D3F55);
  static const Color accent   = Color(0xFF38BDF8); // sky-400
  static const Color green    = Color(0xFF22C55E);
  static const Color yellow   = Color(0xFFEAB308);
  static const Color orange   = Color(0xFFF97316);
  static const Color red      = Color(0xFFEF4444);
  static const Color purple   = Color(0xFFA855F7);
  static const Color pink     = Color(0xFFEC4899);
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);

  // ── Extended palette ─────────────────────────────────────────────────────────
  static const Color sky     = Color(0xFF0EA5E9); // sky-500: sub-accent / accentDim
  static const Color blue    = Color(0xFF60A5FA); // blue-400: sort handles, drag indicators
  static const Color blue500 = Color(0xFF3B82F6); // blue-500: focus rings, inline links
  static const Color blue800 = Color(0xFF1E40AF); // blue-800: selected-column header bg
  static const Color indigo  = Color(0xFF6366F1); // indigo-500: menu section / user avatar

  // ── Semantic layout colors ────────────────────────────────────────────────────
  static const Color pageBg     = Color(0xFFF1F5F9); // light scaffold background (slate-100)
  static const Color fabBg      = Color(0xFF1E3A5F); // dark navy FAB / primary action button
  static const Color toolbarIcon = Color(0xB3FFFFFF); // white 70%: icon on dark toolbar/appbar
  static const Color shadow      = Color(0x28000000); // black ~16%: default box shadow

  // ── Light data-grid (white background rows) ──────────────────────────────────
  static const Color tableRowEven   = Color(0xFFFFFFFF);
  static const Color tableRowOdd    = Color(0xFFF8FAFC);
  static const Color tableRowSel    = Color(0xFFEFF6FF);
  static const Color tableRowUrgent = Color(0xFFFEE2E2); // overdue / blocked
  static const Color tableRowSoon   = Color(0xFFFEF9C3); // due within 7 days
  static const Color tableBorder    = Color(0xFFE2E8F0);
  static const Color tableText      = Color(0xFF1E293B);
  static const Color tableTextMute  = Color(0xFF64748B);
  static const Color tableHeaderText = Color(0xFFCBD5E1);

  // ── Table dimensions (shared by strains & samples grids) ─────────────────────
  static const double tableHeaderH = 46.0;
  static const double tableRowH    = 38.0;
  static const double tableCheckW  = 44.0;
  static const double tableOpenW   = 40.0;

  // ── TextStyles ───────────────────────────────────────────────────────────────
  static const TextStyle headerStyle = TextStyle(
    fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.07,
    color: textSecondary,
  );
  static const TextStyle tableHeaderStyle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, color: tableHeaderText, letterSpacing: 0.4,
  );
  static const TextStyle tableCellStyle = TextStyle(
    fontSize: 12, color: tableText,
  );
  static const TextStyle tableReadOnlyStyle = TextStyle(
    fontSize: 12, color: tableTextMute,
  );

  // ── Font helpers ─────────────────────────────────────────────────────────────
  static TextStyle mono({double size = 12, Color? color, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, color: color ?? textPrimary, fontWeight: weight);

  static TextStyle ui({double size = 13, Color? color, FontWeight? weight}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, color: color ?? textPrimary, fontWeight: weight);

  // ── Status color helper ──────────────────────────────────────────────────────
  static Color statusColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'active':        return green;
      case 'breeding':      return purple;
      case 'healthy':       return green;
      case 'observation':   return yellow;
      case 'treatment':     return orange;
      case 'sick':          return red;
      case 'archiving':
      case 'archived':      return textMuted;
      case 'lost':          return red;
      case 'cryopreserved': return accent;
      case 'quarantine':    return yellow;
      case 'retired':       return red;
      case 'empty':         return textMuted;
      case 'transgenic':    return accent;
      case 'mutant':        return orange;
      case 'crispr':        return purple;
      case 'ko':            return red;
      case 'ki':            return yellow;
      case 'wt':            return green;
      default:              return textSecondary;
    }
  }
}

// --- Adaptive colour getters -------------------------------------------------
// Use these instead of raw AppDS constants wherever a background/surface/
// text colour needs to flip between light and dark mode.
extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Page / toolbar backgrounds
  Color get appBg       => isDark ? AppDS.bg      : Colors.white;
  Color get appSurface  => isDark ? AppDS.surface  : const Color(0xFFF1F5F9);
  Color get appSurface2 => isDark ? AppDS.surface2 : const Color(0xFFE8EEF4);
  Color get appSurface3 => isDark ? AppDS.surface3 : const Color(0xFFDDE3ED);

  // Borders
  Color get appBorder  => isDark ? AppDS.border  : const Color(0xFFE2E8F0);
  Color get appBorder2 => isDark ? AppDS.border2 : const Color(0xFFCBD5E1);

  // Text on toolbars / page backgrounds
  Color get appTextPrimary   => isDark ? AppDS.textPrimary   : const Color(0xFF0F172A);
  Color get appTextSecondary => isDark ? AppDS.textSecondary : const Color(0xFF475569);
  Color get appTextMuted     => isDark ? AppDS.textMuted     : const Color(0xFF94A3B8);

  // Table column-header row
  Color get appHeaderBg   => isDark ? AppDS.surface        : const Color(0xFFF8FAFC);
  Color get appHeaderText => isDark ? AppDS.textSecondary  : const Color(0xFF475569);
}