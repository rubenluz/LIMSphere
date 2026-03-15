import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import 'core/local_storage.dart';
import 'core/supabase_manager.dart';
import 'pages/database_connection/connections_page.dart';
import 'pages/database_connection/add_connection_page.dart';
import 'pages/menu/menu_page.dart';
import 'pages/database_connection/database_check_page.dart';
import 'pages/database_connection/setup_page.dart';
import 'pages/login/set_admin_login_page.dart';
import 'pages/login/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueOpenLIMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return SafeArea(
          top: true,
          bottom: true,
          left: false,
          right: false,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const StartupPage(),
      routes: {
        '/connections':     (context) => const ConnectionsPage(),
        '/add_connection':  (context) => const AddConnectionPage(),
        '/login':           (context) => const LoginPage(),
        '/db_check':        (context) => const DatabaseCheckPage(),
        '/setup':           (context) => const SetupPage(),
        '/set_admin_login': (context) => const SetAdminLoginPage(),
        '/menu':       (context) => const MenuPage(),
      },
    );
  }
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    _startupLogic();
  }

  Future<void> _startupLogic() async {
    await Future.delayed(const Duration(milliseconds: 600));

    // 1. Try to restore the last connection silently
    final restored = await SupabaseManager.restoreLastConnection();

    if (restored) {
      // 2. Check if the saved session is still within the user's chosen duration
      final sessionValid = await LocalStorage.hasValidSession();

      if (sessionValid && SupabaseManager.hasActiveSession) {
        // Update last login for the restored session (non-critical)
        try {
          final email =
              Supabase.instance.client.auth.currentSession?.user.email;
          if (email != null) {
            await Supabase.instance.client
                .from('users')
                .update({'user_last_login': DateTime.now().toIso8601String()})
                .eq('user_email', email);
          }
        } catch (_) {}

        // Skip login entirely → go straight to dashboard
        if (mounted) Navigator.pushReplacementNamed(context, '/menu');
        return;
      }
      // Session expired or Supabase token gone → go to login (connection already restored)
      if (mounted) Navigator.pushReplacementNamed(context, '/connections');
      return;
    }

    // 3. No saved connection → normal first-run flow
    if (!mounted) return;
    final connections = await LocalStorage.loadConnections();
    if (connections.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/connections');
    } else {
      Navigator.pushReplacementNamed(context, '/add_connection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.biotech, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'BlueOpenLIMS',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}