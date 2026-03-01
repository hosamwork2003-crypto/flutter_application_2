// lib/pages/lessons.dart
//
// صفحة الدروس:
// - تشغيل فيديو من السيرفر مع Cache + Resume + حفظ تقدم
// - مفضلة + علامات (Bookmarks) داخل الفيديو
// - شرطات حمراء لأسئلة Quiz من السيرفر
// - إظهار السؤال عند وصول الوقت، ومنع تخطي السؤال بالـ Seek
// - زر "إلغاء" يغلق الـ popup لكن يمنع استكمال الفيديو حتى الحل

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../main.dart';
import '../services/api_client.dart';
import '../services/lessons_api.dart';
import '../widgets/stroke_text.dart';
import '../widgets/video_controls_with_marks.dart';

class LessonItem {
  final String id;
  final String title;
  final String videoUrl;

  LessonItem({
    required this.id,
    required this.title,
    required this.videoUrl,
  });
}

class VideoBookmark {
  final int id;
  final Duration at;
  final String label;

  VideoBookmark({required this.id, required this.at, required this.label});
}

class QuizMark {
  final int id; // id من جدول quiz_marks (أو marks)
  final Duration at; // وقت ظهور السؤال داخل الفيديو
  bool answered; // هل المستخدم جاوب عليه قبل كده؟

  QuizMark({
    required this.id,
    required this.at,
    required this.answered,
  });
}

/// فلتر عرض الدروس داخل القائمة الجانبية
enum LessonsFilter {
  all,
  favorites,
  bookmarked,
}

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  // =========================
  // 0) API
  // =========================
  static const String baseUrl = "http://192.168.1.114:3000";
  late final LessonsApi lessonsApi = LessonsApi(ApiClient(baseUrl));

  // =========================
  // 1) الدروس (حاليًا ثابتة، لاحقًا ممكن تجيبها من السيرفر حسب academic_level)
  // =========================
  final List<LessonItem> lessons = [
    LessonItem(id: "l1", title: "Lesson 1", videoUrl: "$baseUrl/uploads/videos/vid2_fast.mp4?v=1"),
    LessonItem(id: "l2", title: "Lesson 2", videoUrl: "$baseUrl/uploads/videos/vid1_fast.mp4?v=1"),
    LessonItem(id: "l3", title: "Lesson 3", videoUrl: "$baseUrl/uploads/videos/vid2_fast.mp4?v=1"),
  ];

  int _index = 0;

  // =========================
  // 2) مشغل الفيديو
  // =========================
  VideoPlayerController? _video;
  ChewieController? _chewie;

  bool _loading = true;
  String? _error;

  // =========================
  // 3) العرض
  // =========================
  final double _videoWidthFactor = 0.82;
  bool _zoomed = false;
  double get _zoomScale => _zoomed ? 1.35 : 1.0;

  // =========================
  // 4) الوقت/التقدم (Resume + Progress)
  // =========================
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _tick;

  // Resume من السيرفر (لكل درس)
  final Map<String, Duration> _lastPosByLessonId = {};

  // Progress من السيرفر (لكل درس 0..1)
  final Map<String, double> _progressByLessonId = {};

  // Favorites من السيرفر
  final Set<String> _favoriteLessons = {};

  // Bookmarks من السيرفر (لكل درس)
  final Map<String, List<VideoBookmark>> _bookmarksByLessonId = {};

  // =========================
  // 4.5) Quiz Marks
  // =========================
  List<QuizMark> _quizMarks = [];

  // يمنع فتح أكثر من سؤال في نفس الوقت
  bool _quizOpen = false;

  // (اختياري) تمييز السؤال الحالي لو احتجته
  int? _activeMarkId;

  // ✅ لو المستخدم ضغط "إلغاء" داخل السؤال
  // نعمل Block: الفيديو يفضل مقفول لحد ما يجاوب على نفس السؤال
  int? _blockedMarkId;

  // ✅ دعم Scrub / Seek:
  // بنسجل نقطة بداية السحب، وبعدها نعرف هل المستخدم عدّى على سؤال ولا لا
  Duration? _scrubStartPos;

  // =========================
  // 5) Sidebar
  // =========================
  bool _sidebarOpen = true;
  static const double _sidebarWidth = 260;

  // فلتر القائمة الجانبية
  LessonsFilter _filter = LessonsFilter.all;

  // =========================
  // 6) منع تداخل + تقليل الحفظ للسيرفر
  // =========================
  bool _switching = false;
  Timer? _saveDebounce;

  // =========================
  // 7) موسيقى الخلفية
  // =========================
  bool _bgWasSilencedByMe = false;
  double _bgVolumeBefore = 1.0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1) state (resume/progress/fav)
    await _loadServerState();

    // 2) bookmarks للدرس الحالي + prefetch للباقي (لفلتر "فيها علامات")
    await _loadBookmarksForCurrent();
    _prefetchBookmarksInBackground();

    // 3) quiz marks للدرس الحالي
    await _loadQuizMarksForCurrent();

    // 4) تشغيل الفيديو
    await _loadVideo();
  }

  // =========================
  // تحميل state من السيرفر
  // =========================
  Future<void> _loadServerState() async {
    try {
      final items = await lessonsApi.getState();
      for (final row in items) {
        final lessonId = (row["lesson_id"] ?? "").toString();
        final posMs = (row["position_ms"] as num?)?.toInt() ?? 0;
        final prog = (row["progress"] as num?)?.toDouble() ?? 0.0;
        final fav = (row["is_favorite"] ?? false) == true;

        if (lessonId.isEmpty) continue;

        _lastPosByLessonId[lessonId] = Duration(milliseconds: posMs);
        _progressByLessonId[lessonId] = prog.clamp(0.0, 1.0);
        if (fav) _favoriteLessons.add(lessonId);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("LOAD STATE ERROR: $e");
    }
  }

  // =========================
  // Bookmarks (للدرس الحالي)
  // =========================
  Future<void> _loadBookmarksForCurrent() async {
    final lessonId = lessons[_index].id;
    try {
      final rows = await lessonsApi.getBookmarks(lessonId);

      _bookmarksByLessonId[lessonId] = rows.map((r) {
        return VideoBookmark(
          id: (r["id"] as num).toInt(),
          at: Duration(milliseconds: (r["position_ms"] as num).toInt()),
          label: (r["label"] ?? "").toString(),
        );
      }).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("LOAD BOOKMARKS ERROR: $e");
    }
  }

  // ✅ تحميل Bookmarks لباقي الدروس (يدعم فلتر Bookmarked)
  void _prefetchBookmarksInBackground() {
    Future(() async {
      for (final l in lessons) {
        if (_bookmarksByLessonId.containsKey(l.id)) continue;

        try {
          final rows = await lessonsApi.getBookmarks(l.id);
          _bookmarksByLessonId[l.id] = rows.map((r) {
            return VideoBookmark(
              id: (r["id"] as num).toInt(),
              at: Duration(milliseconds: (r["position_ms"] as num).toInt()),
              label: (r["label"] ?? "").toString(),
            );
          }).toList()
            ..sort((a, b) => a.at.compareTo(b.at));

          if (mounted) setState(() {});
        } catch (_) {
          // لو مش مسجل/توكن ناقص: طبيعي يفشل
        }
      }
    });
  }

  // =========================
  // Quiz Marks (للدرس الحالي)
  // =========================
  Future<void> _loadQuizMarksForCurrent() async {
    final lessonId = lessons[_index].id;
    try {
      final rows = await lessonsApi.getQuizMarks(lessonId);

      _quizMarks = rows.map((r) {
        return QuizMark(
          id: (r["id"] as num).toInt(),
          at: Duration(milliseconds: (r["at_ms"] as num).toInt()),
          answered: (r["answered"] == true),
        );
      }).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("LOAD QUIZ MARKS ERROR: $e");
      _quizMarks = [];
      if (mounted) setState(() {});
    }
  }

  // =========================
  // تشغيل الفيديو (cache + resume)
  // =========================
  Future<void> _loadVideo() async {
    final lesson = lessons[_index];
    final url = lesson.videoUrl;

    setState(() {
      _loading = true;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;

      // reset quiz state على تغيير فيديو
      _quizOpen = false;
      _activeMarkId = null;
      _blockedMarkId = null;
      _scrubStartPos = null;
    });

    _tick?.cancel();
    _tick = null;

    // Dispose القديم
    final oldChewie = _chewie;
    final oldVideo = _video;
    _chewie = null;
    _video = null;
    oldChewie?.dispose();
    await oldVideo?.dispose();

    try {
      final file = await DefaultCacheManager().getSingleFile(url);

      if (file.lengthSync() < 200 * 1024) {
        throw Exception("Downloaded file too small. Possibly cached error page.");
      }

      final v = VideoPlayerController.file(file);
      await v.initialize();
      v.setLooping(false);

      _duration = v.value.duration;

      // Resume
      final resume = _lastPosByLessonId[lesson.id];
      if (resume != null && resume > Duration.zero && resume < _duration) {
        await v.seekTo(resume);
      }

      // Timer تحديث + حفظ progress/pos للسيرفر
      _tick = Timer.periodic(const Duration(milliseconds: 350), (_) {
        if (!mounted) return;

        final val = v.value;
        _position = val.position;
        _duration = val.duration;

        // progress
        double prog = 0.0;
        if (_duration.inMilliseconds > 0) {
          prog = (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
        }
        _progressByLessonId[lesson.id] = prog;
        _lastPosByLessonId[lesson.id] = _position;

        // كتم موسيقى الخلفية أثناء التشغيل
        if (val.isPlaying) {
          _silenceBackgroundMusic();
        } else {
          _restoreBackgroundMusic();
        }

        // ✅ trigger quiz أثناء التشغيل الطبيعي
        _checkQuizTrigger(lessonId: lesson.id, video: v);

        // حفظ state
        _scheduleSaveState(lessonId: lesson.id, videoUrl: lesson.videoUrl);

        setState(() {});
      });

      // ✅ Chewie controls (مع marks + منع التخطي لو Blocked)
      final c = ChewieController(
        videoPlayerController: v,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: false,
        allowMuting: true,
        showControls: true,

        customControls: VideoControlsWithMarks(
          marks: _quizMarks.map((m) => m.at).toList(),

          // ✅ لو المستخدم ضغط Cancel، نخلي الفيديو blocked
          blocked: _blockedMarkId != null,

          // ✅ لو المستخدم حاول يشغل وهو blocked: افتح نفس السؤال فورًا
          onBlockedTap: () async {
            final id = _blockedMarkId;
            if (id == null || _video == null) return;

            final mark = _quizMarks.firstWhere(
              (m) => m.id == id,
              orElse: () => QuizMark(id: -1, at: Duration.zero, answered: true),
            );

            if (mark.id == -1 || mark.answered) {
              _blockedMarkId = null;
              if (mounted) setState(() {});
              return;
            }

            await _video!.pause();
            await _video!.seekTo(mark.at);
            if (!mounted) return;

            _quizOpen = true;
            await _showQuizDialog(lessonId: lesson.id, mark: mark, video: _video!);
            _quizOpen = false;
          },

          // ✅ نعرف بداية/نهاية السحب على شريط الفيديو
          onScrubStart: (pos) => _scrubStartPos = pos,
          onScrubEnd: (pos) async {
  _scrubStartPos = null;
  if (_video == null) return;

  final mark = _firstUnansweredMarkAfter(pos);
  if (mark == null) return;

  await _video!.pause();
  await _video!.seekTo(mark.at);

  _quizOpen = true;
  await _showQuizDialog(
    lessonId: lesson.id,
    mark: mark,
    video: _video!,
  );
  _quizOpen = false;
},
        ),
      );

      if (!mounted) {
        c.dispose();
        await v.dispose();
        return;
      }

      setState(() {
        _video = v;
        _chewie = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "تعذّر تشغيل الفيديو.\nسبب تقني: $e";
      });
    }
  }

// =========================
// Quiz Helpers
// =========================
QuizMark? _firstUnansweredMarkAfter(Duration pos) {
  for (final m in _quizMarks) {
    if (!m.answered && pos >= m.at) {
      return m;
    }
  }
  return null;
}

  // =========================
  // Quiz Trigger (أثناء التشغيل الطبيعي)
  // =========================
void _checkQuizTrigger({
  required String lessonId,
  required VideoPlayerController video,
}) async {
  if (_quizOpen) return;
  if (!video.value.isInitialized) return;

  final pos = video.value.position;

  final mark = _firstUnansweredMarkAfter(pos);
  if (mark == null) return;

  _quizOpen = true;
  _activeMarkId = mark.id;

  await video.pause();
  await video.seekTo(mark.at);

  if (!mounted) return;
  await _showQuizDialog(
    lessonId: lessonId,
    mark: mark,
    video: video,
  );

  _quizOpen = false;
  _activeMarkId = null;
}

  // =========================
  // منع تخطي السؤال عند الـ Seek/Scrub
  // =========================
  Future<void> _handleScrubEnded({
    required String lessonId,
    required VideoPlayerController video,
    required Duration start,
    required Duration end,
  }) async {
    if (!video.value.isInitialized) return;

    // ✅ لو في سؤال blocked لازم يتحل: افتحه تاني فورًا
    if (_blockedMarkId != null) {
      final id = _blockedMarkId!;
      final mark = _quizMarks.firstWhere(
        (m) => m.id == id,
        orElse: () => QuizMark(id: -1, at: Duration.zero, answered: true),
      );

      if (mark.id != -1 && !mark.answered) {
        if (_quizOpen) return;
        _quizOpen = true;

        await video.pause();
        await video.seekTo(mark.at);
        if (!mounted) return;

        await _showQuizDialog(lessonId: lessonId, mark: mark, video: video);
        _quizOpen = false;
      }
      return;
    }

    // لا تفتح سؤال فوق سؤال
    if (_quizOpen) return;

    // حدد مدى السحب
    final a = start < end ? start : end;
    final b = start < end ? end : start;

    // لو المستخدم عدّى على mark غير محلول داخل المدى => افتحه
    QuizMark? target;
    for (final m in _quizMarks) {
      if (m.answered) continue;
      if (m.at >= a && m.at <= b) {
        target = m;
        break;
      }
    }
    if (target == null) return;

    _quizOpen = true;
    _activeMarkId = target.id;

    await video.pause();
    await video.seekTo(target.at); // ✅ رجّعه لنقطة السؤال

    if (!mounted) return;
    await _showQuizDialog(lessonId: lessonId, mark: target, video: video);

    _quizOpen = false;
    _activeMarkId = null;
  }

  // =========================
  // Popup السؤال
  // =========================
  Future<void> _showQuizDialog({
    required String lessonId,
    required QuizMark mark,
    required VideoPlayerController video,
  }) async {
    late final Map<String, dynamic> q;
    try {
      q = await lessonsApi.getQuizQuestion(lessonId, mark.id);
    } catch (e) {
      debugPrint("GET QUIZ QUESTION ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تعذر تحميل السؤال: $e")),
        );
      }
      // لو فشل تحميل السؤال نسمح له يكمل (علشان متقفلش الفيديو للأبد)
      await video.play();
      return;
    }

    final questionText = (q["question"] ?? "").toString();
    final options = (q["options"] as List).cast<Map<String, dynamic>>();

    String? selectedKey;
    String? localError;
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false, // ممنوع يقفل بالضغط بره
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            Future<void> submit() async {
              if (selectedKey == null) {
                setSt(() => localError = "اختر إجابة أولاً");
                return;
              }

              setSt(() {
                submitting = true;
                localError = null;
              });

              try {
                final ok = await lessonsApi.answerQuiz(lessonId, mark.id, selectedKey!);

                if (!ok) {
                  setSt(() {
                    submitting = false;
                    localError = "إجابة خاطئة، حاول مرة أخرى";
                  });
                  return;
                }

                // ✅ إجابة صحيحة
                mark.answered = true;

                // ✅ فك البلوك لو كان محجوز
                _blockedMarkId = null;

                if (mounted) setState(() {});
                Navigator.pop(ctx);

                await video.play();
              } catch (e) {
                setSt(() {
                  submitting = false;
                  localError = e.toString().replaceFirst("Exception: ", "");
                });
              }
            }

            return AlertDialog(
              title: const Text("سؤال سريع"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(questionText),
                    const SizedBox(height: 12),
                    ...options.map((o) {
                      final key = (o["key"] ?? "").toString();
                      final text = (o["text"] ?? "").toString();

                      return RadioListTile<String>(
                        value: key,
                        groupValue: selectedKey,
                        onChanged: submitting ? null : (v) => setSt(() => selectedKey = v),
                        title: Text(text),
                      );
                    }),
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Text(localError!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ],
                ),
              ),
              actions: [
                // ✅ إلغاء: يقفل الـ popup لكن يمنع تشغيل الفيديو
         TextButton(
  onPressed: submitting
      ? null
      : () {
          // ❌ لا Resume
          // ❌ لا Play
          Navigator.pop(ctx);
        },
  child: const Text("إلغاء"),
),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  child: Text(submitting ? "جاري التحقق..." : "تأكيد"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================
  // حفظ state (Debounce)
  // =========================
  void _scheduleSaveState({required String lessonId, required String videoUrl}) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), () async {
      try {
        final pos = _lastPosByLessonId[lessonId] ?? Duration.zero;
        final dur = _duration;
        final prog = (_progressByLessonId[lessonId] ?? 0.0).clamp(0.0, 1.0);
        final fav = _favoriteLessons.contains(lessonId);

        await lessonsApi.upsertState(
          lessonId: lessonId,
          videoUrl: videoUrl,
          positionMs: pos.inMilliseconds,
          durationMs: dur.inMilliseconds,
          progress: prog,
          isFavorite: fav,
        );
      } catch (e) {
        debugPrint("SAVE STATE ERROR: $e");
      }
    });
  }

  // =========================
  // Favorites
  // =========================
  void _toggleFavorite() {
    final id = lessons[_index].id;
    setState(() {
      if (_favoriteLessons.contains(id)) {
        _favoriteLessons.remove(id);
      } else {
        _favoriteLessons.add(id);
      }
    });
    _scheduleSaveState(lessonId: id, videoUrl: lessons[_index].videoUrl);
  }

  // =========================
  // Bookmarks UI + Helpers
  // =========================
  String _fmtShort(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return "${two(h)}:${two(m)}:${two(s)}";
    return "${two(m)}:${two(s)}";
  }

  Future<void> _addBookmark() async {
    if (_video == null || !_video!.value.isInitialized) return;

    final lessonId = lessons[_index].id;
    final pos = _video!.value.position;

    final ctrl = TextEditingController(text: "نقطة مهمة");
    final label = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("إضافة علامة داخل الفيديو"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: "وصف مختصر (اختياري)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text("إضافة"),
          ),
        ],
      ),
    );

    if (label == null) return;

    try {
      final item = await lessonsApi.addBookmark(
        lessonId,
        pos.inMilliseconds,
        label.isEmpty ? "علامة" : label,
      );

      final b = VideoBookmark(
        id: (item["id"] as num).toInt(),
        at: Duration(milliseconds: (item["position_ms"] as num).toInt()),
        label: (item["label"] ?? "").toString(),
      );

      final list = _bookmarksByLessonId.putIfAbsent(lessonId, () => []);
      list.add(b);
      list.sort((a, b) => a.at.compareTo(b.at));

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("ADD BOOKMARK ERROR: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تعذر حفظ العلامة: $e")),
      );
    }
  }

  Future<void> _deleteBookmark(VideoBookmark b) async {
    try {
      await lessonsApi.deleteBookmark(b.id);
      final lessonId = lessons[_index].id;
      _bookmarksByLessonId[lessonId]?.removeWhere((x) => x.id == b.id);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("DELETE BOOKMARK ERROR: $e");
    }
  }

  Future<void> _seekToBookmark(Duration at) async {
    if (_video == null || !_video!.value.isInitialized) return;
    await _video!.seekTo(at);
    if (mounted) setState(() {});
  }

  Widget _buildBookmarksBar() {
    final lessonId = lessons[_index].id;
    final list = _bookmarksByLessonId[lessonId] ?? const [];

    if (list.isEmpty) {
      return strokeText(
        'لا توجد علامات داخل الفيديو بعد.',
        size: 15,
        strokeColor: const Color.fromARGB(150, 0, 0, 0),
        fillColor: const Color.fromARGB(150, 255, 255, 255),
        strokeWidth: 3,
      );
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final b = list[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _seekToBookmark(b.at),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bookmark, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "${_fmtShort(b.at)} • ${b.label}",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _deleteBookmark(b),
                  child: const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================
  // موسيقى الخلفية
  // =========================
  Future<void> _silenceBackgroundMusic() async {
    if (_bgWasSilencedByMe) return;
    try {
      await MyProfessionalApp.audioPlayer.setVolume(0);
      _bgWasSilencedByMe = true;
    } catch (_) {}
  }

  Future<void> _restoreBackgroundMusic() async {
    if (!_bgWasSilencedByMe) return;
    try {
      await MyProfessionalApp.audioPlayer.setVolume(_bgVolumeBefore);
    } catch (_) {}
    _bgWasSilencedByMe = false;
  }

  // =========================
  // تنقل بين الدروس
  // =========================
  Future<void> _goTo(int i) async {
    if (_switching) return;
    if (i < 0 || i >= lessons.length) return;

    setState(() {
      _switching = true;
      _index = i;
    });

    await _loadBookmarksForCurrent();
    await _loadQuizMarksForCurrent();
    await _loadVideo();

    if (mounted) setState(() => _switching = false);
  }

  Future<void> _prev() async => _goTo(_index - 1);
  Future<void> _next() async => _goTo(_index + 1);

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _tick?.cancel();
    _restoreBackgroundMusic();
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  // =========================
  // Sidebar Helpers
  // =========================
  bool _lessonHasBookmarks(String lessonId) {
    final list = _bookmarksByLessonId[lessonId];
    return list != null && list.isNotEmpty;
  }

  List<int> get _filteredLessonIndexes {
    final out = <int>[];
    for (int i = 0; i < lessons.length; i++) {
      final l = lessons[i];
      final fav = _favoriteLessons.contains(l.id);
      final hasBm = _lessonHasBookmarks(l.id);

      bool ok = true;
      switch (_filter) {
        case LessonsFilter.all:
          ok = true;
          break;
        case LessonsFilter.favorites:
          ok = fav;
          break;
        case LessonsFilter.bookmarked:
          ok = hasBm;
          break;
      }

      if (ok) out.add(i);
    }
    return out;
  }

  Widget _sidebarFiltersRow() {
    Widget chip({
      required LessonsFilter value,
      required IconData icon,
      required String text,
    }) {
      final selected = _filter == value;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? Colors.white24 : Colors.white10,
            border: Border.all(color: selected ? Colors.white38 : Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.white70),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(value: LessonsFilter.all, icon: Icons.list, text: "الكل"),
          chip(value: LessonsFilter.favorites, icon: Icons.star, text: "المفضلة"),
          chip(value: LessonsFilter.bookmarked, icon: Icons.bookmark, text: "فيها علامات"),
        ],
      ),
    );
  }

  Widget _sidebar() {
    final listIndexes = _filteredLessonIndexes;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: _sidebarOpen ? _sidebarWidth : 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: _sidebarOpen
              ? Column(
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      "قائمة الدروس",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _sidebarFiltersRow(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: listIndexes.isEmpty
                          ? const Center(
                              child: Text(
                                "لا توجد عناصر ضمن هذا الفلتر.",
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              itemCount: listIndexes.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, idx) {
                                final i = listIndexes[idx];
                                final l = lessons[i];
                                final selected = i == _index;
                                final fav = _favoriteLessons.contains(l.id);
                                final prog = (_progressByLessonId[l.id] ?? 0.0).clamp(0.0, 1.0);
                                final bmCount = (_bookmarksByLessonId[l.id]?.length ?? 0);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _goTo(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: selected ? Colors.white24 : Colors.white10,
                                      border: Border.all(color: selected ? Colors.white38 : Colors.white12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              fav ? Icons.star : Icons.play_circle_outline,
                                              color: fav ? Colors.amber : Colors.white70,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                l.title,
                                                style: TextStyle(
                                                  color: selected ? Colors.white : Colors.white70,
                                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (bmCount > 0) ...[
                                              const Icon(Icons.bookmark, color: Colors.white70, size: 18),
                                              const SizedBox(width: 4),
                                              Text(
                                                "$bmCount",
                                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (selected)
                                              const Icon(Icons.chevron_right, color: Colors.white),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            value: prog,
                                            minHeight: 6,
                                            backgroundColor: Colors.white12,
                                            valueColor: const AlwaysStoppedAnimation(Colors.redAccent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _sidebarToggleArrow() {
    return Positioned(
      top: 120,
      left: _sidebarOpen ? _sidebarWidth - 18 : 0,
      child: GestureDetector(
        onTap: () => setState(() => _sidebarOpen = !_sidebarOpen),
        child: Container(
          width: 36,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(
            _sidebarOpen ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final hasPrev = _index > 0;
    final hasNext = _index < lessons.length - 1;
    final currentLesson = lessons[_index];

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
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _sidebar(),
                  ),
                  _sidebarToggleArrow(),

                  AnimatedPadding(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(left: _sidebarOpen ? _sidebarWidth : 0),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // عنوان الدرس + Favorite + Add Bookmark
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                strokeText(
                                  currentLesson.title,
                                  size: 25,
                                  fillColor: const Color.fromARGB(255, 0, 0, 0),
                                  strokeColor: const Color.fromARGB(255, 255, 255, 255),
                                  strokeWidth: 1.5,
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: _toggleFavorite,
                                  tooltip: "مفضلة",
                                  icon: Icon(
                                    _favoriteLessons.contains(currentLesson.id) ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _addBookmark,
                                  tooltip: "إضافة علامة داخل الفيديو",
                                  icon: const Icon(Icons.bookmark_add, color: Color.fromARGB(255, 117, 104, 104)),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // صف: السابق + الفيديو + القادم
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _navBtn(
                                  icon: Icons.chevron_left,
                                  onTap: hasPrev ? _prev : null,
                                  tooltip: "الدرس السابق",
                                ),
                                const SizedBox(width: 10),

                                SizedBox(
                                  width: MediaQuery.of(context).size.width * _videoWidthFactor,
                                  child: AspectRatio(
                                    aspectRatio: (_video?.value.isInitialized ?? false) ? _video!.value.aspectRatio : 16 / 9,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        color: Colors.black,
                                        child: _loading
                                            ? const Center(child: CircularProgressIndicator())
                                            : (_error != null)
                                                ? Center(
                                                    child: Text(
                                                      _error!,
                                                      style: const TextStyle(color: Colors.white),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  )
                                                : Stack(
                                                    children: [
                                                      Positioned.fill(
                                                        child: ClipRect(
                                                          child: Transform.scale(
                                                            scale: _zoomScale,
                                                            child: Chewie(controller: _chewie!),
                                                          ),
                                                        ),
                                                      ),

                                                      // زر التكبير/التصغير
                                                      Positioned(
                                                        top: 8,
                                                        right: 8,
                                                        child: InkWell(
                                                          onTap: () => setState(() => _zoomed = !_zoomed),
                                                          borderRadius: BorderRadius.circular(999),
                                                          child: Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              color: Colors.black.withOpacity(0.35),
                                                              borderRadius: BorderRadius.circular(999),
                                                              border: Border.all(color: Colors.white24),
                                                            ),
                                                            child: Icon(
                                                              _zoomed ? Icons.zoom_out_map : Icons.zoom_in_map,
                                                              color: Colors.white,
                                                              size: 20,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),
                                _navBtn(
                                  icon: Icons.chevron_right,
                                  onTap: hasNext ? _next : null,
                                  tooltip: "الدرس القادم",
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // شريط العلامات (Bookmarks) للدرس الحالي
                            _buildBookmarksBar(),
                            const SizedBox(height: 10),

                            // مؤشر رقم الدرس
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
          ],
        ),
      ),
    );
  }

  // =========================
  // زر دائري للسابق/القادم
  // =========================
  Widget _navBtn({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    final disabled = onTap == null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled ? Colors.white10 : Colors.white24,
            border: Border.all(color: disabled ? Colors.white12 : Colors.white30),
            boxShadow: disabled
                ? const []
                : [
                    BoxShadow(
                      blurRadius: 10,
                      spreadRadius: 1,
                      color: Colors.black.withOpacity(0.35),
                    )
                  ],
          ),
          child: Icon(
            icon,
            color: disabled ? Colors.white24 : Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }
}