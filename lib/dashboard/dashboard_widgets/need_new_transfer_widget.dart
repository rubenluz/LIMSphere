// need_new_transfer_widget.dart - Dashboard widget listing strains explicitly
// flagged as needing a new transfer (strain_need_new_transfer = true).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

class NeedNewTransferWidget extends StatefulWidget {
  const NeedNewTransferWidget({super.key});

  @override
  State<NeedNewTransferWidget> createState() => _NeedNewTransferWidgetState();
}

class _NeedNewTransferWidgetState extends State<NeedNewTransferWidget> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('strains')
          .select('strain_code, strain_medium, strain_last_transfer, strain_periodicity')
          .eq('strain_need_new_transfer', true)
          .order('strain_last_transfer', ascending: true);

      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('NeedNewTransferWidget ERROR: $e');
      debugPrint(st.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No strains flagged',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final r = _rows[index];
        final code     = r['strain_code']?.toString() ?? '—';
        final medium   = r['strain_medium']?.toString() ?? '—';
        final last     = r['strain_last_transfer']?.toString() ?? '—';
        final periodicity = r['strain_periodicity']?.toString() ?? '—';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.withAlpha(120)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    medium,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    last,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${periodicity}d',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
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
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 400 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.event_repeat_rounded, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Needs New Transfer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      if (!_loading)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_rows.length}',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: _load,
                ),
              ],
            ),
          ),
          if (_rows.isNotEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: const [
                  Expanded(flex: 2, child: Text('Strain',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey))),
                  Expanded(flex: 2, child: Text('Medium',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey))),
                  Expanded(flex: 2, child: Text('Last Transfer',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey))),
                  SizedBox(
                    width: 50,
                    child: Text('Cycle',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
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
