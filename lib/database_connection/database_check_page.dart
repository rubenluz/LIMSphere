// database_check_page.dart - Connection validation with actionable diagnostics.

import 'package:flutter/material.dart';

import 'database_initializer.dart';

class DatabaseCheckPage extends StatefulWidget {
  const DatabaseCheckPage({super.key});

  @override
  State<DatabaseCheckPage> createState() => _DatabaseCheckPageState();
}

class _DatabaseCheckPageState extends State<DatabaseCheckPage> {
  DatabaseCheckResult? _result;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _result = null;
    });

    final result = await DatabaseInitializer.checkDatabase();
    if (!mounted) return;

    if (result.isReady) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (result.needsSetup) {
      Navigator.pushReplacementNamed(context, '/setup');
      return;
    }

    setState(() {
      _checking = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check Database Connection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to connections',
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/connections'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: result == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 18),
                      Text('Checking Supabase connection…'),
                    ],
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconFor(result.status),
                            size: 52,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            result.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(result.message, textAlign: TextAlign.center),
                          if (result.technicalDetails case final details?) ...[
                            const SizedBox(height: 16),
                            ExpansionTile(
                              title: const Text('Technical details'),
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(bottom: 8),
                              children: [
                                SelectableText(
                                  details,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/connections',
                                      ),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Connections'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _checking ? null : _checkDatabase,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try Again'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(DatabaseCheckStatus status) => switch (status) {
    DatabaseCheckStatus.noInternet => Icons.wifi_off_rounded,
    DatabaseCheckStatus.invalidCredentials => Icons.key_off_outlined,
    DatabaseCheckStatus.invalidSession => Icons.person_off_outlined,
    DatabaseCheckStatus.accessDenied => Icons.lock_outline,
    DatabaseCheckStatus.serviceUnavailable => Icons.cloud_off_outlined,
    DatabaseCheckStatus.invalidConfiguration => Icons.link_off_outlined,
    _ => Icons.error_outline,
  };
}
