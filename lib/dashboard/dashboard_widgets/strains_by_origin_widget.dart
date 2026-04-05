// strains_by_origin_widget.dart - Dashboard bar/pie chart aggregating active
// strain counts by geographic origin (country/island).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

/// Strains by Origin Widget - Shows distribution of strains by origin
class StrainsByOriginWidget extends StatefulWidget {
  const StrainsByOriginWidget({super.key});

  @override
  State<StrainsByOriginWidget> createState() => _StrainsByOriginWidgetState();
}

class _StrainsByOriginWidgetState extends State<StrainsByOriginWidget> {
  Map<String, int> _originCount = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOriginData();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<void> _loadOriginData() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('strains').select('strain_origin');

      final Map<String, int> counts = {};
      for (var row in data) {
        final origin = row['strain_origin'] as String?;
        if (origin != null && origin.isNotEmpty) {
          counts[origin] = (counts[origin] ?? 0) + 1;
        }
      }

      final sorted = Map.fromEntries(
          counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

      if (mounted) {
        setState(() {
          _originCount = sorted;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_originCount.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No origin data',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _originCount.length,
      itemBuilder: (context, index) {
        final entry = _originCount.entries.toList()[index];
        final total = _originCount.values.reduce((a, b) => a + b);
        final percentage = (entry.value / total * 100).toStringAsFixed(1);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: entry.value / total,
                  minHeight: 4,
                  backgroundColor: Colors.grey[200],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 400 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.pie_chart, size: 20, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Strains by Origin',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (desktop)
            Expanded(child: SingleChildScrollView(child: _buildList()))
          else
            _buildList(),
        ],
      ),
    );
  }
}