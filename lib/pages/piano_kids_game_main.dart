
import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';

class PianoNote {
  final String noteName;
  final int octave;
  final bool isBlack;
  final int midiNumber;
  final String noteId;

  const PianoNote({
    required this.noteName,
    required this.octave,
    required this.isBlack,
    required this.midiNumber,
    required this.noteId,
  });

  String get displayName => '$noteName$octave';

  String get arabicName {
    const map = {
      'C': 'دو',
      'Db': 'دو دييز',
      'D': 'ري',
      'Eb': 'ري دييز',
      'E': 'مي',
      'F': 'فا',
      'Gb': 'فا دييز',
      'G': 'صول',
      'Ab': 'صول دييز',
      'A': 'لا',
      'Bb': 'لا دييز',
      'B': 'سي',
    };
    return '${map[noteName] ?? noteName} $octave';
  }
}

class KidsPianoGame extends StatefulWidget {
  const KidsPianoGame({super.key});

  @override
  State<KidsPianoGame> createState() => _KidsPianoGameState();
}

class _KidsPianoGameState extends State<KidsPianoGame> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _pianoAreaKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  final MidiPro _midi = MidiPro();
  bool _audioReady = false;
  bool _isWarmingUp = false;

  late final List<PianoNote> _allNotes;

  PianoNote? _currentNote;
  PianoNote? _highlightedNote;
  String? _pressedNoteId;

  int _score = 0;
  int _stars = 0;
  String _message = 'بيانو حر: اضغط على أي مفتاح';
  String _playerName = 'Player 1';
  int _visibleKeyCount = 18;

  int _gameState = 0;
  bool _isPlayingTeacherSequence = false;

  bool _isFingerDown = false;
  bool _isPianoTouchActive = false;
  String? _lastPlayedKey;

  final List<PianoNote> _teacherSequence = [];
  final List<PianoNote> _childSequence = [];

  final List<int> _activeNotes = [];
  static const int _maxSimultaneousNotes = 6;
  static const int _defaultVelocity = 127;

  @override
  void initState() {
    super.initState();
    _allNotes = _buildAvailableNotes();
    _initMidiEngine();
  }

  @override
  void dispose() {
    _stopAllActiveNotes();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initMidiEngine() async {
    if (_isWarmingUp) return;

    setState(() {
      _isWarmingUp = true;
      _audioReady = false;
      _message = 'جارٍ تجهيز صوت البيانو...';
    });

    try {
      await _midi.loadSoundfont(
        sf2Path: 'assets/soundfonts/export.sf2',
        instrumentIndex: 0,
      );

      // Warm-up: تشغيل نغمة شبه صامتة مرة واحدة لتجهيز محرك الصوت
      // وتقليل التعليق في أول ضغطة حقيقية.
      _midi.playMidiNote(midi: 60, velocity: 1);
      await Future.delayed(const Duration(milliseconds: 45));
      _midi.stopMidiNote(midi: 60);
      await Future.delayed(const Duration(milliseconds: 10));

      if (!mounted) return;
      setState(() {
        _audioReady = true;
        _isWarmingUp = false;
        _message = 'بيانو حر: اضغط على أي مفتاح';
      });
    } catch (e) {
      debugPrint('MIDI init error: $e');

      if (!mounted) return;
      setState(() {
        _audioReady = false;
        _isWarmingUp = false;
        _message = 'تعذر تجهيز صوت البيانو';
      });
    }
  }

  List<PianoNote> _buildAvailableNotes() {
    const chromaticOrder = [
      'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
    ];
    const blackNames = {'Db', 'Eb', 'Gb', 'Ab', 'Bb'};

    int midi = 21;
    final notes = <PianoNote>[
      PianoNote(noteName: 'A', octave: 0, isBlack: false, midiNumber: midi++, noteId: 'A0'),
      PianoNote(noteName: 'Bb', octave: 0, isBlack: true, midiNumber: midi++, noteId: 'Bb0'),
      PianoNote(noteName: 'B', octave: 0, isBlack: false, midiNumber: midi++, noteId: 'B0'),
    ];

    for (int octave = 1; octave <= 7; octave++) {
      for (final name in chromaticOrder) {
        notes.add(
          PianoNote(
            noteName: name,
            octave: octave,
            isBlack: blackNames.contains(name),
            midiNumber: midi++,
            noteId: '$name$octave',
          ),
        );
      }
    }

    notes.addAll([
      PianoNote(noteName: 'C', octave: 8, isBlack: false, midiNumber: midi++, noteId: 'C8'),
      PianoNote(noteName: 'Db', octave: 8, isBlack: true, midiNumber: midi, noteId: 'Db8'),
    ]);

    return notes;
  }

  void _playNoteSound(PianoNote note, {int velocity = _defaultVelocity}) {
    if (!_audioReady) return;

    final safeVelocity = velocity.clamp(1, 127);

    _activeNotes.remove(note.midiNumber);

    if (_activeNotes.length >= _maxSimultaneousNotes) {
      final oldest = _activeNotes.removeAt(0);
      _midi.stopMidiNote(midi: oldest);
    }

    _midi.playMidiNote(midi: note.midiNumber, velocity: safeVelocity);
    _activeNotes.add(note.midiNumber);
  }

  void _stopNoteSound(PianoNote note) {
    if (!_audioReady) return;
    _midi.stopMidiNote(midi: note.midiNumber);
    _activeNotes.remove(note.midiNumber);
  }

  void _stopAllActiveNotes() {
    if (!_audioReady) return;
    for (final midi in List<int>.from(_activeNotes)) {
      _midi.stopMidiNote(midi: midi);
    }
    _activeNotes.clear();
  }

  void _playNote(PianoNote note) {
    if (!_audioReady || _isWarmingUp) return;
    if (_lastPlayedKey == note.noteId) return;
    _lastPlayedKey = note.noteId;

    final previousNote = _currentNote;

    if (previousNote != null &&
        previousNote.noteId != note.noteId &&
        !_isPlayingTeacherSequence) {
      _stopNoteSound(previousNote);
    }

    _playNoteSound(note);

    if (!mounted) return;

    String nextMessage = _message;
    bool shouldShowWrongSnack = false;
    bool shouldShowMissingTeacherSnack = false;
    bool shouldShowCorrectSnack = false;
    bool shouldShowSuccessSnack = false;
    int earned = 0;

    if (_isPlayingTeacherSequence) {
      setState(() {
        _currentNote = note;
        _pressedNoteId = note.noteId;
      });
      return;
    }

    if (_gameState == 0) {
      nextMessage = 'بيانو حر: ${note.arabicName}';

      setState(() {
        _currentNote = note;
        _pressedNoteId = note.noteId;
        _message = nextMessage;
      });
      return;
    }

    if (_gameState == 1) {
      setState(() {
        _currentNote = note;
        _pressedNoteId = note.noteId;
        _teacherSequence.add(note);
        _message = 'تم تسجيل ${note.arabicName} في تسلسل المعلّم';
      });
      return;
    }

    if (_teacherSequence.isEmpty) {
      shouldShowMissingTeacherSnack = true;

      setState(() {
        _currentNote = note;
        _pressedNoteId = note.noteId;
        _message = 'سجّل تسلسل المعلّم أولًا';
      });

      if (shouldShowMissingTeacherSnack) {
        _showSnack('لا يوجد تسلسل محفوظ بعد', Colors.orange);
      }
      return;
    }

    final expectedIndex = _childSequence.length;
    if (expectedIndex >= _teacherSequence.length) {
      setState(() {
        _currentNote = note;
        _pressedNoteId = note.noteId;
        _childSequence.clear();
      });
      return;
    }

    final expectedNote = _teacherSequence[expectedIndex];
    final isCorrect =
        note.noteName == expectedNote.noteName &&
        note.octave == expectedNote.octave;

    if (!isCorrect) {
      shouldShowWrongSnack = true;

      setState(() {
        _currentNote = note;
        _pressedNoteId = note.noteId;
        _childSequence.clear();
        _message = 'خطأ. ابدأ من أول التسلسل';
      });

      if (shouldShowWrongSnack) {
        _showSnack('خطأ. ابدأ من البداية', Colors.red);
      }
      return;
    }

    final completedSequence =
        (_childSequence.length + 1) == _teacherSequence.length;

    if (completedSequence) {
      earned = _teacherSequence.length * 10;
      shouldShowSuccessSnack = true;

      setState(() {
        _currentNote = note;
        _pressedNoteId = note.noteId;
        _childSequence.clear();
        _score += earned;
        _stars += 1;
        _message = 'أحسنت! الطفل نفذ التسلسل كاملًا';
      });

      if (shouldShowSuccessSnack) {
        _showSnack('ممتاز! +$earned نقطة ⭐', Colors.green);
      }
      return;
    }

    shouldShowCorrectSnack = true;

    setState(() {
      _currentNote = note;
      _pressedNoteId = note.noteId;
      _childSequence.add(note);
      _message = 'صحيح! أكمل باقي التسلسل';
    });

    if (shouldShowCorrectSnack) {
      _showSnack('صحيح، أكمل', Colors.green);
    }
  }

  Future<void> _playTeacherSequence() async {
    if (_teacherSequence.isEmpty || _isPlayingTeacherSequence) return;

    _stopAllActiveNotes();

    setState(() {
      _isPlayingTeacherSequence = true;
      _message = 'استمع لتسلسل المعلّم';
      _highlightedNote = null;
      _pressedNoteId = null;
    });

    for (final note in _teacherSequence) {
      if (!mounted) return;

      setState(() {
        _highlightedNote = note;
        _pressedNoteId = note.noteId;
      });

      _playNoteSound(note, velocity: 127);
      await Future.delayed(const Duration(milliseconds: 320));
      _stopNoteSound(note);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;

    setState(() {
      _highlightedNote = null;
      _pressedNoteId = null;
      _isPlayingTeacherSequence = false;
      _message = _gameState == 2
          ? 'الآن دور الطفل: كرر نفس التسلسل'
          : 'انتهى تشغيل تسلسل المعلّم';
    });
  }

  void _showSnack(String text, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 900),
        backgroundColor: color,
      ),
    );
  }

  void _advanceChallengeState() {
    if (_gameState == 0) {
      setState(() {
        _gameState = 1;
        _teacherSequence.clear();
        _childSequence.clear();
        _message = 'وضع تسجيل المعلّم: اضغط النغمات المطلوبة';
      });
      return;
    }

    if (_gameState == 1) {
      if (_teacherSequence.isEmpty) {
        setState(() {
          _message = 'سجّل نغمة واحدة على الأقل أولًا';
        });
        _showSnack('سجّل تسلسل المعلّم أولًا', Colors.orange);
        return;
      }

      setState(() {
        _gameState = 2;
        _childSequence.clear();
        _message = 'وضع الطفل: كرر نفس التسلسل';
      });
      return;
    }

    _stopAllActiveNotes();

    setState(() {
      _gameState = 0;
      _teacherSequence.clear();
      _childSequence.clear();
      _highlightedNote = null;
      _pressedNoteId = null;
      _message = 'بيانو حر: اضغط على أي مفتاح';
    });
  }

  String _challengeButtonLabel() {
    if (_gameState == 0) return 'ابدأ تسجيل المعلّم';
    if (_gameState == 1) return 'ابدأ دور الطفل';
    return 'إنهاء التحدي';
  }

  IconData _challengeButtonIcon() {
    if (_gameState == 0) return Icons.fiber_manual_record;
    if (_gameState == 1) return Icons.child_care;
    return Icons.stop_circle_outlined;
  }

  String _modeLabel() {
    if (_gameState == 0) return 'بيانو حر';
    if (_gameState == 1) return 'تسجيل المعلّم';
    return 'دور الطفل';
  }

  Color _modeColor() {
    if (_gameState == 0) return Colors.teal;
    if (_gameState == 1) return Colors.deepOrange;
    return Colors.deepPurple;
  }

  Color _keyAccent(String noteName) {
    switch (noteName) {
      case 'C':
        return const Color(0xFFFF6B6B);
      case 'D':
        return const Color(0xFFFFD93D);
      case 'E':
        return const Color(0xFF6BCB77);
      case 'F':
        return const Color(0xFF4D96FF);
      case 'G':
        return const Color(0xFF845EC2);
      case 'A':
        return const Color(0xFFFF9671);
      case 'B':
        return const Color(0xFF00C9A7);
      default:
        return const Color(0xFF222222);
    }
  }

  bool _isTeacherDemoKey(PianoNote note) {
    return _isPlayingTeacherSequence &&
        _highlightedNote?.noteId == note.noteId;
  }

  PianoNote? _findNoteAtPosition({
    required Offset globalPosition,
    required List<PianoNote> visibleNotes,
    required List<PianoNote> visibleWhiteNotes,
    required double whiteKeyWidth,
    required double whiteKeyHeight,
    required double blackKeyWidth,
    required double blackKeyHeight,
  }) {
    final ctx = _pianoAreaKey.currentContext;
    if (ctx == null) return null;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final local = box.globalToLocal(globalPosition);
    final x = local.dx;
    final y = local.dy;

    if (x < 0 || y < 0 || y > whiteKeyHeight) return null;

    final baseWidth =
        (visibleWhiteNotes.length * whiteKeyWidth) +
        ((visibleWhiteNotes.length - 1) * 4);

    for (int whiteIndex = 0; whiteIndex < visibleWhiteNotes.length; whiteIndex++) {
      final whiteNote = visibleWhiteNotes[whiteIndex];

      if (whiteNote.noteName == 'E' || whiteNote.noteName == 'B') {
        continue;
      }

      final currentIndex = visibleNotes.indexOf(whiteNote);
      PianoNote? blackAfter;

      for (int i = currentIndex + 1; i < visibleNotes.length; i++) {
        if (visibleNotes[i].isBlack) {
          blackAfter = visibleNotes[i];
          break;
        }
        if (!visibleNotes[i].isBlack) {
          break;
        }
      }

      if (blackAfter == null) continue;

      double left =
          (whiteIndex * (whiteKeyWidth + 4)) + whiteKeyWidth - (blackKeyWidth / 2);

      final maxLeft = baseWidth - blackKeyWidth;
      if (left > maxLeft) {
        left = maxLeft;
      }

      if (x >= left &&
          x <= left + blackKeyWidth &&
          y >= 0 &&
          y <= blackKeyHeight) {
        return blackAfter;
      }
    }

    for (int i = 0; i < visibleWhiteNotes.length; i++) {
      final left = i * (whiteKeyWidth + 4);
      if (x >= left && x <= left + whiteKeyWidth) {
        return visibleWhiteNotes[i];
      }
    }

    return null;
  }

  void _handlePointerDown({
    required PointerDownEvent event,
    required List<PianoNote> visibleNotes,
    required List<PianoNote> visibleWhiteNotes,
    required double whiteKeyWidth,
    required double whiteKeyHeight,
    required double blackKeyWidth,
    required double blackKeyHeight,
  }) {
    _isFingerDown = true;

    final note = _findNoteAtPosition(
      globalPosition: event.position,
      visibleNotes: visibleNotes,
      visibleWhiteNotes: visibleWhiteNotes,
      whiteKeyWidth: whiteKeyWidth,
      whiteKeyHeight: whiteKeyHeight,
      blackKeyWidth: blackKeyWidth,
      blackKeyHeight: blackKeyHeight,
    );

    if (note != null) {
      _isPianoTouchActive = true;
      _playNote(note);
    } else {
      _isPianoTouchActive = false;
      _lastPlayedKey = null;

      setState(() {
        _pressedNoteId = null;
      });
    }
  }

  void _handlePointerMove({
    required PointerMoveEvent event,
    required List<PianoNote> visibleNotes,
    required List<PianoNote> visibleWhiteNotes,
    required double whiteKeyWidth,
    required double whiteKeyHeight,
    required double blackKeyWidth,
    required double blackKeyHeight,
  }) {
    if (!_isFingerDown || !_isPianoTouchActive) return;

    final note = _findNoteAtPosition(
      globalPosition: event.position,
      visibleNotes: visibleNotes,
      visibleWhiteNotes: visibleWhiteNotes,
      whiteKeyWidth: whiteKeyWidth,
      whiteKeyHeight: whiteKeyHeight,
      blackKeyWidth: blackKeyWidth,
      blackKeyHeight: blackKeyHeight,
    );

    if (note != null) {
      _playNote(note);
    } else {
      _lastPlayedKey = null;

      setState(() {
        _pressedNoteId = null;
      });
    }
  }

 void _handlePointerEnd() {
  _isFingerDown = false;
  _isPianoTouchActive = false;
  _lastPlayedKey = null;

  if (!mounted) return;

  setState(() {
    _pressedNoteId = null;
  });
}

  List<Widget> _buildBlackKeyOverlays({
    required List<PianoNote> visibleWhiteNotes,
    required List<PianoNote> visibleNotes,
    required double whiteKeyWidth,
    required double blackKeyWidth,
    required double blackKeyHeight,
  }) {
    final widgets = <Widget>[];

    final baseWidth =
        (visibleWhiteNotes.length * whiteKeyWidth) +
        ((visibleWhiteNotes.length - 1) * 4);

    for (int whiteIndex = 0; whiteIndex < visibleWhiteNotes.length; whiteIndex++) {
      final whiteNote = visibleWhiteNotes[whiteIndex];

      if (whiteNote.noteName == 'E' || whiteNote.noteName == 'B') {
        continue;
      }

      final currentIndex = visibleNotes.indexOf(whiteNote);
      PianoNote? blackAfter;

      for (int i = currentIndex + 1; i < visibleNotes.length; i++) {
        if (visibleNotes[i].isBlack) {
          blackAfter = visibleNotes[i];
          break;
        }
        if (!visibleNotes[i].isBlack) {
          break;
        }
      }

      if (blackAfter == null) continue;

      double left =
          (whiteIndex * (whiteKeyWidth + 4)) + whiteKeyWidth - (blackKeyWidth / 2);

      final maxLeft = baseWidth - blackKeyWidth;
      if (left > maxLeft) {
        left = maxLeft;
      }

      widgets.add(
        Positioned(
          left: left,
          top: 0,
          child: _BlackKey(
            note: blackAfter,
            width: blackKeyWidth,
            height: blackKeyHeight,
            isHighlighted: _highlightedNote?.noteId == blackAfter.noteId,
            isPressed: !_isPlayingTeacherSequence && _pressedNoteId == blackAfter.noteId,
            isTeacherDemo: _isTeacherDemoKey(blackAfter),
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final clampedVisibleCount = _visibleKeyCount.clamp(7, 89);

    final zoom = 30 / clampedVisibleCount;
    final whiteKeyWidth = (48 * zoom).clamp(42.0, 92.0);
    final blackKeyWidth = (30 * zoom).clamp(24.0, 58.0);

    final whiteKeyHeight = screenHeight * 0.5;
    final blackKeyHeight = whiteKeyHeight * 0.62;

    final visibleNotes = _allNotes;
    final visibleWhiteNotes = visibleNotes.where((n) => !n.isBlack).toList();

    final pianoWidth =
        (visibleWhiteNotes.length * whiteKeyWidth) +
        ((visibleWhiteNotes.length - 1) * 4) +
        blackKeyWidth;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF6F5FB),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFB39DDB),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'قائمة البيانو',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اسم اللاعب: $_playerName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('اسم اللاعب'),
                subtitle: Text(_playerName),
                onTap: () async {
                  final controller = TextEditingController(text: _playerName);

                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('اسم اللاعب'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'اكتب اسم اللاعب',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, controller.text.trim()),
                          child: const Text('حفظ'),
                        ),
                      ],
                    ),
                  );

                  if (result != null && result.isNotEmpty) {
                    setState(() {
                      _playerName = result;
                    });
                  }
                },
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('تفاصيل اللعبة'),
                subtitle: Text('بيانو حر أولًا، ثم تسجيل المعلّم، ثم تنفيذ الطفل'),
              ),
              const ListTile(
                leading: Icon(Icons.settings),
                title: Text('الإعدادات'),
                subtitle: Text('التحكم في تكبير وتصغير المفاتيح'),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تكبير وتصغير المفاتيح',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _visibleKeyCount = (_visibleKeyCount - 3).clamp(7, 89);
                            });
                          },
                          icon: const Icon(Icons.remove_circle, size: 32),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$_visibleKeyCount',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _visibleKeyCount = (_visibleKeyCount + 3).clamp(7, 89);
                            });
                          },
                          icon: const Icon(Icons.add_circle, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'كلما قلّ الرقم كبرت المفاتيح أكثر، وكل المفاتيح تظل متاحة بالسحب.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFB39DDB),
        title: const Text(
          'لعبة البيانو للأطفال',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 5)),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _currentNote?.arabicName ?? 'بيانو حر: اضغط على أي مفتاح',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(label: _modeLabel(), color: _modeColor()),
                        _InfoChip(label: 'النقاط: $_score', color: Colors.orange),
                        _InfoChip(label: 'النجوم: $_stars', color: Colors.amber),
                        _InfoChip(label: 'تسلسل المعلّم: ${_teacherSequence.length}', color: Colors.blue),
                        _InfoChip(label: 'ما أدخله الطفل: ${_childSequence.length}', color: Colors.pink),
                        _InfoChip(label: 'اللاعب: $_playerName', color: Colors.indigo),
                        _InfoChip(
                          label: _audioReady ? 'الصوت جاهز' : 'جارٍ تجهيز الصوت',
                          color: _audioReady ? Colors.green : Colors.redAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _advanceChallengeState,
                          icon: Icon(_challengeButtonIcon()),
                          label: Text(_challengeButtonLabel()),
                        ),
                        ElevatedButton.icon(
                          onPressed: _teacherSequence.isEmpty || _isPlayingTeacherSequence
                              ? null
                              : _playTeacherSequence,
                          icon: const Icon(Icons.volume_up),
                          label: const Text('اسمع تسلسل المعلّم'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            _stopAllActiveNotes();
                            setState(() {
                              _score = 0;
                              _stars = 0;
                              _teacherSequence.clear();
                              _childSequence.clear();
                              _gameState = 0;
                              _highlightedNote = null;
                              _pressedNoteId = null;
                              _message = 'تمت إعادة التعيين';
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: _isPianoTouchActive
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: IgnorePointer(
                  ignoring: !_audioReady || _isWarmingUp,
                  child: Listener(
                    onPointerDown: (event) => _handlePointerDown(
                      event: event,
                      visibleNotes: visibleNotes,
                      visibleWhiteNotes: visibleWhiteNotes,
                      whiteKeyWidth: whiteKeyWidth,
                      whiteKeyHeight: whiteKeyHeight,
                      blackKeyWidth: blackKeyWidth,
                      blackKeyHeight: blackKeyHeight,
                    ),
                    onPointerMove: (event) => _handlePointerMove(
                      event: event,
                      visibleNotes: visibleNotes,
                      visibleWhiteNotes: visibleWhiteNotes,
                      whiteKeyWidth: whiteKeyWidth,
                      whiteKeyHeight: whiteKeyHeight,
                      blackKeyWidth: blackKeyWidth,
                      blackKeyHeight: blackKeyHeight,
                    ),
                    onPointerUp: (_) => _handlePointerEnd(),
                    onPointerCancel: (_) => _handlePointerEnd(),
                    child: SizedBox(
                      key: _pianoAreaKey,
                      width: pianoWidth,
                      height: whiteKeyHeight,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: visibleWhiteNotes
                                .map(
                                  (note) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: _WhiteKey(
                                      note: note,
                                      color: _keyAccent(note.noteName),
                                      width: whiteKeyWidth,
                                      height: whiteKeyHeight,
                                      isHighlighted: _highlightedNote?.noteId == note.noteId,
                                      isPressed: !_isPlayingTeacherSequence &&
                                          _pressedNoteId == note.noteId,
                                      isTeacherDemo: _isTeacherDemoKey(note),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          ..._buildBlackKeyOverlays(
                            visibleWhiteNotes: visibleWhiteNotes,
                            visibleNotes: visibleNotes,
                            whiteKeyWidth: whiteKeyWidth,
                            blackKeyWidth: blackKeyWidth,
                            blackKeyHeight: blackKeyHeight,
                          ),
                        ],
                      ),
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

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _WhiteKey extends StatelessWidget {
  final PianoNote note;
  final Color color;
  final double width;
  final double height;
  final bool isHighlighted;
  final bool isPressed;
  final bool isTeacherDemo;

  const _WhiteKey({
    required this.note,
    required this.color,
    required this.width,
    required this.height,
    required this.isHighlighted,
    required this.isPressed,
    required this.isTeacherDemo,
  });

  @override
  Widget build(BuildContext context) {
    final active = isHighlighted || isPressed || isTeacherDemo;

    return Transform.translate(
      offset: Offset(0, isPressed ? 2 : 0),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        elevation: active ? 6 : 3,
        shadowColor: Colors.black26,
        child: SizedBox(
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isTeacherDemo ? const Color(0xFFD4AF37) : Colors.black26,
                width: isTeacherDemo ? 3 : 1,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              boxShadow: isTeacherDemo
                  ? const [
                      BoxShadow(
                        color: Color(0x55D4AF37),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  active ? Colors.grey.shade100 : Colors.white,
                  active ? color.withOpacity(0.22) : color.withOpacity(0.12),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: active ? color.withOpacity(0.20) : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        note.arabicName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: width >= 80 ? 14 : 12,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        note.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: width >= 80 ? 11 : 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlackKey extends StatelessWidget {
  final PianoNote note;
  final double width;
  final double height;
  final bool isHighlighted;
  final bool isPressed;
  final bool isTeacherDemo;

  const _BlackKey({
    required this.note,
    required this.width,
    required this.height,
    required this.isHighlighted,
    required this.isPressed,
    required this.isTeacherDemo,
  });

  @override
  Widget build(BuildContext context) {
    final active = isHighlighted || isPressed || isTeacherDemo;

    return Transform.translate(
      offset: Offset(0, isPressed ? 5 : 0),
      child: Material(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        elevation: active ? 10 : 6,
        shadowColor: Colors.black54,
        child: SizedBox(
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isTeacherDemo ? const Color(0xFFD4AF37) : Colors.black87,
                width: isTeacherDemo ? 2.5 : 1,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              boxShadow: isTeacherDemo
                  ? const [
                      BoxShadow(
                        color: Color(0x66D4AF37),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: active
                    ? [
                        const Color(0xFF444444),
                        const Color(0xFF111111),
                      ]
                    : [
                        Colors.grey.shade900,
                        Colors.black,
                      ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    note.arabicName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: width >= 50 ? 10 : 8.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note.displayName,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: width >= 50 ? 9 : 7.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
