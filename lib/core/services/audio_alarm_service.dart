import 'package:audioplayers/audioplayers.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

abstract class AudioAlarmService {
  Future<void> playAlarm();
  Future<void> stopAlarm();
  Future<void> dispose();
  bool get isPlaying;
}

class AppAudioAlarmService implements AudioAlarmService {
  static const String _tag = 'AudioAlarmService';
  final AudioPlayer _player;
  bool _isPlaying = false;

  AppAudioAlarmService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<void> playAlarm() async {
    if (_isPlaying) {
      return;
    }
    try {
      _isPlaying = true;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource(AppConstants.alarmSoundAsset));
      AppLogger.info(_tag, 'Alarm audio started playing (looping).');
    } catch (e, st) {
      _isPlaying = false;
      AppLogger.error(_tag, 'Failed to play alarm audio', e, st);
    }
  }

  @override
  Future<void> stopAlarm() async {
    if (!_isPlaying) {
      return;
    }
    try {
      _isPlaying = false;
      await _player.stop();
      AppLogger.info(_tag, 'Alarm audio stopped.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to stop alarm audio', e, st);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _isPlaying = false;
      await _player.stop();
      await _player.dispose();
      AppLogger.info(_tag, 'Audio service disposed.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Error disposing audio player', e, st);
    }
  }
}
