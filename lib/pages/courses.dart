// lib/pages/courses.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        // ✅ صفحة مستقلة تمامًا (مش شفافة)
        backgroundColor: Colors.black, // fallback لو الصورة بتتحمّل
        body: Stack(
          children: [
            // ✅ نفس خلفية التطبيق
            Positioned.fill(
              child: Image.asset(
                'assets/image/main_home.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),

            // ✅ زر رجوع بدون AppBar (علشان مفيش شريط أسود فوق)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // ✅ محتوى صفحة الكورسات (جرّب كده)
            const SafeArea(
              child: Center(
                child: Text(
                  "Courses Page",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
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