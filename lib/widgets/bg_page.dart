import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BgPage extends StatelessWidget {
  final Widget child;
  final bool showBack;

  const BgPage({
    super.key,
    required this.child,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black, // مهم كـ fallback لو الصورة لسه بتحميل
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/image/main_home.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),

            // زر رجوع بدون AppBar
            if (showBack)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

            // محتوى الصفحة
            SafeArea(
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}