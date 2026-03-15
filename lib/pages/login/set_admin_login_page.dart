import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SetAdminLoginPage extends StatefulWidget {
  const SetAdminLoginPage({super.key});

  @override
  State<SetAdminLoginPage> createState() => _SetAdminLoginPageState();
}

class _SetAdminLoginPageState extends State<SetAdminLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool isLoading = false;
  bool _showPassword = false;

  Future<void> _createAdmin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (email.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      _snack('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters.');
      return;
    }

    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      final res = await supabase.auth.signUp(email: email, password: password);
      if (res.user == null) throw Exception('Sign-up failed — check your Supabase Auth settings.');

      await supabase.from('users').upsert({
        'user_name': 'admin',
        'user_email': email,
        'user_role': 'superadmin',
        'user_status': 'active',
        'user_table_dashboard': 'write',
        'user_table_chat': 'write',
        'user_table_culture_collection': 'write',
        'user_table_fish_facility': 'write',
        'user_table_resources': 'write',
      }, onConflict: 'user_email');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin account created! Welcome.')),
      );
      Navigator.pushReplacementNamed(context, '/menu');
    } on AuthException catch (e) {
      _snack('Auth error: ${e.message}');
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/connections'),
        ),
        title: const Text('Admin Setup'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.biotech, size: 56, color: colorScheme.primary),
                const SizedBox(height: 12),
                const Text(
                  'Blue Open LIMS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // ── Warning banner ──────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.4)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.admin_panel_settings, color: colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'First account — Admin registration',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No users are registered in this database yet. '
                              'The account you create now will be the '
                              'Administrator (superadmin) with full access to manage users and data.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ────────────────────────────────────────────────────────

                const SizedBox(height: 28),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  obscureText: !_showPassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : _createAdmin,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.admin_panel_settings),
                    label: const Text('Create Admin Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}