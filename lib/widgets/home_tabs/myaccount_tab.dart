import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../pages/login.dart';
import 'package:flutter_application_1/services/api_client.dart';
import 'package:flutter_application_1/services/auth_api.dart';
import '../../widgets/no_anim_route.dart';

class MyAccountTab extends StatefulWidget {
  const MyAccountTab({super.key});

  @override
  State<MyAccountTab> createState() => _MyAccountTabState();
}

class _MyAccountTabState extends State<MyAccountTab> {
  final auth = AuthApi(ApiClient('http://192.168.1.114:3000'));

  bool loading = true;
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
  if (!mounted) return;
  setState(() => loading = true);
  try {
    user = await auth.me();
  } catch (_) {
    user = null;
  }
  if (!mounted) return;
  setState(() => loading = false);
}

  Future<void> _openLogin() async {
    final ok = await Navigator.of(context).push(
      NoAnimRoute(builder: (_) => const LoginPage()),
    );
    if (ok == true) _load();
  }

  Future<void> _logout() async {
  await auth.logout();
  if (!mounted) return;
  setState(() {
    user = null;      // ✅ يخفي البيانات فورًا
    loading = false;  // ✅ يوقف اللودنج
  });
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
                  onPressed: () => Navigator.pop(context),
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
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : (user == null)
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Not logged in",
                                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _openLogin,
                                    child: const Text("Login"),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user!['name'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user!['email'] ?? '',
                                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _logout,
                                    child: const Text("Logout"),
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
}