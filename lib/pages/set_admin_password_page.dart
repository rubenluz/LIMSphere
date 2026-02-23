import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SetAdminPasswordPage extends StatefulWidget {
  const SetAdminPasswordPage({super.key});

  @override
  State<SetAdminPasswordPage> createState() => _SetAdminPasswordPageState();
}

class _SetAdminPasswordPageState extends State<SetAdminPasswordPage> {
  final passwordController = TextEditingController();
  final emailController = TextEditingController(text: 'admin@lab.com');
  bool isLoading = false;

  Future<void> setPassword() async {
    if (passwordController.text.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Sign up admin with Supabase Auth
      final res = await supabase.auth.signUp(
        email: emailController.text,
        password: passwordController.text,
      );

      if (res.user == null) {
        try {
          final response = await supabase.auth.signInWithPassword(
            email: 'email@exemplo.com',
            password: 'password',
          );
          // Se chegou aqui, o login foi um sucesso
          final user = response.user;
        } on AuthException catch (e) {
          // Aqui acede à mensagem de erro
          print(e.message);
        } catch (e) {
          print('Erro inesperado: $e');
        }
      }

      // Insert metadata in users table
      await supabase.from('users').upsert({
        'username': 'admin',
        'role': 'superadmin',
      }, onConflict: 'username');

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set Admin Password")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Set a secure password for the admin account (Supabase Auth).",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : setPassword,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Set Password"),
            ),
          ],
        ),
      ),
    );
  }
}