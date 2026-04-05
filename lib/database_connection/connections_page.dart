// connections_page.dart - Saved Supabase connection list: select active
// connection, edit URL/key, delete, navigate to add-connection page.

import 'package:flutter/material.dart';
import '../core/local_storage.dart';
import 'database_connection_model.dart';
import '../supabase/supabase_manager.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  List<ConnectionModel> connections = [];
  int? selectedIndex;
  final Map<int, bool> healthStatus = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await LocalStorage.loadConnections();
    setState(() => connections = list);
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    for (int i = 0; i < connections.length; i++) {
      final ok = await SupabaseManager.testConnection(connections[i]);
      healthStatus[i] = ok;
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteConnection(int index) async {
    final conn = connections[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete connection?'),
        content: Text('Remove "${conn.name}" from your saved connections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    connections.removeAt(index);
    await LocalStorage.saveConnections(connections);
    setState(() {});
  }

  Future<void> _editConnection(int index) async {
    await Navigator.pushNamed(
      context,
      '/add_connection',
      arguments: connections[index],
    );
    _load();
  }

  Future<void> _connect(ConnectionModel conn, int index) async {
    setState(() => selectedIndex = index);
    await SupabaseManager.initialize(conn);
    conn.lastConnected = DateTime.now();
    await LocalStorage.saveConnections(connections);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/db_check');
  }

  String _lastConnectedText(ConnectionModel conn) {
    if (conn.lastConnected == null) return 'Never connected';
    final diff = DateTime.now().difference(conn.lastConnected!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Database')
      ),
      floatingActionButton: connections.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.pushNamed(context, '/add_connection');
                _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: connections.isEmpty
            ? _emptyState()
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: connections.length,
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  final conn = connections[index];
                  final selected = selectedIndex == index;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? scheme.primary : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(
                            color: scheme.primary.withOpacity(.25),
                            blurRadius: 12,
                          ),
                      ],
                    ),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _connect(conn, index),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Top row: icon + health dot + menu ──
                              Row(
                                children: [
                                  Icon(Icons.storage, color: scheme.primary),
                                  const Spacer(),
                                  // Health dot
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: healthStatus[index] == null
                                          ? Colors.orange
                                          : healthStatus[index]!
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // ── Options menu ──────────────────
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      iconSize: 18,
                                      icon: Icon(Icons.more_vert,
                                          color: scheme.outline, size: 18),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      onSelected: (v) {
                                        if (v == 'edit') _editConnection(index);
                                        if (v == 'delete') _deleteConnection(index);
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [
                                            Icon(Icons.edit_outlined,
                                                size: 16,
                                                color: scheme.onSurface),
                                            const SizedBox(width: 10),
                                            const Text('Edit'),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete_outline,
                                                size: 16,
                                                color: scheme.error),
                                            const SizedBox(width: 10),
                                            Text('Delete',
                                                style: TextStyle(
                                                    color: scheme.error)),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const Spacer(),

                              // ── Name ──────────────────────────────
                              Text(
                                conn.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),

                              // ── URL ───────────────────────────────
                              Text(
                                conn.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),

                              // ── Bottom row: last connected + check ─
                              Row(
                                children: [
                                  Text(
                                    _lastConnectedText(conn),
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                  const Spacer(),
                                  AnimatedScale(
                                    scale: selected ? 1 : 0,
                                    duration:
                                        const Duration(milliseconds: 250),
                                    child: Icon(Icons.check_circle,
                                        color: scheme.primary, size: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage_rounded, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No connections saved'),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Connection'),
            onPressed: () async {
              await Navigator.pushNamed(context, '/add_connection');
              _load();
            },
          ),
        ],
      ),
    );
  }
}