import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../main.dart';
import '../widgets/no_anim_route.dart';

// tabs (حسب التقسيمة في الصورة)
import '../widgets/home_tabs/rank_tab.dart';
import '../widgets/home_tabs/connectes_tab.dart';
import '../widgets/home_tabs/settings_tab.dart';

import '../services/api_client.dart';
import '../services/auth_api.dart';

import 'courses.dart';
import 'games.dart';
import 'sheets.dart';
import 'social.dart';
import 'edit_profile.dart';
import 'login.dart';
import 'lessons_subjects.dart';
import 'admin_lessons_page.dart';

class MainPage extends StatefulWidget {
  final bool isAdmin;

  const MainPage({
    super.key,
    this.isAdmin = false,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final authApi = AuthApi(ApiClient('http://192.168.1.114:3000'));
  Map<String, dynamic>? me;

  bool isMuted = false;
  final AudioPlayer _sfxPlayer = AudioPlayer();
  String? _activeButton;

  bool get _adminVisible => me?['is_admin'] == true;

  @override
  void initState() {
    super.initState();
    debugPrint("MAIN PAGE opened");
    _prepareSfx();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final data = await authApi.me();
      me = data;
      debugPrint(
  "MAIN PAGE /me => id=${data['id']}, "
  "name=${data['name']}, "
  "email=${data['email']}, "
  "is_admin=${data['is_admin']}",
);
      debugPrint("MAIN PAGE resolved admin = ${data['is_admin'] == true}");
    } catch (e) {
      debugPrint("MAIN PAGE /me error: $e");
      me = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _prepareSfx() async {
    try {
      await _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
      await _sfxPlayer.setSource(AssetSource('audio/click_bubble.wav'));
    } catch (e) {
      debugPrint("SFX preload error: $e");
    }
  }

  void _playClickSound() async {
    if (!isMuted) {
      try {
        await _sfxPlayer.stop();
        await _sfxPlayer.play(
          AssetSource('audio/click_bubble.wav'),
          mode: PlayerMode.lowLatency,
        );
      } catch (e) {
        debugPrint("SFX Error: $e");
      }
    }
  }

  Future<void> toggleSound() async {
    HapticFeedback.heavyImpact();

    final nextMuted = !isMuted;

    setState(() {
      isMuted = nextMuted;
    });

    try {
      if (nextMuted) {
        await MyProfessionalApp.pauseBgMusic();
      } else {
        await MyProfessionalApp.resumeBgMusic();
      }
    } catch (e) {
      debugPrint("Toggle sound error: $e");
    }
  }

  Future<void> _pushInstant(Widget page) async {
    await Navigator.of(context).push(NoAnimRoute(builder: (_) => page));
    await _loadMe(); // ✅ بعد الرجوع يحدث avatar / admin state
  }

void _openAdminPage() {
  _pushInstant(const AdminLessonsPage());
}

  void _openProfileSheet() {
    if (me == null) return; // ✅ أمان إضافي

    final fullName = (me?['full_name'] ?? me?['name'] ?? '') as String;
    final level = (me?['academic_level'] ?? 'Not set') as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.85),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Academic level: $level",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),

                // ✅ Edit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final updated = await Navigator.of(context).push(
                        NoAnimRoute(builder: (_) => EditProfilePage(initial: me)),
                      );
                      if (updated == true) {
                        await _loadMe();
                      }
                    },
                    child: const Text("Edit"),
                  ),
                ),

                const SizedBox(height: 10),

                // ✅ Logout
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await authApi.logout();
                      if (!mounted) return;

                      setState(() => me = null);
                      Navigator.pop(context); // يقفل الـ bottom sheet

                      // ✅ يفتح صفحة اللوجن ويمنع استخدام التطبيق بدونها
                      final ok = await Navigator.of(context).push(
                        NoAnimRoute(builder: (_) => const LoginPage()),
                      );

                      // لو سجّل بنجاح -> حدث بياناته/الأفاتار
                      if (ok == true) {
                        await _loadMe();
                      } else {
                        if (!mounted) return;
                        await Navigator.of(context).push(
                          NoAnimRoute(builder: (_) => const LoginPage()),
                        );
                        await _loadMe();
                      }
                    },
                    child: const Text("Logout"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileAvatar() {
    final base64Str = me?['avatar_base64'] as String?;
    ImageProvider? img;

    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(base64Str));
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () async {
        _playClickSound();

        if (me == null) {
          final ok = await Navigator.of(context).push(
            NoAnimRoute(builder: (_) => const LoginPage()),
          );
          if (ok == true) {
            await _loadMe();
          }
        } else {
          _openProfileSheet();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            backgroundImage: img,
            child: img == null
                ? const Icon(Icons.person, color: Colors.black)
                : null,
          ),
          const SizedBox(height: 4),
          const Text(
            "Account",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),

          // ✅ زر الأدمن هنا
if (_adminVisible) ...[
  const SizedBox(height: 6),
  const Icon(
    Icons.admin_panel_settings,
    color: Colors.redAccent,
    size: 22,
  ),
],
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, String label, Widget targetPage) {
    return GestureDetector(
      onTap: () {
        _playClickSound();
        _pushInstant(targetPage);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDropdown() {
    return PopupMenuButton<String>(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.settings,
            size: 32,
            color: Color.fromARGB(255, 126, 126, 126),
          ),
          SizedBox(height: 4),
          Text(
            "Settings",
            style: TextStyle(
              color: Color.fromARGB(255, 110, 110, 110),
              fontSize: 12,
            ),
          ),
        ],
      ),
      onSelected: (val) async {
        if (val == 'mute') await toggleSound();
        if (val == 'page') await _pushInstant(const SettingsTab());
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'mute',
          child: Row(
            children: [
              Icon(isMuted ? Icons.volume_off : Icons.volume_up),
              const SizedBox(width: 8),
              Text(isMuted ? "Unmute" : "Mute"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'page',
          child: Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text("Settings Page"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCloudButton(String title, Widget page, {required bool isSmall}) {
    final isPressed = _activeButton == title;
    final imgWidth = isSmall ? 280.0 : 550.0;

    return SizedBox(
      width: isSmall ? 125 : 320,
      height: isSmall ? 100 : 130,
      child: GestureDetector(
        onTapDown: (_) {
          _playClickSound();
          setState(() => _activeButton = title);
        },
        onTapUp: (_) => setState(() => _activeButton = null),
        onTapCancel: () => setState(() => _activeButton = null),
        onTap: () => _pushInstant(page),
        child: OverflowBox(
          maxWidth: imgWidth,
          maxHeight: 250,
          child: AnimatedScale(
            scale: isPressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: imgWidth,
              height: 250,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/image/cloud_1223.png'),
                  fit: BoxFit.contain,
                ),
              ),
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent.withOpacity(0.9),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
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
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildProfileAvatar(),
                        _buildHeaderIcon(
                          Icons.emoji_events,
                          "Rank",
                          const RankTab(),
                        ),
                        _buildHeaderIcon(
                          Icons.hub,
                          "Connects",
                          const ConnectesTab(),
                        ),
                        _buildSettingsDropdown(),
                      ],
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 450),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCloudButton(
                                'Courses',
                                const CoursesPage(),
                                isSmall: true,
                              ),
                              const SizedBox(width: 130),
                              _buildCloudButton(
                                'Games',
                                const GamesPage(),
                                isSmall: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 60),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCloudButton(
                                'Lessons',
                                const LessonsSubjectsPage(),
                                isSmall: true,
                              ),
                                  const SizedBox(width: 130),
                              _buildCloudButton(
                                'Sheets',
                                const SheetsPage(),
                                isSmall: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 60),
                          _buildCloudButton(
                            'Social',
                            const SocialPage(),
                            isSmall: false,
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_adminVisible)
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  onPressed: () {
                    _playClickSound();
                    _openAdminPage();
                  },
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
