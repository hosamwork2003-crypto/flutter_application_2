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

  @override
  State<MyProfessionalApp> createState() => _MyProfessionalAppState();
}

class _MyProfessionalAppState extends State<MyProfessionalApp> {
  @override
  void initState() {
    super.initState();
    _startBackgroundMusic();
  }

  Future<void> _startBackgroundMusic() async {
    try {
      await MyProfessionalApp.audioPlayer.setReleaseMode(ReleaseMode.loop);
      await MyProfessionalApp.audioPlayer.play(AssetSource('audio/welcome.mp3'));
    } catch (e) {
      debugPrint("Error music: $e");
    }
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