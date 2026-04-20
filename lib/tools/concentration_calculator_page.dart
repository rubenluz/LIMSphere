// concentration_calculator_page.dart - Concentration calculation tool (stub).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';

class ConcentrationCalculatorPage extends StatelessWidget {
  const ConcentrationCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: AppDS.surface2,
        foregroundColor: AppDS.textPrimary,
        title: Row(children: [
          const Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF22C55E)),
          const SizedBox(width: 8),
          Text('Concentration Calculator', style: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppDS.textPrimary)),
        ]),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined,
              size: 56, color: const Color(0xFF22C55E).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Concentration Calculator',
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
