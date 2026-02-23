import 'package:flutter/material.dart';
import '../core/local_storage.dart';
import '../models/connection_model.dart';

class AddConnectionPage extends StatefulWidget {
  const AddConnectionPage({super.key});

  @override
  State<AddConnectionPage> createState() => _AddConnectionPageState();
}

class _AddConnectionPageState extends State<AddConnectionPage> {
  final nameController = TextEditingController();
  final urlController = TextEditingController();
  final anonKeyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Supabase Connection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Connection name',
              ),
            ),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Supabase URL',
              ),
            ),
            TextField(
              controller: anonKeyController,
              decoration: const InputDecoration(
                labelText: 'Anon Key',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final connection = ConnectionModel(
                  name: nameController.text,
                  url: urlController.text,
                  anonKey: anonKeyController.text,
                );

                await LocalStorage.addConnection(connection);

                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/connections');
                }
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }
}