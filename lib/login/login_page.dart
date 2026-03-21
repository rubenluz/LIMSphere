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
    final email = days > 0 ? await LocalStorage.getRememberedEmail() : null;
    if (!mounted) return;
    setState(() => _rememberDays = days);
    if (email != null && email.isNotEmpty) {
      emailController.text = email;
    }
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

      if ((userRows as List).isEmpty) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        final goRegister = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.person_search_outlined, size: 40),
            title: const Text('Email not registered'),
            content: Text(
              '"$email" has no account in this system.\n\nWould you like to register?',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Register'),
              ),
            ],
          ),
        );
        if (goRegister == true && mounted) {
          Navigator.pushReplacementNamed(context, '/register');
        }
        return;
      }
      final userRow = userRows[0];

      if (userRow['user_role'] != 'superadmin' && userRow['user_status'] == 'pending') {
        await Supabase.instance.client.auth.signOut();
        _snack('Your account is pending admin approval.');
        return;
      }

      await LocalStorage.saveSessionExpiry(_rememberDays);
      if (_rememberDays > 0) {
        await LocalStorage.saveRememberedEmail(email);
      } else {
        await LocalStorage.clearRememberedEmail();
      }

      // Record this login timestamp (non-critical — never blocks login)
      try {
        await Supabase.instance.client
            .from('users')
            .update({'user_last_login': DateTime.now().toIso8601String()})
            .eq('user_email', email);
      } catch (_) {}

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
                          initialValue: _rememberDays,
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
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Not registered yet?',
                                style: TextStyle(fontSize: 13, color: Colors.grey)),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.pushReplacementNamed(
                                      context, '/register'),
                              child: const Text('Register here!',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ],
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