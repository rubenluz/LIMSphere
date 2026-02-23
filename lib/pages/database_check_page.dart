import 'package:flutter/material.dart';
import '../core/database_initializer.dart';

class DatabaseCheckPage extends StatefulWidget {
  const DatabaseCheckPage({super.key});

  @override
  State<DatabaseCheckPage> createState() => _DatabaseCheckPageState();
}

class _DatabaseCheckPageState extends State<DatabaseCheckPage> {

  @override
  void initState() {
    super.initState();
    checkDatabase();
  }

  Future<void> checkDatabase() async {
    final initialized =
        await DatabaseInitializer.isDatabaseInitialized();

    if (!mounted) return;

    if (initialized) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      Navigator.pushReplacementNamed(context, '/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}