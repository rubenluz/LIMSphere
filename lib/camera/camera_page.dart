// camera_page.dart - Mobile-only entry point for QR scanning and camera features.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';
import '/menu/app_nav.dart';
import 'qr_scanner/qr_scanner_page.dart';

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────────
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: context.appSurface2,
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: context.appTextSecondary,
              tooltip: 'Menu',
              onPressed: openAppDrawer,
            ),
            const Icon(Icons.camera_alt_outlined, size: 18, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            Text('Camera', style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: context.appTextPrimary)),
          ]),
        ),
        // ── Content ──────────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Camera Features', style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: context.appTextMuted)),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.qr_code_scanner_rounded,
                  color: const Color(0xFF38BDF8),
                  title: 'Scan QR Code',
                  subtitle: 'Open a record by scanning its QR label',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrScannerPage()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: context.appTextPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: context.appTextMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appTextMuted, size: 20),
          ]),
        ),
      ),
    );
  }
}
