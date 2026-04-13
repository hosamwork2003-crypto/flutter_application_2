import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_api.dart';
import '../widgets/no_anim_route.dart';

import 'mainpage.dart';
import 'login.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final auth = AuthApi(ApiClient('http://192.168.1.114:3000'));

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // 1) لو التوكن صالح -> MainPage
    try {
      await auth.me();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(NoAnimRoute(builder: (_) => const MainPage()));
      return;
    } catch (_) {}

    // 2) مش مسجل -> افتح Login و"استنى" نتيجته
    if (!mounted) return;
    final ok = await Navigator.of(context).push(
      NoAnimRoute(builder: (_) => const LoginPage()),
    );

    // 3) لو نجح -> ادخل MainPage
    if (ok == true) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(NoAnimRoute(builder: (_) => const MainPage()));
      return;
    }

    // 4) لو رجع false (ضغط Back) -> يفضل على شاشة اللوجن (يجرب تاني)
    if (!mounted) return;
    _boot();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/main_home.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}