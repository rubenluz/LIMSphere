// tools_page.dart - Hub page for lab utility tools. Each tile opens its own page.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';
import '/menu/app_nav.dart';
import 'well_randomizer_page.dart';
import 'serial_dilution_page.dart';
import 'concentration_calculator_page.dart';
import 'unit_converter_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final tools = <_Tool>[
      _Tool(
        icon: Icons.grid_on_outlined,
        color: const Color(0xFFA855F7),
        title: '96 Well Randomizer',
        subtitle: 'Randomize sample layout on a 96-well plate',
        builder: () => const WellRandomizerPage(),
      ),
      _Tool(
        icon: Icons.opacity_outlined,
        color: const Color(0xFF38BDF8),
        title: 'Serial Dilution Planner',
        subtitle: 'Plan stepwise dilution series and volumes',
        builder: () => const SerialDilutionPage(),
      ),
      _Tool(
        icon: Icons.calculate_outlined,
        color: const Color(0xFF22C55E),
        title: 'Concentration Calculator',
        subtitle: 'Compute C₁V₁ = C₂V₂, molarity and mass',
        builder: () => const ConcentrationCalculatorPage(),
      ),
      _Tool(
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFFF97316),
        title: 'Units Converter',
        subtitle: 'Convert between mass, volume and concentration units',
        builder: () => const UnitConverterPage(),
      ),
    ];

    return Column(
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: context.appSurface2,
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.menu_rounded, size: 20),
                color: context.appTextSecondary,
                tooltip: 'Menu',
                onPressed: openAppDrawer,
              ),
            const Icon(Icons.handyman_outlined, size: 18, color: Color(0xFFA855F7)),
            const SizedBox(width: 8),
            Text('Tools', style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: context.appTextPrimary)),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, cons) {
            final narrow = cons.maxWidth < 560;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lab Tools', style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: context.appTextMuted)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: narrow
                        ? ListView.separated(
                            itemCount: tools.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ToolListTile(tool: tools[i]),
                          )
                        : _buildGrid(cons, tools),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildGrid(BoxConstraints cons, List<_Tool> tools) {
    // Windows always uses 2x2. Other desktops go 1x4 when very wide.
    const gap = 12.0;
    final wide = !Platform.isWindows && cons.maxWidth >= 1100;
    final cols = wide ? 4 : 2;
    final rows = wide ? 1 : 2;
    return Column(
      children: List.generate(rows, (r) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : gap),
            child: Row(
              children: List.generate(cols, (c) {
                final idx = r * cols + c;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: c == cols - 1 ? 0 : gap),
                    child: _ToolCard(tool: tools[idx]),
                  ),
                );
              }),
            ),
          ),
        );
      }),
    );
  }
}

class _Tool {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget Function() builder;
  const _Tool({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

class _ToolCard extends StatelessWidget {
  final _Tool tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => tool.builder())),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: tool.color, size: 26),
              ),
              const SizedBox(height: 16),
              Text(tool.title, style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: context.appTextPrimary)),
              const SizedBox(height: 6),
              Expanded(
                child: Text(tool.subtitle,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, color: context.appTextMuted, height: 1.4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolListTile extends StatelessWidget {
  final _Tool tool;
  const _ToolListTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => tool.builder())),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tool.icon, color: tool.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tool.title, style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: context.appTextPrimary)),
                  const SizedBox(height: 2),
                  Text(tool.subtitle,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: context.appTextMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
              color: context.appTextMuted, size: 20),
          ]),
        ),
      ),
    );
  }
}
