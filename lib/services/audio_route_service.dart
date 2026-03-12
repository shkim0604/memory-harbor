import 'package:flutter/services.dart';

class AudioRouteService {
  AudioRouteService._();
  static final AudioRouteService instance = AudioRouteService._();

  static const MethodChannel _channel = MethodChannel(
    'memory_harbor/audio_route',
  );

  Future<bool> hasExternalAudioOutput() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasExternalAudioOutput');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
