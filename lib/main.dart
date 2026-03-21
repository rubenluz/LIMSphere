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

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 24, end: 0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _startupLogic();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  /// Returns true if a real internet connection is available.
  static Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('connectivitycheck.gstatic.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startupLogic() async {
    // Run connectivity check and minimum splash delay concurrently.
    final results = await Future.wait([
      checkConnectivity(),
      Future.delayed(const Duration(milliseconds: 800)).then((_) => true),
    ]);
    final isOnline = results[0];

    if (!isOnline && mounted) setState(() => _offline = true);

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
      // Session expired — if offline let the user read the warning before moving on
      if (!isOnline && mounted) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      if (mounted) Navigator.pushReplacementNamed(context, '/connections');
      return;
    }

    // 3. No saved connection — if offline, pause so warning is visible
    if (!isOnline && mounted) {
      await Future.delayed(const Duration(milliseconds: 1500));
    }
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
    const bg      = Color(0xFF0F172A);
    const accent  = Color(0xFF38BDF8);
    const surface = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Subtle radial glow behind logo
          Positioned.fill(
            child: Center(
              child: Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                    radius: 0.8,
                  ),
                ),
              ),
            ),
          ),
          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: AnimatedBuilder(
                animation: _slideUp,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: child,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.25), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.15),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/icon/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.biotech_outlined,
                              size: 48,
                              color: accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // App name
                    Text(
                      'BlueOpenLIMS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF1F5F9),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Subtitle
                    Text(
                      'Laboratory Information Management',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Offline warning badge
                    if (_offline) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded,
                                size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 6),
                            Text('No internet connection',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  color: const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Animated dots loader
                    _DotsLoader(color: accent),
                  ],
                ),
              ),
            ),
          ),
          // Version tag at bottom
          Positioned(
            bottom: 24, left: 0, right: 0,
            child: FadeTransition(
              opacity: _fadeIn,
              child: Text(
                'Open Source · MIT License',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Three pulsing dots loading indicator
class _DotsLoader extends StatefulWidget {
  final Color color;
  const _DotsLoader({required this.color});
  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot peaks at a different phase of the animation cycle
            final phase  = (i / 3.0);
            final t      = ((_ctrl.value - phase + 1.0) % 1.0);
            final scale  = 0.5 + 0.5 * (1 - (2 * t - 1).abs().clamp(0.0, 1.0));
            final opacity = 0.3 + 0.7 * scale;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}