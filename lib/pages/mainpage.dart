import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../main.dart';
import '../widgets/no_anim_route.dart';

// Tabs
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
import 'shop_page.dart';

class MainPage extends StatefulWidget {
  final bool isAdmin;
  const MainPage({super.key, this.isAdmin = false});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  final authApi = AuthApi(ApiClient('http://192.168.1.114:3000'));
  Map<String, dynamic>? me;

  // إعدادات الصوت والواجهة فقط
  bool isMuted = false;
  final AudioPlayer _sfxPlayer = AudioPlayer();
  String? _activeButton;

  bool get _adminVisible => me?['is_admin'] == true;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _prepareSfx();
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }

Future<void> _loadMe() async {
  try {
    final data = await authApi.me();
    me = data;

    // ✅ كود للطباعة النظيفة (اختياري للديباج فقط)
    if (me != null) {
      var cleanData = Map.from(me!); // عمل نسخة من البيانات
      if (cleanData.containsKey('avatar_base64')) {
        cleanData['avatar_base64'] = '... (long string hidden) ...'; // إخفاء النص الطويل
      }
      debugPrint("USER DATA LOADED: $cleanData"); 
    }
    
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
        await _sfxPlayer.play(AssetSource('audio/click_bubble.wav'), mode: PlayerMode.lowLatency);
      } catch (e) {
        debugPrint("SFX Error: $e");
      }
    }
  }

  Future<void> toggleSound() async {
    HapticFeedback.heavyImpact();
    setState(() => isMuted = !isMuted);
    try {
      if (isMuted) await MyProfessionalApp.pauseBgMusic();
      else await MyProfessionalApp.resumeBgMusic();
    } catch (e) { debugPrint("Toggle sound error: $e"); }
  }

  Future<void> _pushInstant(Widget page) async {
    await Navigator.of(context).push(NoAnimRoute(builder: (_) => page));
    await _loadMe();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/image/main_home.png', fit: BoxFit.cover, gaplessPlayback: true),
            ),
            // رائد الفضاء
            Positioned(
              top: 150,
              left: 20,
              child: Lottie.asset('assets/3d/astronot.json', width: 250, height: 250),
            ),
            // القطة
            Positioned(
              bottom: 20,
              left: 50,
              child: Lottie.asset('assets/3d/cute-cat.json', width: 150, height: 150),
            ),
            SafeArea(
              child: Stack(
                children: [
                  _buildHeader(),
                  _buildMainButtons(),
                ],
              ),
            ),
            if (_adminVisible)
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  onPressed: () { _playClickSound(); _pushInstant(const AdminLessonsPage()); },
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // بقية الـ Widgets (BuildHeader, MainButtons, إلخ) تظل كما هي...
  Widget _buildHeader() {
    return Positioned(
      top: 10, left: 10, right: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildProfileAvatar(),
          _buildHeaderIcon('assets/image/rank.png', "Rank", const RankTab()),
          _buildHeaderIcon('assets/image/connects.png', "Connects", const ConnectesTab()),
          _buildSettingsDropdown(),
        ],
      ),
    );
  }

  Widget _buildMainButtons() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 450),
            _buildRow('Courses', const CoursesPage(), 'Games', const GamesPage()),
            const SizedBox(height: 60),
            _buildRow('Lessons', const LessonsSubjectsPage(), 'Sheets', const SheetsPage()),
            const SizedBox(height: 60),
            _buildRow('Social', const SocialPage(), 'Shop', const ShopPage()),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String t1, Widget p1, String t2, Widget p2) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCloudButton(t1, p1, isSmall: true),
        const SizedBox(width: 130),
        _buildCloudButton(t2, p2, isSmall: true),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    final base64Str = me?['avatar_base64'] as String?;
    ImageProvider? img;
    if (base64Str != null && base64Str.isNotEmpty) {
      try { img = MemoryImage(base64Decode(base64Str)); } catch (_) {}
    }
    return GestureDetector(
      onTap: () async {
        _playClickSound();
        if (me == null) {
          final ok = await Navigator.of(context).push(NoAnimRoute(builder: (_) => const LoginPage()));
          if (ok == true) await _loadMe();
        } else { _openProfileSheet(); }
      },
      child: Container(
        height: 160, width: 160,
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/image/avatar_frame.png'), fit: BoxFit.contain)),
        child: Center(
          child: ClipOval(
            child: Container(
              color: Colors.white24, width: 60, height: 60,
              child: img != null ? Image(image: img, fit: BoxFit.cover) : const Icon(Icons.person, color: Colors.black, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(String imagePath, String label, Widget targetPage) {
    return GestureDetector(
      onTap: () { _playClickSound(); _pushInstant(targetPage); },
      child: Image.asset(imagePath, height: 120, width: 120, fit: BoxFit.contain),
    );
  }

  Widget _buildSettingsDropdown() {
    return PopupMenuButton<String>(
      icon: Image.asset('assets/image/settings.png', height: 120, width: 120),
      onSelected: (val) async {
        if (val == 'mute') await toggleSound();
        if (val == 'page') await _pushInstant(const SettingsTab());
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'mute', child: Row(children: [Icon(isMuted ? Icons.volume_off : Icons.volume_up), const SizedBox(width: 8), Text(isMuted ? "Unmute" : "Mute")])),
        const PopupMenuItem(value: 'page', child: Row(children: [Icon(Icons.settings), SizedBox(width: 8), Text("Settings Page")])),
      ],
    );
  }

  Widget _buildCloudButton(String title, Widget page, {required bool isSmall}) {
    final isPressed = _activeButton == title;
    final imgWidth = isSmall ? 280.0 : 550.0;
    return SizedBox(
      width: isSmall ? 125 : 320, height: isSmall ? 100 : 130,
      child: GestureDetector(
        onTapDown: (_) { _playClickSound(); setState(() => _activeButton = title); },
        onTapUp: (_) => setState(() => _activeButton = null),
        onTapCancel: () => setState(() => _activeButton = null),
        onTap: () => _pushInstant(page),
        child: OverflowBox(
          maxWidth: imgWidth, maxHeight: 250,
          child: AnimatedScale(
            scale: isPressed ? 0.9 : 1.0, duration: const Duration(milliseconds: 100),
            child: Container(
              width: imgWidth, height: 250,
              decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/image/cloud.png'), fit: BoxFit.contain)),
              child: Center(
                child: Stack(
                  children: [
                    Text(title, style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = Colors.black)),
                    Text(title, style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openProfileSheet() {
    if (me == null) return;
    final fullName = (me?['full_name'] ?? me?['name'] ?? '') as String;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.black.withOpacity(0.85),
      builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { Navigator.pop(context); final updated = await Navigator.of(context).push(NoAnimRoute(builder: (_) => EditProfilePage(initial: me))); if (updated == true) await _loadMe(); }, child: const Text("Edit"))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { await authApi.logout(); setState(() => me = null); Navigator.pop(context); Navigator.of(context).push(NoAnimRoute(builder: (_) => const LoginPage())); }, child: const Text("Logout"))),
      ]))),
    );
  }
}