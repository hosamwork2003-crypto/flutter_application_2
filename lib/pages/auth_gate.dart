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
  bool isAdmin = false;
  final auth = AuthApi(ApiClient('http://192.168.1.114:3000'));

  @override
  void initState() {
    super.initState();
    _boot();
  }

Future<void> _boot() async {
  try {
    final user = await auth.me();
    final isAdmin = user['is_admin'] == true;

    debugPrint("USER FROM /me = $user");
    debugPrint("AUTH GATE isAdmin = $isAdmin");

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      NoAnimRoute(
        builder: (_) => MainPage(isAdmin: isAdmin),
      ),
    );
    return;
  } catch (_) {}

  if (!mounted) return;
  final ok = await Navigator.of(context).push(
    NoAnimRoute(builder: (_) => const LoginPage()),
  );

  if (ok == true) {
    try {
      final user = await auth.me();
      final isAdmin = user['is_admin'] == true;

      debugPrint("USER FROM /me AFTER LOGIN = $user");
      debugPrint("AUTH GATE isAdmin AFTER LOGIN = $isAdmin");

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        NoAnimRoute(
          builder: (_) => MainPage(isAdmin: isAdmin),
        ),
      );
    } catch (_) {}
  }
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