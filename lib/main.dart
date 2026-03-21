// main.dart - App entry point: startup splash, DNS connectivity check,
// auth/session restore, route to login or menu. ErrorWidget override.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import 'core/local_storage.dart';
import 'supabase/supabase_manager.dart';
import 'theme/theme_controller.dart';
import 'database_connection/connections_page.dart';
import 'database_connection/add_connection_page.dart';
import 'menu/menu_page.dart';
import 'database_connection/database_check_page.dart';
import 'database_connection/setup_page.dart';
import 'login/set_admin_login_page.dart';
import 'login/login_page.dart';
import 'login/register_page.dart';

part 'startup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appThemeCtrl.init();

  // Show a user-friendly error screen instead of a black screen on
  // uncaught build exceptions (especially in release mode).
  ErrorWidget.builder = (details) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 16),
              const Text('Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                kDebugMode ? details.exceptionAsString() : 'Please restart the app.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeCtrl,
      builder: (context, _) => MaterialApp(
        themeMode: appThemeCtrl.mode,
        theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF38BDF8),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF0F172A),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Colors.white,
            contentTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 13),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF38BDF8),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0F172A),
            foregroundColor: Color(0xFFF1F5F9),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Colors.white,
            contentTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 13),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        title: 'BlueOpenLIMS',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
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
          '/register':        (context) => const RegisterPage(),
          '/menu':            (context) => const MenuPage(),
        },
      ),
    );
  }
}
