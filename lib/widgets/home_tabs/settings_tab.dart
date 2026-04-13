import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

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
              child: Padding(
                padding: const EdgeInsets.only(top: 52),
                child: ListView(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.notifications, color: Colors.white),
                      title: Text("Push Notifications", style: TextStyle(color: Color.fromARGB(255, 228, 76, 6))),
                    ),
                    ListTile(
                      leading: Icon(Icons.language, color: Colors.white),
                      title: Text("Language", style: TextStyle(color: Colors.white)),
                      subtitle: Text("English", style: TextStyle(color: Colors.white70)),
                    ),
                    ListTile(
                      leading: Icon(Icons.info, color: Colors.white),
                      title: Text("About", style: TextStyle(color: Colors.white)),
                      subtitle: Text("Version 1.0.0", style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}