import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../main.dart';
import 'piano_kids_game_main.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  // ✅ لازم يكون جوه الكلاس
  static final AudioPlayer clickPlayer = AudioPlayer();

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
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Text(
                        'تعذر تحميل صورة الخلفية',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
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
                child: GestureDetector(
                  onTap: () async {
                    // 🔥 تشغيل صوت البابل
                    await clickPlayer.setPlayerMode(PlayerMode.lowLatency);
                    await clickPlayer.setAudioContext(
                      AudioContext(
                        android: AudioContextAndroid(
                          audioFocus: AndroidAudioFocus.none,
                        ),
                      ),
                    );

                    clickPlayer.play(
                      AssetSource('audio/click_bubble.wav'),
                    );

                    // وقف موسيقى الخلفية
                    await MyProfessionalApp.audioPlayer.pause();

                    // فتح لعبة البيانو
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KidsPianoGame(),
                      ),
                    );

                    // رجوع الموسيقى
                    await MyProfessionalApp.audioPlayer.resume();
                  },
                  child: Container(
                    width: 140,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            'assets/image/piano_icon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return const Icon(
                                Icons.piano,
                                color: Colors.white,
                                size: 60,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لعبة البيانو',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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