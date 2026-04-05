// strains_by_medium_widget.dart - Dashboard chart aggregating active strain
// counts by growth medium type.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

/// Strains by Medium Widget - Shows distribution of strains by culture medium
class StrainsByMediumWidget extends StatefulWidget {
  const StrainsByMediumWidget({super.key});

  @override
  State<StrainsByMediumWidget> createState() => _StrainsByMediumWidgetState();
}

class _StrainsByMediumWidgetState extends State<StrainsByMediumWidget> {
  Map<String, int> _mediumCount = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMediumData();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<void> _loadMediumData() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('strains').select('strain_medium');

      final Map<String, int> counts = {};
      for (var row in data) {
        final medium = row['strain_medium'] as String?;
        if (medium != null && medium.isNotEmpty) {
          counts[medium] = (counts[medium] ?? 0) + 1;
        }
      }

      final sorted = Map.fromEntries(
          counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

      if (mounted) {
        setState(() {
          _mediumCount = sorted;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_mediumCount.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No medium data',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _mediumCount.entries.map((entry) {
          final total = _mediumCount.values.reduce((a, b) => a + b);
          final percentage = (entry.value / total * 100).toStringAsFixed(0);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.cyan.withAlpha(80),
              border: Border.all(color: Colors.cyan.withAlpha(150), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.key.length > 10
                      ? '${entry.key.substring(0, 10)}...'
                      : entry.key,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.value}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.cyan, width: 2),
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
                const Icon(Icons.water_drop, size: 20, color: Colors.cyan),
                const SizedBox(width: 8),
                const Text(
                  'Strains by Medium',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (desktop)
            Expanded(child: SingleChildScrollView(child: _buildContent()))
          else
            _buildContent(),
        ],
      ),
    );
  }
}