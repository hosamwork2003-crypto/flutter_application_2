// lib/pages/lessons.dart
//
// صفحة الدروس:
// - تجيب الدروس ديناميكيًا من السيرفر حسب المادة
// - أي درس جديد يترفع من صفحة الأدمن يظهر هنا أوتوماتيك
// - تشغيل فيديو من السيرفر مع Cache + Resume + حفظ تقدم
// - مفضلة + علامات (Bookmarks) داخل الفيديو
// - شرطات حمراء لأسئلة Quiz من السيرفر
// - fallback لقراءة quiz marks من lessons.by-subject لو endpoint الخاص بها فشل
// - إيقاف موسيقى الخلفية Pause أول ما تدخل الصفحة ثم إرجاعها عند الخروج

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
  final List<Map<String, dynamic>> rawQuizMarks;

  LessonItem({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.rawQuizMarks,
  });
}

class VideoBookmark {
  final int id;
  final Duration at;
  final String label;

  VideoBookmark({required this.id, required this.at, required this.label});
}

class QuizMark {
  final int id;
  final Duration at;
  bool answered;

  QuizMark({
    required this.id,
    required this.at,
    required this.answered,
  });
}

enum LessonsFilter {
  all,
  favorites,
  bookmarked,
}

class LessonsPage extends StatefulWidget {
  final String subject;
  final String title;

  const LessonsPage({
    super.key,
    required this.subject,
    required this.title,
  });

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  static const String baseUrl = "http://192.168.1.114:3000";
  static const double _videoFrameAspectRatio = 16 / 9;

  late final ApiClient apiClient = ApiClient(baseUrl);
  late final LessonsApi lessonsApi = LessonsApi(apiClient);

  List<LessonItem> lessons = [];
  int _index = 0;

  VideoPlayerController? _video;
  ChewieController? _chewie;

  bool _loading = true;
  String? _error;

  final double _videoWidthFactor = 0.82;
  bool _zoomed = false;
  double get _zoomScale => _zoomed ? 1.35 : 1.0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _tick;

  final Map<String, Duration> _lastPosByLessonId = {};
  final Map<String, double> _progressByLessonId = {};
  final Set<String> _favoriteLessons = {};
  final Map<String, List<VideoBookmark>> _bookmarksByLessonId = {};
  final Set<String> _rewardedLessonsSession = {}; // إضافة جديدة لتتبع الدروس المكتملة

  List<QuizMark> _quizMarks = [];
  bool _quizDialogOpen = false;
  int? _activeMarkId;
  Duration _lastTickPos = Duration.zero;
  int? _blockedMarkId;
  DateTime _lastBlockedPromptAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool _sidebarOpen = true;
  static const double _sidebarWidth = 260;
  LessonsFilter _filter = LessonsFilter.all;

  bool _switching = false;
  Timer? _saveDebounce;

  bool _bgPausedByMe = false;

  @override
  void initState() {
    super.initState();
    _pauseBackgroundMusicNow();
    _bootstrap();
  }

  Future<void> _pauseBackgroundMusicNow() async {
    try {
      await MyProfessionalApp.pauseBgMusic();
      _bgPausedByMe = true;
    } catch (e) {
      debugPrint("PAUSE BG MUSIC ERROR: $e");
    }
  }

  Future<void> _resumeBackgroundMusicIfNeeded() async {
    if (!_bgPausedByMe) return;
    try {
      await MyProfessionalApp.resumeBgMusic();
    } catch (e) {
      debugPrint("RESUME BG MUSIC ERROR: $e");
    }
    _bgPausedByMe = false;
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await _loadLessonsFromServer();

    if (lessons.isEmpty) {
      setState(() {
        _loading = false;
        _error = "لا توجد دروس لهذه المادة حالياً";
      });
      return;
    }

    if (_index >= lessons.length) {
      _index = 0;
    }

    await _loadServerState();
    await _loadBookmarksForCurrent();
    _prefetchBookmarksInBackground();
    await _loadQuizMarksForCurrent();
    await _loadVideo();
  }

  List<Map<String, dynamic>> _normalizeRawQuizMarks(dynamic raw) {
    if (raw is! List) return const [];

    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  Future<void> _loadLessonsFromServer() async {
    try {
      final data = await apiClient.get('/lessons/by-subject/${widget.subject}');
      final items = (data['items'] as List?) ?? const [];

      lessons = items.map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return LessonItem(
          id: (row['id'] ?? '').toString(),
          title: (row['lesson_name'] ?? 'بدون عنوان').toString(),
          videoUrl: (row['video_url'] ?? '').toString(),
          rawQuizMarks: _normalizeRawQuizMarks(row['quiz_marks_json']),
        );
      }).where((l) => l.id.isNotEmpty && l.videoUrl.isNotEmpty).toList();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("LOAD LESSONS ERROR: $e");
      lessons = [];
      _error = "فشل تحميل الدروس";
      if (mounted) setState(() {});
    }
  }

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

        // إضافة جديدة: لو التقدم 95% أو أكتر، نعتبره مكتمل
        if (prog >= 0.99) {
          _rewardedLessonsSession.add(lessonId);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("LOAD STATE ERROR: $e");
    }
  }

  Future<void> _loadBookmarksForCurrent() async {
    if (lessons.isEmpty) return;
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
        } catch (_) {}
      }
    });
  }

  List<QuizMark> _fallbackQuizMarksFromLesson() {
    if (lessons.isEmpty) return [];

    final raw = lessons[_index].rawQuizMarks;
    final out = <QuizMark>[];

    for (final m in raw) {
      final id = (m['mark_id'] as num?)?.toInt() ??
          (m['id'] as num?)?.toInt() ??
          -1;
      final atMs = (m['at_ms'] as num?)?.toInt() ?? 0;
      final active = m['active'] != false;

      if (id <= 0 || atMs < 0 || !active) continue;

      out.add(
        QuizMark(
          id: id,
          at: Duration(milliseconds: atMs),
          answered: false,
        ),
      );
    }

    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  Future<void> _loadQuizMarksForCurrent() async {
    if (lessons.isEmpty) return;
    final lessonId = lessons[_index].id;

    try {
      final rows = await lessonsApi.getQuizMarks(lessonId);

      _quizMarks = rows.map((r) {
        final id = (r["id"] as num?)?.toInt() ??
            (r["mark_id"] as num?)?.toInt() ??
            -1;

        return QuizMark(
          id: id,
          at: Duration(milliseconds: (r["at_ms"] as num).toInt()),
          answered: (r["answered"] == true),
        );
      }).where((m) => m.id > 0).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

      if (_quizMarks.isEmpty) {
        _quizMarks = _fallbackQuizMarksFromLesson();
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("LOAD QUIZ MARKS ERROR: $e");
      _quizMarks = _fallbackQuizMarksFromLesson();
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadVideo() async {
    if (lessons.isEmpty) return;

    final lesson = lessons[_index];
    final url = lesson.videoUrl;

    setState(() {
      _loading = true;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _blockedMarkId = null;
      _activeMarkId = null;
      _quizDialogOpen = false;
      _lastTickPos = Duration.zero;
      _lastBlockedPromptAt = DateTime.fromMillisecondsSinceEpoch(0);
    });

    _tick?.cancel();
    _tick = null;

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

      final resume = _lastPosByLessonId[lesson.id];
      if (resume != null && resume > Duration.zero && resume < _duration) {
        await v.seekTo(resume);
      }

      _lastTickPos = v.value.position;

      _tick = Timer.periodic(const Duration(milliseconds: 350), (_) {
        if (!mounted) return;

        final val = v.value;
        _position = val.position;
        _duration = val.duration;

        double prog = 0.0;
        if (_duration.inMilliseconds > 0) {
          prog = (_position.inMilliseconds / _duration.inMilliseconds)
              .clamp(0.0, 1.0);
        }
        _progressByLessonId[lesson.id] = prog;
        // --- كود المكافأة الجديد ---
        if (prog >= 0.95 && !_rewardedLessonsSession.contains(lesson.id)) {
          _rewardedLessonsSession.add(lesson.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🎉 عاااش! خلصت الدرس وكسبت 20 نجمة و 10 كوينز", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
        // --- نهاية كود المكافأة ---
        _lastPosByLessonId[lesson.id] = _position;

        final prev = _lastTickPos;
        final now = _position;
        _lastTickPos = now;

        Future(() => _handleQuizTick(
              lessonId: lesson.id,
              video: v,
              prev: prev,
              now: now,
            ));

        _scheduleSaveState(lessonId: lesson.id, videoUrl: lesson.videoUrl);

        setState(() {});
      });

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
          blocked: _blockedMarkId != null,
          onBlockedTap: () async {
            final id = _blockedMarkId;
            if (id == null || _video == null) return;

            final mark = _quizMarks.firstWhere(
              (m) => m.id == id,
              orElse: () =>
                  QuizMark(id: -1, at: Duration.zero, answered: true),
            );

            if (mark.id == -1 || mark.answered) {
              _blockedMarkId = null;
              if (mounted) setState(() {});
              return;
            }

            await _video!.pause();
            await _video!.seekTo(mark.at);
            if (!mounted) return;

            await _openQuizOnce(
              lessonId: lesson.id,
              mark: mark,
              video: _video!,
              fromBlockedAttempt: true,
            );
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

  QuizMark? _firstUnansweredBetween(Duration start, Duration end) {
    final a = start <= end ? start : end;
    final b = start <= end ? end : start;

    for (final m in _quizMarks) {
      if (!m.answered && m.at >= a && m.at <= b) return m;
    }
    return null;
  }

  QuizMark? _getBlockedMark() {
    final id = _blockedMarkId;
    if (id == null) return null;
    try {
      final m = _quizMarks.firstWhere((x) => x.id == id);
      if (m.answered) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleQuizTick({
    required String lessonId,
    required VideoPlayerController video,
    required Duration prev,
    required Duration now,
  }) async {
    if (_quizDialogOpen) return;

    const tolerance = Duration(milliseconds: 450);

    final blocked = _getBlockedMark();
    if (blocked != null) {
      final at = blocked.at;

      if (now < at - tolerance) {
        return;
      }

      final passedForward = now > at + tolerance;
      final reachedWhilePlaying = video.value.isPlaying;

      if (!passedForward && !reachedWhilePlaying) {
        return;
      }

      final dt = DateTime.now().difference(_lastBlockedPromptAt);
      if (dt < const Duration(milliseconds: 600)) {
        if (video.value.isPlaying) await video.pause();
        return;
      }
      _lastBlockedPromptAt = DateTime.now();

      if (video.value.isPlaying) await video.pause();

      if (passedForward) {
        await video.seekTo(at);
      }

      await _openQuizOnce(
        lessonId: lessonId,
        mark: blocked,
        video: video,
        fromBlockedAttempt: true,
      );
      return;
    }

    final mark = _firstUnansweredBetween(prev - tolerance, now + tolerance);
    if (mark == null) return;

    if (_activeMarkId == mark.id) return;
    _activeMarkId = mark.id;

    await video.pause();
    await video.seekTo(mark.at);
    await _openQuizOnce(
      lessonId: lessonId,
      mark: mark,
      video: video,
      fromBlockedAttempt: false,
    );
  }

  Future<void> _openQuizOnce({
    required String lessonId,
    required QuizMark mark,
    required VideoPlayerController video,
    required bool fromBlockedAttempt,
  }) async {
    if (_quizDialogOpen) return;
    if (mark.answered) return;

    _quizDialogOpen = true;

    await _showQuizDialog(
      lessonId: lessonId,
      mark: mark,
      video: video,
    );

    _quizDialogOpen = false;

    if (!mark.answered) {
      _blockedMarkId = mark.id;
      if (mounted) setState(() {});
      await video.pause();
      await video.seekTo(mark.at);
    } else {
      _blockedMarkId = null;
      if (mounted) setState(() {});
      await video.play();
    }
  }

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
      barrierDismissible: false,
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
final ok =
                    await lessonsApi.answerQuiz(lessonId, mark.id, selectedKey!);

                if (!ok) {
                  setSt(() {
                    submitting = false;
                    localError = "إجابة خاطئة، حاول مرة أخرى";
                  });
                  return;
                }

                // إضافة جديدة: إظهار رسالة لو جاوب صح لأول مرة
                if (!mark.answered && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("⭐ إجابة صحيحة! كسبت 5 نجوم و 2 كوينز", style: TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                mark.answered = true;
                _blockedMarkId = null;

                if (mounted) setState(() {});
                Navigator.pop(ctx);
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
                        onChanged: submitting
                            ? null
                            : (v) => setSt(() => selectedKey = v),
                        title: Text(text),
                      );
                    }),
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        localError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          _blockedMarkId = mark.id;
                          if (mounted) setState(() {});
                          await video.pause();
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

  void _scheduleSaveState({
    required String lessonId,
    required String videoUrl,
  }) {
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

  void _toggleFavorite() {
    if (lessons.isEmpty) return;
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

  String _fmtShort(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return "${two(h)}:${two(m)}:${two(s)}";
    return "${two(m)}:${two(s)}";
  }

  Future<void> _addBookmark() async {
    if (lessons.isEmpty) return;
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
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
    if (lessons.isEmpty) return const SizedBox.shrink();

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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _deleteBookmark(b),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
    _chewie?.dispose();
    _video?.dispose();
    _resumeBackgroundMusicIfNeeded();
    super.dispose();
  }

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
            border: Border.all(
              color: selected ? Colors.white38 : Colors.white12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.white70,
              ),
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
          chip(
            value: LessonsFilter.favorites,
            icon: Icons.star,
            text: "المفضلة",
          ),
          chip(
            value: LessonsFilter.bookmarked,
            icon: Icons.bookmark,
            text: "فيها علامات",
          ),
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
                    Text(
                      "قائمة دروس ${widget.title}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              itemCount: listIndexes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, idx) {
                                final i = listIndexes[idx];
                                final l = lessons[i];
                                final selected = i == _index;
                                final fav = _favoriteLessons.contains(l.id);
                                final prog = (_progressByLessonId[l.id] ?? 0.0)
                                    .clamp(0.0, 1.0);
                                final bmCount =
                                    (_bookmarksByLessonId[l.id]?.length ?? 0);
                                        final isCompleted = prog >= 0.95;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _goTo(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: selected
                                          ? Colors.white24
                                          : Colors.white10,
                                      border: Border.all(
                                        color: selected
                                            ? Colors.white38
                                            : Colors.white12,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
// 1. المتغير الجديد لمعرفة الدرس اكتمل ولا لأ
                                        Row(
                                          children: [
                                            // 2. الأيقونة الجديدة اللي بتتغير لو الدرس اكتمل
                                            Icon(
                                              isCompleted 
                                                  ? Icons.check_circle 
                                                  : (fav ? Icons.star : Icons.play_circle_outline),
                                              color: isCompleted 
                                                  ? Colors.greenAccent 
                                                  : (fav ? Colors.amber : Colors.white70),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                l.title,
                                                style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : Colors.white70,
                                                  fontWeight: selected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (bmCount > 0) ...[
                                              const Icon(
                                                Icons.bookmark,
                                                color: Colors.white70,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "$bmCount",
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (selected)
                                              const Icon(
                                                Icons.chevron_right,
                                                color: Colors.white,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            value: prog,
                                            minHeight: 6,
                                            backgroundColor: Colors.white12,
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                              Colors.redAccent,
                                            ),
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
            _sidebarOpen
                ? Icons.arrow_back_ios_new
                : Icons.arrow_forward_ios,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(bool hasLessons, LessonItem currentLesson) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            strokeText(
              currentLesson.title,
              size: 25,
              fillColor: const Color.fromARGB(255, 0, 0, 0),
              strokeColor: const Color.fromARGB(255, 255, 255, 255),
              strokeWidth: 1.5,
            ),
            IconButton(
              onPressed: hasLessons ? _toggleFavorite : null,
              tooltip: "مفضلة",
              icon: Icon(
                _favoriteLessons.contains(currentLesson.id)
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.amber,
              ),
            ),
            IconButton(
              onPressed: hasLessons ? _addBookmark : null,
              tooltip: "إضافة علامة داخل الفيديو",
              icon: const Icon(
                Icons.bookmark_add,
                color: Color.fromARGB(255, 117, 104, 104),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoRow(bool hasPrev, bool hasNext) {
    return Row(
      children: [
        _navBtn(
          icon: Icons.chevron_left,
          onTap: hasPrev ? _prev : null,
          tooltip: "الدرس السابق",
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * _videoWidthFactor,
              ),
              child: AspectRatio(
                aspectRatio: _videoFrameAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                                        child: Chewie(
                                          controller: _chewie!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => _zoomed = !_zoomed,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.35),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: Icon(
                                          _zoomed
                                              ? Icons.zoom_out_map
                                              : Icons.zoom_in_map,
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
          ),
        ),
        const SizedBox(width: 10),
        _navBtn(
          icon: Icons.chevron_right,
          onTap: hasNext ? _next : null,
          tooltip: "الدرس القادم",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLessons = lessons.isNotEmpty;
    final hasPrev = hasLessons && _index > 0;
    final hasNext = hasLessons && _index < lessons.length - 1;
    final currentLesson = hasLessons
        ? lessons[_index]
        : LessonItem(id: '', title: '', videoUrl: '', rawQuizMarks: const []);

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
                    padding: EdgeInsets.only(
                      left: _sidebarOpen ? _sidebarWidth : 0,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTitleBar(hasLessons, currentLesson),
                            const SizedBox(height: 14),
                            _buildVideoRow(hasPrev, hasNext),
                            const SizedBox(height: 12),
                            if (hasLessons) _buildBookmarksBar(),
                            const SizedBox(height: 10),
                            if (hasLessons)
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
            border: Border.all(
              color: disabled ? Colors.white12 : Colors.white30,
            ),
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
