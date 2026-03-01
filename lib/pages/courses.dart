// lib/pages/courses.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class LessonItem {
  final String title;
  final String videoUrl;
  LessonItem({required this.title, required this.videoUrl});
}

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  // ✅ IP جهازك + بورت السيرفر
  static const String baseUrl = "http://192.168.1.114:3000";

  // ✅ مؤقتًا: دروس ثابتة (بعد كده نجيبهم من API/DB)
  final List<LessonItem> lessons = [
    LessonItem(
      title: "Lesson 1",
      videoUrl: "$baseUrl/uploads/videos/vid1.mp4",
    ),
    // ضيف فيديوهات تانية بنفس الشكل:
    // LessonItem(title: "Lesson 2", videoUrl: "$baseUrl/uploads/videos/vid2.mp4"),
  ];

  int _index = 0;
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final url = lessons[_index].videoUrl;
    final old = _controller;

    final c = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await c.initialize();
      c.setLooping(false);
      await c.play();

      setState(() {
        _controller = c;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _controller = null;
        _loading = false;
        _error = "مش قادر أشغل الفيديو. تأكد إن السيرفر شغال والرابط صحيح.";
      });
    } finally {
      await old?.dispose();
    }
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() => _index--);
    _loadVideo();
  }

  void _next() {
    if (_index >= lessons.length - 1) return;
    setState(() => _index++);
    _loadVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPrev = _index > 0;
    final hasNext = _index < lessons.length - 1;

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
            // ✅ نفس الخلفية
            Positioned.fill(
              child: Image.asset(
                'assets/image/main_home.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),

            // ✅ زر رجوع
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // ✅ محتوى الصفحة
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lessons[_index].title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          // زرار السابق (شمال)
                          IconButton(
                            onPressed: hasPrev ? _prev : null,
                            icon: const Icon(Icons.chevron_left,
                                size: 44, color: Colors.white),
                            disabledColor: Colors.white24,
                            tooltip: "Previous lesson",
                          ),

                          // الفيديو (في النص)
                          Expanded(
                            child: AspectRatio(
                              aspectRatio:
                                  (_controller?.value.isInitialized ?? false)
                                      ? _controller!.value.aspectRatio
                                      : 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  color: Colors.black,
                                  child: _loading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : (_error != null)
                                          ? Center(
                                              child: Text(
                                                _error!,
                                                style: const TextStyle(
                                                    color: Colors.white),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          : Stack(
                                              alignment: Alignment.bottomCenter,
                                              children: [
                                                VideoPlayer(_controller!),

                                                // Play/Pause
                                                Center(
                                                  child: IconButton(
                                                    iconSize: 64,
                                                    color: Colors.white,
                                                    onPressed: () {
                                                      final v =
                                                          _controller!.value;
                                                      setState(() {
                                                        v.isPlaying
                                                            ? _controller!
                                                                .pause()
                                                            : _controller!.play();
                                                      });
                                                    },
                                                    icon: Icon(
                                                      _controller!.value
                                                              .isPlaying
                                                          ? Icons.pause_circle
                                                          : Icons.play_circle,
                                                    ),
                                                  ),
                                                ),

                                                VideoProgressIndicator(
                                                  _controller!,
                                                  allowScrubbing: true,
                                                ),
                                              ],
                                            ),
                                ),
                              ),
                            ),
                          ),

                          // زرار القادم (يمين)
                          IconButton(
                            onPressed: hasNext ? _next : null,
                            icon: const Icon(Icons.chevron_right,
                                size: 44, color: Colors.white),
                            disabledColor: Colors.white24,
                            tooltip: "Next lesson",
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Text(
                        "(${_index + 1} / ${lessons.length})",
                        style: const TextStyle(color: Colors.white70),
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
}