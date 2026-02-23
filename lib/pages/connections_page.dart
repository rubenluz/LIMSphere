import 'package:flutter/material.dart';
import '../core/local_storage.dart';
import '../models/connection_model.dart';
import '../core/supabase_manager.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  List<ConnectionModel> connections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await LocalStorage.loadConnections();
    setState(() => connections = list);
  }

  Future<void> _deleteConnection(int index) async {
    connections.removeAt(index);
    await LocalStorage.saveConnections(connections);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add connection',
            onPressed: () async {
              await Navigator.pushNamed(context, '/add_connection');
              _load();
            },
          ),
        ],
      ),
      body: connections.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storage_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No connections saved.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/add_connection');
                      _load();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Connection'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: connections.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final conn = connections[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text(conn.name),
                    subtitle: Text(conn.url, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteConnection(index),
                    ),
                    onTap: () async {
                      await SupabaseManager.initialize(conn);
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/db_check');
                    },
                  ),
                );
              },
            ),
      floatingActionButton: connections.isNotEmpty
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/add_connection');
                _load();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}