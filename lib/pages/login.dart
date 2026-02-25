import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_application_1/services/api_client.dart';
import 'package:flutter_application_1/services/auth_api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final auth = AuthApi(ApiClient('http://192.168.1.114:3000'));

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool isRegister = false;
  bool loading = false;
  String? error;

  Future<void> _submit() async {
  if (!mounted) return;

  setState(() {
    loading = true;
    error = null;
  });

  try {
    if (isRegister) {
      await auth.register(_name.text, _email.text, _pass.text);
    } else {
      await auth.login(_email.text, _pass.text);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
    return; // ✅ مهم: يمنع finally يعمل setState بعد pop
  } catch (e) {
    if (!mounted) return;
    setState(() => error = e.toString().replaceFirst('Exception: ', ''));
  } finally {
    if (!mounted) return; // ✅ مهم
    setState(() => loading = false);
  }
}

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/image/main_home.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isRegister ? "Create account" : "Login",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (isRegister) ...[
                        TextField(
                          controller: _name,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec("Name"),
                        ),
                        const SizedBox(height: 10),
                      ],

                      TextField(
                        controller: _email,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec("Email"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec("Password"),
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.redAccent)),
                      ],

                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : _submit,
                          child: Text(loading ? "Please wait..." : (isRegister ? "Register" : "Login")),
                        ),
                      ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
                                  isRegister = !isRegister;
                                  error = null;
                                }),
                        child: Text(
                          isRegister ? "I already have an account" : "Create new account",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.black.withOpacity(0.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );
}