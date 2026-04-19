import 'package:flutter/material.dart';
import 'package:flutter_application_1/native_piano.dart';
import '../services/api_client.dart';
import '../services/piano_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

class _BlackKeyPlacement {
  final PianoNote note;
  final double left;

  const _BlackKeyPlacement({
    required this.note,
    required this.left,
  });
}

class KidsPianoGame extends StatefulWidget {
  const KidsPianoGame({super.key});

  @override
  State<KidsPianoGame> createState() => _KidsPianoGameState();
}

class _KidsPianoGameState extends State<KidsPianoGame> {
  final ApiClient _apiClient = ApiClient('http://192.168.1.114:3000');
  late final PianoApi _pianoApi = PianoApi(_apiClient);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _pianoAreaKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  late final List<PianoNote> _allNotes;

  final Map<int, PianoNote> _pointerToNote = <int, PianoNote>{};
  final Set<int> _activePointers = <int>{};
  final Map<int, Offset> _lastPointerPos = <int, Offset>{};
  final Map<int, DateTime> _pointerDownTimes = <int, DateTime>{};
  final Map<int, DateTime> _recentPlayedNotes = <int, DateTime>{};
  final Map<int, DateTime> _noteStartTimes = <int, DateTime>{};
  final Map<int, int> _notePlayStamps = <int, int>{};
  final List<PianoNote> _teacherSequence = <PianoNote>[];
  final List<PianoNote> _childSequence = <PianoNote>[];
  final List<PianoNote> _pendingDownChordNotes = <PianoNote>[];

  late final ValueNotifier<Set<String>> _pressedNoteIdsNotifier;
  late final ValueNotifier<PianoNote?> _currentNoteNotifier;
  late final ValueNotifier<String> _messageNotifier;
  late final ValueNotifier<PianoNote?> _highlightedNoteNotifier;
  late final ValueNotifier<bool> _isPlayingTeacherSequenceNotifier;
  late final ValueNotifier<bool> _hasActiveTouchesNotifier;
  late final ValueNotifier<int> _scoreNotifier;
  late final ValueNotifier<int> _starsNotifier;
  late final ValueNotifier<int> _teacherSequenceLengthNotifier;
  late final ValueNotifier<int> _childSequenceLengthNotifier;
  late final ValueNotifier<int> _gameStateNotifier;
  late final ValueNotifier<String> _playerNameNotifier;

  bool _audioReady = false;
  bool _isWarmingUp = false;
  bool _isDownChordBatchScheduled = false;
  int _visibleKeyCount = 18;
  int _noteStampSeed = 0;
  double _scrollValue = 0.0;

  static const int _defaultVelocity = 127;
  static const int _downChordWindowMs = 28;
  static const int _shortTapMinSoundMs = 320;
  static const int _longPressThresholdMs = 280;
  static const int _longPressTailMs = 480;
  static const String _sf2AssetPath = 'assets/soundfonts/SalC5Light2.sf2';

  @override
@override
void initState() {
  super.initState();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  _allNotes = _buildAvailableNotes();

  _pressedNoteIdsNotifier = ValueNotifier<Set<String>>(<String>{});
  _currentNoteNotifier = ValueNotifier<PianoNote?>(null);
  _messageNotifier = ValueNotifier<String>('بيانو حر: اضغط على أي مفتاح');
  _highlightedNoteNotifier = ValueNotifier<PianoNote?>(null);
  _isPlayingTeacherSequenceNotifier = ValueNotifier<bool>(false);
  _hasActiveTouchesNotifier = ValueNotifier<bool>(false);
  _scoreNotifier = ValueNotifier<int>(0);
  _starsNotifier = ValueNotifier<int>(0);
  _teacherSequenceLengthNotifier = ValueNotifier<int>(0);
  _childSequenceLengthNotifier = ValueNotifier<int>(0);
  _gameStateNotifier = ValueNotifier<int>(0);
  _playerNameNotifier = ValueNotifier<String>('');

  _scrollController.addListener(_syncScrollValue);

  _initMidiEngine();
  _loadPianoProfile();
}

  @override
@override
void dispose() {
  _stopAllActiveNotes();
  NativePiano.release();

  _scrollController.removeListener(_syncScrollValue);
  _scrollController.dispose();
  _pressedNoteIdsNotifier.dispose();
  _currentNoteNotifier.dispose();
  _messageNotifier.dispose();
  _highlightedNoteNotifier.dispose();
  _isPlayingTeacherSequenceNotifier.dispose();
  _hasActiveTouchesNotifier.dispose();
  _scoreNotifier.dispose();
  _starsNotifier.dispose();
  _teacherSequenceLengthNotifier.dispose();
  _childSequenceLengthNotifier.dispose();
  _gameStateNotifier.dispose();
  _playerNameNotifier.dispose();

  SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  super.dispose();
}

  Future<void> _loadPianoProfile() async {
    try {
      final data = await _pianoApi.getState();

      if (!mounted) return;

      _playerNameNotifier.value = (data['player_name'] ?? '').toString();
      _starsNotifier.value = (data['stars'] ?? 0) as int;
      _scoreNotifier.value = (data['score'] ?? 0) as int;
    } catch (e) {
      debugPrint('load piano profile error: $e');
    }
  }

  Future<void> _savePianoProfile() async {
    try {
      await _pianoApi.saveState(
        stars: _starsNotifier.value,
        score: _scoreNotifier.value,
        lastMode: _gameStateNotifier.value,
        teacherSequenceLength: _teacherSequence.length,
      );
    } catch (e) {
      debugPrint('save piano profile error: $e');
    }
  }

  Future<void> _initMidiEngine() async {
    if (_isWarmingUp) return;

    setState(() {
      _isWarmingUp = true;
      _audioReady = false;
    });
    _messageNotifier.value = 'جارٍ تجهيز صوت البيانو...';

    try {
      final ok = await NativePiano.init(_sf2AssetPath);

      if (!mounted) return;

      setState(() {
        _audioReady = ok;
        _isWarmingUp = false;
      });

      _messageNotifier.value =
          ok ? 'بيانو حر: اضغط على أي مفتاح' : 'تعذر تجهيز صوت البيانو';
    } catch (e) {
      debugPrint('Native piano init error: $e');

      if (!mounted) return;

      setState(() {
        _audioReady = false;
        _isWarmingUp = false;
      });
      _messageNotifier.value = 'تعذر تجهيز صوت البيانو';
    }
  }

  List<PianoNote> _buildAvailableNotes() {
    const chromaticOrder = [
      'C',
      'Db',
      'D',
      'Eb',
      'E',
      'F',
      'Gb',
      'G',
      'Ab',
      'A',
      'Bb',
      'B',
    ];
    const blackNames = {'Db', 'Eb', 'Gb', 'Ab', 'Bb'};

    int midi = 21;
    final notes = <PianoNote>[
      PianoNote(
        noteName: 'A',
        octave: 0,
        isBlack: false,
        midiNumber: midi++,
        noteId: 'A0',
      ),
      PianoNote(
        noteName: 'Bb',
        octave: 0,
        isBlack: true,
        midiNumber: midi++,
        noteId: 'Bb0',
      ),
      PianoNote(
        noteName: 'B',
        octave: 0,
        isBlack: false,
        midiNumber: midi++,
        noteId: 'B0',
      ),
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
      PianoNote(
        noteName: 'C',
        octave: 8,
        isBlack: false,
        midiNumber: midi++,
        noteId: 'C8',
      ),
    ]);

    return notes;
  }

  void _syncScrollValue() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final next =
        max <= 0 ? 0.0 : (_scrollController.offset / max).clamp(0.0, 1.0);
    if ((_scrollValue - next).abs() > 0.001 && mounted) {
      setState(() {
        _scrollValue = next;
      });
    }
  }

  void _jumpToScrollFraction(double value) {
    if (!_scrollController.hasClients) return;

    double maxExtent;
    try {
      maxExtent = _scrollController.position.maxScrollExtent;
    } catch (_) {
      return;
    }

    final clamped = value.clamp(0.0, 1.0);
    final target = maxExtent * clamped;
    _scrollController.jumpTo(target);

    if ((_scrollValue - clamped).abs() > 0.001 && mounted) {
      setState(() {
        _scrollValue = clamped;
      });
    }
  }

  void _stepMiniScroll(double direction, double viewportFraction) {
    final step = (1 - viewportFraction) * 0.18;
    _jumpToScrollFraction((_scrollValue + (direction * step)).clamp(0.0, 1.0));
  }

  void _setPressedNote(String noteId, bool pressed) {
    final current = _pressedNoteIdsNotifier.value;
    if (pressed) {
      if (current.contains(noteId)) return;
      _pressedNoteIdsNotifier.value = <String>{...current, noteId};
      return;
    }

    if (!current.contains(noteId)) return;
    final next = <String>{...current}..remove(noteId);
    _pressedNoteIdsNotifier.value = next;
  }

  void _updatePointerActivity() {
    final hasActive = _activePointers.isNotEmpty || _pointerToNote.isNotEmpty;
    if (_hasActiveTouchesNotifier.value != hasActive) {
      _hasActiveTouchesNotifier.value = hasActive;
    }
  }

  void _setCurrentNote(PianoNote? note) {
    if (_currentNoteNotifier.value?.noteId == note?.noteId) return;
    _currentNoteNotifier.value = note;
  }

  void _setHighlightedNote(PianoNote? note) {
    if (_highlightedNoteNotifier.value?.noteId == note?.noteId) return;
    _highlightedNoteNotifier.value = note;
  }

  void _setMessage(String value) {
    if (_messageNotifier.value == value) return;
    _messageNotifier.value = value;
  }

  void _setGameState(int value) {
    if (_gameStateNotifier.value == value) return;
    _gameStateNotifier.value = value;
  }

  void _setTeacherDemo(bool value) {
    if (_isPlayingTeacherSequenceNotifier.value == value) return;
    _isPlayingTeacherSequenceNotifier.value = value;
  }

  void _syncSequenceCounters() {
    if (_teacherSequenceLengthNotifier.value != _teacherSequence.length) {
      _teacherSequenceLengthNotifier.value = _teacherSequence.length;
    }
    if (_childSequenceLengthNotifier.value != _childSequence.length) {
      _childSequenceLengthNotifier.value = _childSequence.length;
    }
  }

  bool _canTriggerNote(PianoNote note, {int retriggerGapMs = 35}) {
    final now = DateTime.now();
    final last = _recentPlayedNotes[note.midiNumber];
    if (last != null && now.difference(last).inMilliseconds < retriggerGapMs) {
      return false;
    }
    return true;
  }

  int _markNoteStarted(PianoNote note) {
    final now = DateTime.now();
    final stamp = ++_noteStampSeed;
    _recentPlayedNotes[note.midiNumber] = now;
    _noteStartTimes[note.midiNumber] = now;
    _notePlayStamps[note.midiNumber] = stamp;
    return stamp;
  }

  void _startLiveNote(
    PianoNote note, {
    int velocity = _defaultVelocity,
    int retriggerGapMs = 35,
  }) {
    if (!_audioReady) return;
    if (!_canTriggerNote(note, retriggerGapMs: retriggerGapMs)) return;

    final safeVelocity = velocity.clamp(1, 127);
    NativePiano.noteOn(note.midiNumber, velocity: safeVelocity);
    _markNoteStarted(note);
  }

  List<PianoNote> _startLiveChordNotes(
    List<PianoNote> notes, {
    int velocity = _defaultVelocity,
    int retriggerGapMs = 35,
  }) {
    if (!_audioReady || notes.isEmpty) return <PianoNote>[];

    final uniqueNotes = <PianoNote>[];
    final seen = <String>{};
    for (final note in notes) {
      if (seen.add(note.noteId)) {
        uniqueNotes.add(note);
      }
    }

    final playable = <PianoNote>[];
    for (final note in uniqueNotes) {
      if (_canTriggerNote(note, retriggerGapMs: retriggerGapMs)) {
        playable.add(note);
      }
    }

    if (playable.isEmpty) return <PianoNote>[];

    final safeVelocity = velocity.clamp(1, 127);
    NativePiano.noteOnMany(
      playable.map((n) => n.midiNumber).toList(),
      velocity: safeVelocity,
    );

    for (final note in playable) {
      _markNoteStarted(note);
    }

    return playable;
  }

  void _scheduleTimedNoteOff(int midiNumber, int stamp, int holdMs) {
    Future.delayed(Duration(milliseconds: holdMs), () {
      final lastStamp = _notePlayStamps[midiNumber];
      if (lastStamp != stamp) return;

      NativePiano.noteOff(midiNumber);
      _notePlayStamps.remove(midiNumber);
      _noteStartTimes.remove(midiNumber);
      _recentPlayedNotes.remove(midiNumber);
    });
  }

  void _performNoteSound(
    PianoNote note, {
    int velocity = _defaultVelocity,
    int holdMs = 320,
    int retriggerGapMs = 35,
  }) {
    if (!_audioReady) return;
    if (!_canTriggerNote(note, retriggerGapMs: retriggerGapMs)) return;

    final safeVelocity = velocity.clamp(1, 127);
    NativePiano.noteOn(note.midiNumber, velocity: safeVelocity);
    final stamp = _markNoteStarted(note);
    _scheduleTimedNoteOff(note.midiNumber, stamp, holdMs);
  }

  void _releaseLiveNoteForPointer(int pointer, PianoNote note) {
    final downAt = _pointerDownTimes[pointer] ?? DateTime.now();
    final startAt = _noteStartTimes[note.midiNumber] ?? downAt;
    final heldMs = DateTime.now().difference(downAt).inMilliseconds;
    final playedMs = DateTime.now().difference(startAt).inMilliseconds;

    final tailMs = heldMs >= _longPressThresholdMs
        ? _longPressTailMs
        : (_shortTapMinSoundMs - playedMs).clamp(0, _shortTapMinSoundMs);

    final stamp = _notePlayStamps[note.midiNumber];
    if (stamp == null) {
      NativePiano.noteOff(note.midiNumber);
      _noteStartTimes.remove(note.midiNumber);
      _recentPlayedNotes.remove(note.midiNumber);
      return;
    }

    Future.delayed(Duration(milliseconds: tailMs), () {
      final lastStamp = _notePlayStamps[note.midiNumber];
      if (lastStamp != stamp) return;

      NativePiano.noteOff(note.midiNumber);
      _notePlayStamps.remove(note.midiNumber);
      _noteStartTimes.remove(note.midiNumber);
      _recentPlayedNotes.remove(note.midiNumber);
    });
  }

  void _queuePointerDownChordNote(PianoNote note) {
    if (!_audioReady || _isWarmingUp) return;

    if (_pendingDownChordNotes.any((n) => n.noteId == note.noteId)) {
      return;
    }

    _pendingDownChordNotes.add(note);

    if (_isDownChordBatchScheduled) return;
    _isDownChordBatchScheduled = true;

    Future.delayed(const Duration(milliseconds: _downChordWindowMs), () {
      final notes = List<PianoNote>.from(_pendingDownChordNotes);
      _pendingDownChordNotes.clear();
      _isDownChordBatchScheduled = false;

      if (notes.isEmpty) return;

      if (notes.length == 1) {
        _performUserNote(notes.first);
        return;
      }

      final playedNotes = _startLiveChordNotes(notes);
      for (final note in playedNotes) {
        _handleModeAfterPerformedNote(note);
      }
    });
  }

  void _stopAllActiveNotes() {
    if (!_audioReady) return;
    NativePiano.allNotesOff();
    _recentPlayedNotes.clear();
    _noteStartTimes.clear();
    _notePlayStamps.clear();
    _pendingDownChordNotes.clear();
    _isDownChordBatchScheduled = false;
  }

  void _handleModeAfterPerformedNote(PianoNote note) {
    if (_isPlayingTeacherSequenceNotifier.value) {
      _setCurrentNote(note);
      return;
    }

    _setCurrentNote(note);

    if (_gameStateNotifier.value == 0) {
      _setMessage('بيانو حر: ${note.arabicName}');
      return;
    }

    if (_gameStateNotifier.value == 1) {
      _teacherSequence.add(note);
      _syncSequenceCounters();
      _setMessage('تم تسجيل ${note.arabicName} في تسلسل المعلّم');
      return;
    }

    if (_teacherSequence.isEmpty) {
      _setMessage('سجّل تسلسل المعلّم أولًا');
      _showSnack('لا يوجد تسلسل محفوظ بعد', Colors.orange);
      return;
    }

    final expectedIndex = _childSequence.length;
    if (expectedIndex >= _teacherSequence.length) {
      _childSequence.clear();
      _syncSequenceCounters();
      return;
    }

    final expectedNote = _teacherSequence[expectedIndex];
    final isCorrect =
        note.noteName == expectedNote.noteName &&
        note.octave == expectedNote.octave;

    if (!isCorrect) {
      _childSequence.clear();
      _syncSequenceCounters();
      _setMessage('خطأ. ابدأ من أول التسلسل');
      _showSnack('خطأ. ابدأ من البداية', Colors.red);
      return;
    }

    final completedSequence =
        (_childSequence.length + 1) == _teacherSequence.length;

    if (completedSequence) {
      final earned = _teacherSequence.length * 10;

      _stopAllActiveNotes();

      _childSequence.clear();
      _syncSequenceCounters();

      _scoreNotifier.value = _scoreNotifier.value + earned;
      _starsNotifier.value = _starsNotifier.value + 1;
      _setGameState(0);

      _teacherSequence.clear();
      _syncSequenceCounters();
      _setHighlightedNote(null);
      _setMessage('أحسنت! انتهى التحدي بنجاح');

      _savePianoProfile();
      _showSnack('ممتاز! +$earned نقطة ⭐', Colors.green);
      return;
    }

    _childSequence.add(note);
    _syncSequenceCounters();
    _setMessage('صحيح! أكمل باقي التسلسل');
    _showSnack('صحيح، أكمل', Colors.green);
  }

  void _performUserNote(PianoNote note) {
    if (!_audioReady || _isWarmingUp) return;
    _startLiveNote(note);
    _handleModeAfterPerformedNote(note);
  }

  Future<void> _playTeacherSequence() async {
    if (_teacherSequence.isEmpty || _isPlayingTeacherSequenceNotifier.value) {
      return;
    }

    final teacherSequenceSnapshot = List<PianoNote>.from(_teacherSequence);

    _stopAllActiveNotes();

    _setTeacherDemo(true);
    _setMessage('استمع لتسلسل المعلّم');
    _setHighlightedNote(null);
    _pressedNoteIdsNotifier.value = <String>{};
    _pointerToNote.clear();
    _activePointers.clear();
    _lastPointerPos.clear();
    _pointerDownTimes.clear();
    _pendingDownChordNotes.clear();
    _isDownChordBatchScheduled = false;
    _updatePointerActivity();

    for (final note in teacherSequenceSnapshot) {
      if (!mounted) return;

      _setHighlightedNote(note);
      _setCurrentNote(note);
      _performNoteSound(note, velocity: 127, holdMs: 320, retriggerGapMs: 0);
      await Future.delayed(const Duration(milliseconds: 380));
    }

    if (!mounted) return;

    _setHighlightedNote(null);
    _setTeacherDemo(false);
    _setMessage(
      _gameStateNotifier.value == 2
          ? 'الآن دور الطفل: كرر نفس التسلسل'
          : 'انتهى تشغيل تسلسل المعلّم',
    );
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
    if (_gameStateNotifier.value == 0) {
      _setGameState(1);
      _teacherSequence.clear();
      _childSequence.clear();
      _syncSequenceCounters();
      _setMessage('وضع تسجيل المعلّم: اضغط النغمات المطلوبة');
      return;
    }

    if (_gameStateNotifier.value == 1) {
      if (_teacherSequence.isEmpty) {
        _setMessage('سجّل نغمة واحدة على الأقل أولًا');
        _showSnack('سجّل تسلسل المعلّم أولًا', Colors.orange);
        return;
      }

      _setGameState(2);
      _childSequence.clear();
      _syncSequenceCounters();
      _setMessage('وضع الطفل: كرر نفس التسلسل');
      return;
    }

    _stopAllActiveNotes();

    _setGameState(0);
    _teacherSequence.clear();
    _childSequence.clear();
    _syncSequenceCounters();
    _setHighlightedNote(null);
    _setCurrentNote(null);
    _setMessage('بيانو حر: اضغط على أي مفتاح');
  }

  String _challengeButtonLabelFor(int gameState) {
    if (gameState == 0) return 'ابدأ تسجيل المعلّم';
    if (gameState == 1) return 'ابدأ دور الطفل';
    return 'إنهاء التحدي';
  }

  IconData _challengeButtonIconFor(int gameState) {
    if (gameState == 0) return Icons.fiber_manual_record;
    if (gameState == 1) return Icons.child_care;
    return Icons.stop_circle_outlined;
  }

  String _modeLabelFor(int gameState) {
    if (gameState == 0) return 'بيانو حر';
    if (gameState == 1) return 'تسجيل المعلّم';
    return 'دور الطفل';
  }

  Color _modeColorFor(int gameState) {
    if (gameState == 0) return Colors.teal;
    if (gameState == 1) return Colors.deepOrange;
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

  Map<String, int> _buildVisibleNoteIndexMap(List<PianoNote> visibleNotes) {
    final map = <String, int>{};
    for (int i = 0; i < visibleNotes.length; i++) {
      map[visibleNotes[i].noteId] = i;
    }
    return map;
  }

  List<_BlackKeyPlacement> _computeBlackKeyPlacements({
    required List<PianoNote> visibleWhiteNotes,
    required List<PianoNote> visibleNotes,
    required Map<String, int> visibleNoteIndexMap,
    required double whiteKeyWidth,
    required double blackKeyWidth,
  }) {
    final placements = <_BlackKeyPlacement>[];

    final baseWidth =
        (visibleWhiteNotes.length * whiteKeyWidth) +
        ((visibleWhiteNotes.length - 1) * 4);

    for (int whiteIndex = 0;
        whiteIndex < visibleWhiteNotes.length;
        whiteIndex++) {
      final whiteNote = visibleWhiteNotes[whiteIndex];

      if (whiteNote.noteName == 'E' || whiteNote.noteName == 'B') {
        continue;
      }

      final currentIndex = visibleNoteIndexMap[whiteNote.noteId];
      if (currentIndex == null) continue;

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

      double left = (whiteIndex * (whiteKeyWidth + 4)) +
          whiteKeyWidth -
          (blackKeyWidth / 2);

      final maxLeft = baseWidth - blackKeyWidth;
      if (left > maxLeft) {
        left = maxLeft;
      }

      placements.add(_BlackKeyPlacement(note: blackAfter, left: left));
    }

    return placements;
  }

  PianoNote? _findNoteAtPosition({
    required Offset globalPosition,
    required List<PianoNote> visibleWhiteNotes,
    required List<_BlackKeyPlacement> blackPlacements,
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

    for (final placement in blackPlacements) {
      if (x >= placement.left &&
          x <= placement.left + blackKeyWidth &&
          y >= 0 &&
          y <= blackKeyHeight) {
        return placement.note;
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
    required List<PianoNote> visibleWhiteNotes,
    required List<_BlackKeyPlacement> blackPlacements,
    required double whiteKeyWidth,
    required double whiteKeyHeight,
    required double blackKeyWidth,
    required double blackKeyHeight,
  }) {
    _activePointers.add(event.pointer);
    _lastPointerPos[event.pointer] = event.position;
    _pointerDownTimes[event.pointer] = DateTime.now();
    _updatePointerActivity();

    final note = _findNoteAtPosition(
      globalPosition: event.position,
      visibleWhiteNotes: visibleWhiteNotes,
      blackPlacements: blackPlacements,
      whiteKeyWidth: whiteKeyWidth,
      whiteKeyHeight: whiteKeyHeight,
      blackKeyWidth: blackKeyWidth,
      blackKeyHeight: blackKeyHeight,
    );

    if (note == null) return;
    if (_pointerToNote.containsKey(event.pointer)) return;

    _pointerToNote[event.pointer] = note;
    _setPressedNote(note.noteId, true);
    _queuePointerDownChordNote(note);
  }

  void _handlePointerMove({
    required PointerMoveEvent event,
    required List<PianoNote> visibleWhiteNotes,
    required List<_BlackKeyPlacement> blackPlacements,
    required double whiteKeyWidth,
    required double whiteKeyHeight,
    required double blackKeyWidth,
    required double blackKeyHeight,
  }) {
    final lastPos = _lastPointerPos[event.pointer];
    if (lastPos == null) {
      _lastPointerPos[event.pointer] = event.position;
      return;
    }

    final distance = (event.position - lastPos).distance;
    final steps = (distance / 12).ceil().clamp(1, 24);

    for (int i = 1; i <= steps; i++) {
      final t = i / steps;

      final interpolated = Offset(
        lastPos.dx + (event.position.dx - lastPos.dx) * t,
        lastPos.dy + (event.position.dy - lastPos.dy) * t,
      );

      final note = _findNoteAtPosition(
        globalPosition: interpolated,
        visibleWhiteNotes: visibleWhiteNotes,
        blackPlacements: blackPlacements,
        whiteKeyWidth: whiteKeyWidth,
        whiteKeyHeight: whiteKeyHeight,
        blackKeyWidth: blackKeyWidth,
        blackKeyHeight: blackKeyHeight,
      );

      final prev = _pointerToNote[event.pointer];

      if (prev != null && note == null) {
        _setPressedNote(prev.noteId, false);
        _releaseLiveNoteForPointer(event.pointer, prev);
        _pointerToNote.remove(event.pointer);
        _updatePointerActivity();
        break;
      }

      if (note != null) {
        if (prev?.noteId == note.noteId) {
          continue;
        }

        if (prev != null) {
          _setPressedNote(prev.noteId, false);
          _releaseLiveNoteForPointer(event.pointer, prev);
        }

        _pointerToNote[event.pointer] = note;
        _pointerDownTimes[event.pointer] = DateTime.now();
        _updatePointerActivity();
        _setPressedNote(note.noteId, true);
        _performUserNote(note);
      }
    }

    _lastPointerPos[event.pointer] = event.position;
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);

    final note = _pointerToNote.remove(event.pointer);

    if (note != null) {
      _setPressedNote(note.noteId, false);
      _releaseLiveNoteForPointer(event.pointer, note);
    }

    _pointerDownTimes.remove(event.pointer);
    _lastPointerPos.remove(event.pointer);
    _updatePointerActivity();

    if (_pointerToNote.isEmpty) {
      _setCurrentNote(null);
    }
  }

  void _resetGame() {
    _stopAllActiveNotes();
    _activePointers.clear();
    _pointerToNote.clear();
    _lastPointerPos.clear();
    _pointerDownTimes.clear();
    _pressedNoteIdsNotifier.value = <String>{};
    _pendingDownChordNotes.clear();
    _isDownChordBatchScheduled = false;
    _updatePointerActivity();
    _scoreNotifier.value = 0;
    _starsNotifier.value = 0;
    _teacherSequence.clear();
    _childSequence.clear();
    _syncSequenceCounters();
    _setGameState(0);
    _setHighlightedNote(null);
    _setCurrentNote(null);
    _setMessage('تمت إعادة التعيين');
    _savePianoProfile();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final clampedVisibleCount = _visibleKeyCount.clamp(7, 52);

    final zoom = 30 / clampedVisibleCount;
    final whiteKeyWidth = (48 * zoom).clamp(42.0, 92.0);
    final blackKeyWidth = (30 * zoom).clamp(24.0, 58.0);

    final whiteKeyHeight = screenHeight * 0.5;
    final blackKeyHeight = whiteKeyHeight * 0.62;

    final visibleNotes = _allNotes;
    final visibleWhiteNotes = visibleNotes.where((n) => !n.isBlack).toList();
    final visibleNoteIndexMap = _buildVisibleNoteIndexMap(visibleNotes);
    final blackPlacements = _computeBlackKeyPlacements(
      visibleWhiteNotes: visibleWhiteNotes,
      visibleNotes: visibleNotes,
      visibleNoteIndexMap: visibleNoteIndexMap,
      whiteKeyWidth: whiteKeyWidth,
      blackKeyWidth: blackKeyWidth,
    );

    final pianoWidth =
        (visibleWhiteNotes.length * whiteKeyWidth) +
        ((visibleWhiteNotes.length - 1) * 4) +
        blackKeyWidth;
    final availablePianoViewportWidth =
        (MediaQuery.of(context).size.width - 24).clamp(1.0, double.infinity);
    final miniViewportFraction =
        (availablePianoViewportWidth / pianoWidth).clamp(0.08, 1.0);

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
                child: ValueListenableBuilder<String>(
                  valueListenable: _playerNameNotifier,
                  builder: (context, playerName, _) {
                    return Column(
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
                          'اسم اللاعب: $playerName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: _playerNameNotifier,
                builder: (context, playerName, _) {
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('اسم اللاعب'),
                    subtitle: Text(
                      playerName.isEmpty ? 'جارٍ تحميل الاسم...' : playerName,
                    ),
                  );
                },
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('تفاصيل اللعبة'),
                subtitle: Text(
                  'بيانو حر أولًا، ثم تسجيل المعلّم، ثم تنفيذ الطفل',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.settings),
                title: Text('الإعدادات'),
                subtitle: Text('التحكم في تكبير وتصغير المفاتيح'),
              ),
              const Divider(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تكبير وتصغير المفاتيح',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _visibleKeyCount =
                                  (_visibleKeyCount - 3).clamp(7, 52);
                            });
                          },
                          icon: const Icon(Icons.remove_circle, size: 32),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$_visibleKeyCount',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _visibleKeyCount =
                                  (_visibleKeyCount + 3).clamp(7, 52);
                            });
                          },
                          icon: const Icon(Icons.add_circle, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الحد الأقصى 52 مفتاحًا أبيض، وعندها يظهر البيانو الكامل بمفاتيحه البيضاء والسوداء.',
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
            _TopStatusPanel(
              currentNoteListenable: _currentNoteNotifier,
              messageListenable: _messageNotifier,
              scoreListenable: _scoreNotifier,
              starsListenable: _starsNotifier,
              teacherSequenceLengthListenable: _teacherSequenceLengthNotifier,
              childSequenceLengthListenable: _childSequenceLengthNotifier,
              gameStateListenable: _gameStateNotifier,
              playerNameListenable: _playerNameNotifier,
              audioReady: _audioReady,
              isPlayingTeacherSequenceListenable:
                  _isPlayingTeacherSequenceNotifier,
              modeLabelBuilder: _modeLabelFor,
              modeColorBuilder: _modeColorFor,
              challengeButtonLabelBuilder: _challengeButtonLabelFor,
              challengeButtonIconBuilder: _challengeButtonIconFor,
              onAdvanceChallengeState: _advanceChallengeState,
              onPlayTeacherSequence: _playTeacherSequence,
              onReset: _resetGame,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: IgnorePointer(
                  ignoring: !_audioReady || _isWarmingUp,
                  child: Listener(
                    onPointerDown: (event) => _handlePointerDown(
                      event: event,
                      visibleWhiteNotes: visibleWhiteNotes,
                      blackPlacements: blackPlacements,
                      whiteKeyWidth: whiteKeyWidth,
                      whiteKeyHeight: whiteKeyHeight,
                      blackKeyWidth: blackKeyWidth,
                      blackKeyHeight: blackKeyHeight,
                    ),
                    onPointerMove: (event) => _handlePointerMove(
                      event: event,
                      visibleWhiteNotes: visibleWhiteNotes,
                      blackPlacements: blackPlacements,
                      whiteKeyWidth: whiteKeyWidth,
                      whiteKeyHeight: whiteKeyHeight,
                      blackKeyWidth: blackKeyWidth,
                      blackKeyHeight: blackKeyHeight,
                    ),
                    onPointerUp: _handlePointerEnd,
                    onPointerCancel: _handlePointerEnd,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: RepaintBoundary(
                                      child: _WhiteKey(
                                        note: note,
                                        color: _keyAccent(note.noteName),
                                        width: whiteKeyWidth,
                                        height: whiteKeyHeight,
                                        highlightedNoteListenable:
                                            _highlightedNoteNotifier,
                                        isPlayingTeacherSequenceListenable:
                                            _isPlayingTeacherSequenceNotifier,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          ...blackPlacements.map(
                            (placement) => Positioned(
                              left: placement.left,
                              top: 0,
                              child: RepaintBoundary(
                                child: _BlackKey(
                                  note: placement.note,
                                  width: blackKeyWidth,
                                  height: blackKeyHeight,
                                  highlightedNoteListenable:
                                      _highlightedNoteNotifier,
                                  isPlayingTeacherSequenceListenable:
                                      _isPlayingTeacherSequenceNotifier,
                                ),
                              ),
                            ),
                          ),
                          _PressedOverlayLayer(
                            pressedNoteIdsListenable: _pressedNoteIdsNotifier,
                            visibleWhiteNotes: visibleWhiteNotes,
                            blackPlacements: blackPlacements,
                            whiteKeyWidth: whiteKeyWidth,
                            whiteKeyHeight: whiteKeyHeight,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _MiniKeyboardNavigator(
                scrollValue: _scrollValue,
                viewportFraction: miniViewportFraction,
                onChanged: _jumpToScrollFraction,
                onStepLeft: () => _stepMiniScroll(-1, miniViewportFraction),
                onStepRight: () => _stepMiniScroll(1, miniViewportFraction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopStatusPanel extends StatelessWidget {
  final ValueListenable<PianoNote?> currentNoteListenable;
  final ValueListenable<String> messageListenable;
  final ValueListenable<int> scoreListenable;
  final ValueListenable<int> starsListenable;
  final ValueListenable<int> teacherSequenceLengthListenable;
  final ValueListenable<int> childSequenceLengthListenable;
  final ValueListenable<int> gameStateListenable;
  final ValueListenable<String> playerNameListenable;
  final ValueListenable<bool> isPlayingTeacherSequenceListenable;
  final bool audioReady;
  final String Function(int) modeLabelBuilder;
  final Color Function(int) modeColorBuilder;
  final String Function(int) challengeButtonLabelBuilder;
  final IconData Function(int) challengeButtonIconBuilder;
  final VoidCallback onAdvanceChallengeState;
  final VoidCallback? onPlayTeacherSequence;
  final VoidCallback onReset;

  const _TopStatusPanel({
    required this.currentNoteListenable,
    required this.messageListenable,
    required this.scoreListenable,
    required this.starsListenable,
    required this.teacherSequenceLengthListenable,
    required this.childSequenceLengthListenable,
    required this.gameStateListenable,
    required this.playerNameListenable,
    required this.audioReady,
    required this.isPlayingTeacherSequenceListenable,
    required this.modeLabelBuilder,
    required this.modeColorBuilder,
    required this.challengeButtonLabelBuilder,
    required this.challengeButtonIconBuilder,
    required this.onAdvanceChallengeState,
    required this.onPlayTeacherSequence,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final merged = Listenable.merge([
      currentNoteListenable,
      messageListenable,
      scoreListenable,
      starsListenable,
      teacherSequenceLengthListenable,
      childSequenceLengthListenable,
      gameStateListenable,
      playerNameListenable,
      isPlayingTeacherSequenceListenable,
    ]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: AnimatedBuilder(
        animation: merged,
        builder: (context, _) {
          final currentNote = currentNoteListenable.value;
          final message = messageListenable.value;
          final score = scoreListenable.value;
          final stars = starsListenable.value;
          final teacherLength = teacherSequenceLengthListenable.value;
          final childLength = childSequenceLengthListenable.value;
          final gameState = gameStateListenable.value;
          final playerName = playerNameListenable.value;
          final isPlayingTeacherSequence =
              isPlayingTeacherSequenceListenable.value;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  currentNote?.arabicName ?? 'بيانو حر: اضغط على أي مفتاح',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      label: modeLabelBuilder(gameState),
                      color: modeColorBuilder(gameState),
                    ),
                    _InfoChip(label: 'النقاط: $score', color: Colors.orange),
                    _InfoChip(label: 'النجوم: $stars', color: Colors.amber),
                    _InfoChip(
                      label: 'تسلسل المعلّم: $teacherLength',
                      color: Colors.blue,
                    ),
                    _InfoChip(
                      label: 'ما أدخله الطفل: $childLength',
                      color: Colors.pink,
                    ),
                    _InfoChip(
                      label: 'اللاعب: $playerName',
                      color: Colors.indigo,
                    ),
                    _InfoChip(
                      label: audioReady ? 'الصوت جاهز' : 'جارٍ تجهيز الصوت',
                      color: audioReady ? Colors.green : Colors.redAccent,
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
                      onPressed: onAdvanceChallengeState,
                      icon: Icon(challengeButtonIconBuilder(gameState)),
                      label: Text(challengeButtonLabelBuilder(gameState)),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          (isPlayingTeacherSequence ||
                                  teacherLength == 0 ||
                                  gameState != 2)
                              ? null
                              : onPlayTeacherSequence,
                      icon: const Icon(Icons.volume_up),
                      label: const Text('اسمع تسلسل المعلّم'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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

class _PressedOverlayLayer extends StatelessWidget {
  final ValueListenable<Set<String>> pressedNoteIdsListenable;
  final List<PianoNote> visibleWhiteNotes;
  final List<_BlackKeyPlacement> blackPlacements;
  final double whiteKeyWidth;
  final double whiteKeyHeight;
  final double blackKeyWidth;
  final double blackKeyHeight;

  const _PressedOverlayLayer({
    required this.pressedNoteIdsListenable,
    required this.visibleWhiteNotes,
    required this.blackPlacements,
    required this.whiteKeyWidth,
    required this.whiteKeyHeight,
    required this.blackKeyWidth,
    required this.blackKeyHeight,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: pressedNoteIdsListenable,
        builder: (context, pressed, _) {
          return Stack(
            children: [
              ...List.generate(visibleWhiteNotes.length, (i) {
                final note = visibleWhiteNotes[i];
                if (!pressed.contains(note.noteId)) {
                  return const SizedBox.shrink();
                }

                final left = i * (whiteKeyWidth + 4);

                return Positioned(
                  left: left,
                  top: 0,
                  child: Transform.translate(
                    offset: const Offset(0, 2),
                    child: Container(
                      width: whiteKeyWidth,
                      height: whiteKeyHeight,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ),
                  ),
                );
              }),
              ...blackPlacements.map((placement) {
                if (!pressed.contains(placement.note.noteId)) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  left: placement.left,
                  top: 0,
                  child: Transform.translate(
                    offset: const Offset(0, 5),
                    child: Container(
                      width: blackKeyWidth,
                      height: blackKeyHeight,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}


class _MiniKeyboardNavigator extends StatelessWidget {
  final double scrollValue;
  final double viewportFraction;
  final ValueChanged<double> onChanged;
  final VoidCallback onStepLeft;
  final VoidCallback onStepRight;

  const _MiniKeyboardNavigator({
    required this.scrollValue,
    required this.viewportFraction,
    required this.onChanged,
    required this.onStepLeft,
    required this.onStepRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _MiniNavButton(
            icon: Icons.chevron_left,
            onTap: onStepLeft,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                final thumbWidth = (trackWidth * viewportFraction)
                    .clamp(26.0, trackWidth)
                    .toDouble();
                final left = trackWidth <= thumbWidth
                    ? 0.0
                    : (trackWidth - thumbWidth) * scrollValue;

                double fractionFromDx(double dx) {
                  if (trackWidth <= thumbWidth) return 0.0;
                  final next = (dx - (thumbWidth / 2)) / (trackWidth - thumbWidth);
                  return next.clamp(0.0, 1.0);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => onChanged(fractionFromDx(details.localPosition.dx)),
                  onHorizontalDragUpdate: (details) =>
                      onChanged(fractionFromDx(details.localPosition.dx)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MiniKeyboardStripPainter(),
                        ),
                      ),
                      Positioned(
                        left: left,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: thumbWidth,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.blueAccent.withOpacity(0.14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.95),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.white24,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          _MiniNavButton(
            icon: Icons.chevron_right,
            onTap: onStepRight,
          ),
        ],
      ),
    );
  }
}

class _MiniNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniNavButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _MiniKeyboardStripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final clipPath = Path()..addRRect(rrect);
    canvas.save();
    canvas.clipPath(clipPath);

    final bgPaint = Paint()..color = const Color(0xFF2A2A2A);
    canvas.drawRRect(rrect, bgPaint);

    const totalWhiteKeys = 52;
    final whiteKeyWidth = size.width / totalWhiteKeys;
    final whitePaint = Paint()..color = const Color(0xFFF4F4F1);
    final whiteLinePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 0.7;

    for (int i = 0; i < totalWhiteKeys; i++) {
      final left = i * whiteKeyWidth;
      final rect = Rect.fromLTWH(left, 0, whiteKeyWidth, size.height);
      canvas.drawRect(rect, whitePaint);
      canvas.drawLine(
        Offset(left, 0),
        Offset(left, size.height),
        whiteLinePaint,
      );
    }
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      whiteLinePaint,
    );

    final blackPaint = Paint()..color = Colors.black;
    const pattern = [true, true, false, true, true, true, false];
    final blackWidth = whiteKeyWidth * 0.62;
    final blackHeight = size.height * 0.58;

    for (int i = 0; i < totalWhiteKeys - 1; i++) {
      if (!pattern[i % 7]) continue;
      final left = ((i + 1) * whiteKeyWidth) - (blackWidth / 2);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, blackWidth, blackHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, blackPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WhiteKey extends StatelessWidget {
  final PianoNote note;
  final Color color;
  final double width;
  final double height;
  final ValueListenable<PianoNote?> highlightedNoteListenable;
  final ValueListenable<bool> isPlayingTeacherSequenceListenable;

  const _WhiteKey({
    required this.note,
    required this.color,
    required this.width,
    required this.height,
    required this.highlightedNoteListenable,
    required this.isPlayingTeacherSequenceListenable,
  });

  @override
  Widget build(BuildContext context) {
    final merged = Listenable.merge([
      highlightedNoteListenable,
      isPlayingTeacherSequenceListenable,
    ]);

    return AnimatedBuilder(
      animation: merged,
      builder: (context, _) {
        final isTeacherDemo =
            isPlayingTeacherSequenceListenable.value &&
            highlightedNoteListenable.value?.noteId == note.noteId;
        final isHighlighted =
            highlightedNoteListenable.value?.noteId == note.noteId;

        final active = isHighlighted || isTeacherDemo;

        return SizedBox(
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isTeacherDemo
                    ? const Color(0xFFD4AF37)
                    : Colors.black26,
                width: isTeacherDemo ? 3 : 1,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  active ? Colors.grey.shade100 : Colors.white,
                  active
                      ? color.withOpacity(0.22)
                      : color.withOpacity(0.12),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? color.withOpacity(0.20)
                        : color.withOpacity(0.12),
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
        );
      },
    );
  }
}

class _BlackKey extends StatelessWidget {
  final PianoNote note;
  final double width;
  final double height;
  final ValueListenable<PianoNote?> highlightedNoteListenable;
  final ValueListenable<bool> isPlayingTeacherSequenceListenable;

  const _BlackKey({
    required this.note,
    required this.width,
    required this.height,
    required this.highlightedNoteListenable,
    required this.isPlayingTeacherSequenceListenable,
  });

  @override
  Widget build(BuildContext context) {
    final merged = Listenable.merge([
      highlightedNoteListenable,
      isPlayingTeacherSequenceListenable,
    ]);

    return AnimatedBuilder(
      animation: merged,
      builder: (context, _) {
        final isTeacherDemo =
            isPlayingTeacherSequenceListenable.value &&
            highlightedNoteListenable.value?.noteId == note.noteId;
        final isHighlighted =
            highlightedNoteListenable.value?.noteId == note.noteId;

        final active = isHighlighted || isTeacherDemo;

        return SizedBox(
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isTeacherDemo
                    ? const Color(0xFFD4AF37)
                    : Colors.black87,
                width: isTeacherDemo ? 2.5 : 1,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: active
                    ? const [
                        Color(0xFF444444),
                        Color(0xFF111111),
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
        );
      },
    );
  }
}
