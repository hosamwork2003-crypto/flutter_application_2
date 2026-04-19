import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../native_piano.dart';

class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  String status = "جارٍ الاتصال بالمحرك...";

  @override
  void initState() {
    super.initState();
    _testInit();
  }

  Future<void> _testInit() async {
    final ok = await NativePiano.init('assets/soundfonts/SalC5Light2.sf2');

    if (!mounted) return;

    setState(() {
      status = ok ? "تم الاتصال بالمحرك ✅" : "فشل الاتصال ❌";
    });
  }

  Future<void> _testSound() async {
    // ✔️ التصحيح هنا
    NativePiano.noteOn(60, velocity: 127);
    await Future.delayed(const Duration(milliseconds: 500));
    NativePiano.noteOff(60);
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

            /// زر الرجوع
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            /// العنوان
            const SafeArea(
              child: Center(
                child: Text(
                  "Games Page",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            /// حالة المحرك
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            /// زر تجربة الصوت
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: _testSound,
                  child: const Text("تشغيل نغمة 🎹"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}