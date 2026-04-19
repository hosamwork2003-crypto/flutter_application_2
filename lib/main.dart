import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'pages/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyProfessionalApp());
}

class MyProfessionalApp extends StatefulWidget {
  const MyProfessionalApp({super.key});

  static final AudioPlayer audioPlayer = AudioPlayer();

  static Future<void> startBgMusic() async {
    try {
      await audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );

      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.play(AssetSource('audio/welcome.mp3'));
    } catch (e) {
      debugPrint("Error starting music: $e");
    }
  }

  static Future<void> pauseBgMusic() async {
    try {
      await audioPlayer.pause();
    } catch (e) {
      debugPrint("Error pausing music: $e");
    }
  }

  static Future<void> resumeBgMusic() async {
    try {
      await audioPlayer.resume();
    } catch (e) {
      debugPrint("Error resuming music: $e");
    }
  }

  @override
  State<MyProfessionalApp> createState() => _MyProfessionalAppState();
}

class _MyProfessionalAppState extends State<MyProfessionalApp> {
  @override
  void initState() {
    super.initState();
    MyProfessionalApp.startBgMusic();
  }

  @override
  void dispose() {
    MyProfessionalApp.audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(),
      ),
      home: const AuthGate(),
    );
  }
}