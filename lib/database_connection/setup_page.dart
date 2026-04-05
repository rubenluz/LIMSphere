// setup_page.dart - Database initialisation wizard: runs DDL from
// core_tables_sql.dart to create all tables on a fresh Supabase project.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../supabase/core_tables_sql.dart';
import '../supabase/supabase_manager.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  bool isLoading = false;

  Future<void> _copySQL() async {
    await Clipboard.setData(ClipboardData(text: coreTablesSQL));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SQL copied to clipboard')),
    );
  }

  Future<void> _checkDatabase() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final ready = await SupabaseManager.checkInitialized();
      if (!mounted) return;

      if (ready) {
        final adminExists = await SupabaseManager.adminExists();
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          adminExists ? '/login' : '/set_admin_login',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tables not found yet. Run the SQL in Supabase SQL Editor, then try again.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Database'),
        // ── Back to connections ──────────────────────────────
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to connections',
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/connections'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Info card ──────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('Database not initialized',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                      'Copy the SQL below and run it in your Supabase SQL Editor, '
                      'then press "Check Again".',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── SQL viewer ─────────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: SelectableText(
                    coreTablesSQL,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Action buttons ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copySQL,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy SQL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : _checkDatabase,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Check Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}