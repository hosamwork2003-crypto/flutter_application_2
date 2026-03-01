import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoControlsWithMarks extends StatefulWidget {
  final List<Duration> marks;

  // ✅ عشان نعرف المستخدم بدأ/خلص سحب
  final ValueChanged<Duration>? onScrubStart;
  final ValueChanged<Duration>? onScrubEnd;

  // ✅ قفل التشغيل لو في سؤال لازم يتحل
  final bool blocked;
  final VoidCallback? onBlockedTap;

  const VideoControlsWithMarks({
    super.key,
    required this.marks,
    this.onScrubStart,
    this.onScrubEnd,
    this.blocked = false,
    this.onBlockedTap,
  });

  @override
  State<VideoControlsWithMarks> createState() => _VideoControlsWithMarksState();
}

class _VideoControlsWithMarksState extends State<VideoControlsWithMarks> {
  bool _show = true;
  Timer? _hideTimer;

  ChewieController get _chewie => ChewieController.of(context);
  VideoPlayerController get _video => _chewie.videoPlayerController;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_video.value.isPlaying) setState(() => _show = false);
    });
  }

  void _toggleControls() {
    setState(() => _show = !_show);
    if (_show) _startHideTimer();
  }

  Future<void> _togglePlay() async {
    if (widget.blocked) {
      widget.onBlockedTap?.call();
      setState(() => _show = true);
      return;
    }

    if (_video.value.isPlaying) {
      await _video.pause();
      setState(() => _show = true);
    } else {
      await _video.play();
      _startHideTimer();
    }
    if (mounted) setState(() {});
  }

  Future<void> _seekRelative(int seconds) async {
    if (widget.blocked) {
      widget.onBlockedTap?.call();
      setState(() => _show = true);
      return;
    }

    final pos = _video.value.position;
    final dur = _video.value.duration;

    Duration target = pos + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (dur.inMilliseconds > 0 && target > dur) target = dur;

    await _video.seekTo(target);
    if (_video.value.isPlaying) _startHideTimer();
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return "${two(h)}:${two(m)}:${two(s)}";
    return "${two(m)}:${two(s)}";
  }

  @override
  Widget build(BuildContext context) {
    final v = _video.value;
    final hasDur = v.duration.inMilliseconds > 0;

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              child: const SizedBox.expand(),
            ),
          ),

          // ✅ زرار Play/Pause في النص
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_show,
              child: AnimatedOpacity(
                opacity: _show ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(
                        v.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              ignoring: !_show,
              child: AnimatedOpacity(
                opacity: _show ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    border: const Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ProgressWithMarks(
                        video: _video,
                        marks: widget.marks,
                        onScrubStart: () {
                          widget.onScrubStart?.call(_video.value.position);
                          _hideTimer?.cancel();
                          setState(() => _show = true);
                        },
                        onScrubEnd: () {
                          widget.onScrubEnd?.call(_video.value.position);
                          if (_video.value.isPlaying) _startHideTimer();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            hasDur ? "${_fmt(v.position)} / ${_fmt(v.duration)}" : _fmt(v.position),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: "رجوع 10 ثواني",
                            onPressed: () => _seekRelative(-10),
                            icon: const Icon(Icons.replay_10, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: v.isPlaying ? "Pause" : "Play",
                            onPressed: _togglePlay,
                            icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: "تقديم 10 ثواني",
                            onPressed: () => _seekRelative(10),
                            icon: const Icon(Icons.forward_10, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: "Fullscreen",
                            onPressed: () => _chewie.enterFullScreen(),
                            icon: const Icon(Icons.fullscreen, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ✅ لو blocked: Overlay بسيط يوضح إن لازم سؤال يتحل
          if (widget.blocked)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withOpacity(0.06),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressWithMarks extends StatelessWidget {
  final VideoPlayerController video;
  final List<Duration> marks;
  final VoidCallback onScrubStart;
  final VoidCallback onScrubEnd;

  const _ProgressWithMarks({
    required this.video,
    required this.marks,
    required this.onScrubStart,
    required this.onScrubEnd,
  });

  @override
  Widget build(BuildContext context) {
    final dur = video.value.duration;
    final hasDur = dur.inMilliseconds > 0;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 18,
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  onPointerDown: (_) => onScrubStart(),
                  onPointerUp: (_) => onScrubEnd(),
                  child: VideoProgressIndicator(
                    video,
                    allowScrubbing: true,
                    padding: EdgeInsets.zero,
                    colors: VideoProgressColors(
                      playedColor: Colors.redAccent,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
              ),
              if (hasDur)
                ...marks.map((m) {
                  final frac = (m.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
                  final left = (w * frac) - 1;
                  return Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}