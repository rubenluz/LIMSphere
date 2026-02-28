import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../core/local_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _showPassword = false;

  // 0 = this session only, 1 = 1 day, 7 = 1 week, 30 = 30 days
  int _rememberDays = 0;

  static const _rememberOptions = [
    (0,  'Don\'t remember me'),
    (1,  'Remember for 1 day'),
    (7,  'Remember for 1 week'),
    (30, 'Remember for 30 days'),
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstUser();
    _loadSavedPreference();
  }

  Future<void> _loadSavedPreference() async {
    final days = await LocalStorage.getRememberDays();
    if (mounted) setState(() => _rememberDays = days);
  }

  Future<void> _checkFirstUser() async {
    setState(() => isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('user_id')
          .limit(1);
      if (!mounted) return;
      if ((res as List).isEmpty) {
        Navigator.pushReplacementNamed(context, '/set_admin_login');
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('Please enter email and password.');
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) throw Exception('Login failed.');

      final userRows = await Supabase.instance.client
          .from('users')
          .select()
          .eq('user_email', email)
          .limit(1);

      if ((userRows as List).isEmpty) throw Exception('User record not found.');
      final userRow = userRows[0];

      if (userRow['user_role'] != 'superadmin' && userRow['user_status'] == 'pending') {
        await Supabase.instance.client.auth.signOut();
        _snack('Your account is pending admin approval.');
        return;
      }

      await LocalStorage.saveSessionExpiry(_rememberDays);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/menu');
    } on AuthException catch (e) {
      _snack('Login error: ${e.message}');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('Please enter email and password.');
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user == null) throw Exception('Registration failed.');

      await Supabase.instance.client.from('users').insert({
        'user_username': email,
        'user_email': email,
        'user_role': 'user',
        'user_status': 'pending',
      });

      _snack('Registration submitted. Waiting for admin approval.');
    } on AuthException catch (e) {
      _snack('Error: ${e.message}');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Back arrow ──────────────────────────────────────────────────────────
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to connection',
          onPressed: () => Navigator.pushReplacementNamed(context, '/connections'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // ── Scrollable body ─────────────────────────────────────────────────────
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: isLoading && emailController.text.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.biotech,
                            size: 56,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        const Text(
                          'BlueOpenLIMS',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Email
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: passwordController,
                          obscureText: !_showPassword,
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Remember me dropdown
                        DropdownButtonFormField<int>(
                          value: _rememberDays,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.schedule),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _rememberOptions
                              .map((o) => DropdownMenuItem(
                                    value: o.$1,
                                    child: Text(o.$2),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _rememberDays = v ?? 0),
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: isLoading ? null : _login,
                            child: isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('Login'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Register button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: isLoading ? null : _register,
                            child: const Text('Register'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'New accounts require admin approval before login.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}