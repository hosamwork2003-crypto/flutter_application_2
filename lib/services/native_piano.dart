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

  static Future<void> noteOn(int midi, {int velocity = 127}) async {
    if (!_initialized) return;
    await _channel.invokeMethod('noteOn', {
      'midi': midi,
      'velocity': velocity,
    });
  }

  static Future<void> noteOff(int midi) async {
    if (!_initialized) return;
    await _channel.invokeMethod('noteOff', {
      'midi': midi,
    });
  }

  static Future<void> allNotesOff() async {
    if (!_initialized) return;
    await _channel.invokeMethod('allNotesOff');
  }
}