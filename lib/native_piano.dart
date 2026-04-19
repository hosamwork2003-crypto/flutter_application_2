import 'package:flutter/services.dart';

class NativePiano {
  static const MethodChannel _channel = MethodChannel('native_piano');
  static bool _initialized = false;

  static Future<bool> init(String sf2AssetPath) async {
    final result = await _channel.invokeMethod<bool>('init', {
      'sf2AssetPath': sf2AssetPath,
    });
    _initialized = result ?? false;
    return _initialized;
  }

  static void noteOn(int midi, {int velocity = 127}) {
    if (!_initialized) return;
    _channel.invokeMethod<void>('noteOn', {
      'midi': midi,
      'velocity': velocity,
    });
  }

  static void noteOff(int midi) {
    if (!_initialized) return;
    _channel.invokeMethod<void>('noteOff', {
      'midi': midi,
    });
  }

  static void allNotesOff() {
    if (!_initialized) return;
    _channel.invokeMethod<void>('allNotesOff');
  }

  // 👇 الجديد
  static Future<void> release() async {
    if (!_initialized) return;

    await _channel.invokeMethod<void>('release');
    _initialized = false; // 👈 مهم عشان لما ترجع تاني يعمل init من جديد
  }
}