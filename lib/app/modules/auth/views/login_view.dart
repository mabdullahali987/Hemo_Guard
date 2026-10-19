import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_client.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final email = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose(); password.dispose(); super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() { busy = true; error = null; });
    try {
      await Get.find<AuthService>().login(email.text, password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hemo Guard')),
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430),
        child: Form(key: form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.medical_services_outlined, size: 60),
            const SizedBox(height: 20),
            Text('Sign in', style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Use the email and password provided by the superadmin.',
              textAlign: TextAlign.center),
            const SizedBox(height: 30),
            TextFormField(controller: email, enabled: !busy,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || !v.contains('@') ? 'Enter your email' : null),
            const SizedBox(height: 14),
            TextFormField(controller: password, enabled: !busy, obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null,
              onFieldSubmitted: (_) => submit()),
            if (error != null) ...[const SizedBox(height: 14),
              Text(error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: busy ? null : submit,
              child: busy ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in')),
          ],
        ))),
    )),
  );
}
