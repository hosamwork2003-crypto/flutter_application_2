import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart'; // ✅ إضافة المكتبة

import 'package:flutter_application_1/services/api_client.dart';
import 'package:flutter_application_1/services/auth_api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin { // ✅ إضافة Mixin
  final auth = AuthApi(ApiClient('http://192.168.1.114:3000'));

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool isRegister = false;
  bool loading = false;
  String? error;

  // --- إعدادات الدودة (نفس السيستم المطور) ---
  late AnimationController _wormController;
  late Animation<double> _wormAnimation;

  final Duration _stepDuration = const Duration(milliseconds: 2500); 
  final Duration _visiblePause = const Duration(seconds: 4);       
  final Duration _backstagePause = const Duration(seconds: 5);     
  double _accumulatedX = -150.0;     
  final double _stepDistance = 60.0; 

  @override
  void initState() {
    super.initState();
    
    _wormController = AnimationController(
      duration: _stepDuration, 
      vsync: this,
    );

    // ربط الإزاحة بتوقيت التصميم (85ms - 185ms)
    _wormAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _wormController,
        curve: const Interval(0.36, 0.78, curve: Curves.easeInOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimationCycle();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _wormController.dispose(); // ✅ تنظيف الذاكرة
    super.dispose();
  }

  void _startAnimationCycle() async {
    if (!mounted) return;
    double screenWidth = MediaQuery.of(context).size.width;

    while (_accumulatedX < screenWidth / 2) {
      if (!mounted) return;
      await _wormController.forward();
      setState(() => _accumulatedX += _stepDistance);
      _wormController.reset();
    }

    await Future.delayed(_visiblePause);

    while (_accumulatedX < screenWidth + 150) {
      if (!mounted) return;
      await _wormController.forward();
      setState(() => _accumulatedX += _stepDistance);
      _wormController.reset();
    }

    await Future.delayed(_backstagePause);

    if (mounted) {
      setState(() => _accumulatedX = -150.0);
      _startAnimationCycle();
    }
  }

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
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
              child: Image.asset('assets/image/main_home.png', fit: BoxFit.cover, gaplessPlayback: true),
            ),
            
            // ✅ الدودة المتحركة في صفحة Login
            AnimatedBuilder(
              animation: _wormAnimation,
              builder: (context, child) {
                double currentPos = _accumulatedX + (_wormAnimation.value * _stepDistance);
                return Positioned(
                  bottom: 50, // خفضنا الارتفاع قليلاً ليناسب صفحة الدخول
                  left: currentPos,
                  child: Transform.flip(
                    flipX: true,
                    child: Lottie.asset(
                      'assets/3d/worm.json',
                      controller: _wormController,
                      width: 120, // صغرنا الحجم قليلاً لعدم تشتيت المستخدم
                    ),
                  ),
                );
              },
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
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                        onPressed: loading ? null : () => setState(() { isRegister = !isRegister; error = null; }),
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