import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playAlarm() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Error playing alarm: $e");
    }
  }

  Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint("Error stopping alarm: $e");
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
