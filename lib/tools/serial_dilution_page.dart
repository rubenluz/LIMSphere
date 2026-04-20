// serial_dilution_page.dart - Serial dilution planner tool (stub).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';

class SerialDilutionPage extends StatelessWidget {
  const SerialDilutionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: AppDS.surface2,
        foregroundColor: AppDS.textPrimary,
        title: Row(children: [
          const Icon(Icons.opacity_outlined, size: 18, color: Color(0xFF38BDF8)),
          const SizedBox(width: 8),
          Text('Serial Dilution Planner', style: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppDS.textPrimary)),
        ]),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined,
              size: 56, color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Serial Dilution Planner',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: context.appTextPrimary)),
            const SizedBox(height: 6),
            Text('Coming soon.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13, color: context.appTextMuted)),
          ],
        ),
      ),
    );
  }
}
