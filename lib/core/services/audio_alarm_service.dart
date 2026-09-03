import 'package:audioplayers/audioplayers.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

abstract class AudioAlarmService {
  Future<void> playAlarm();
  Future<void> playTechnicalWarning();
  Future<void> stopAlarm();
  Future<void> dispose();
  bool get isPlaying;
}

class AppAudioAlarmService implements AudioAlarmService {
  static const String _tag = 'AudioAlarmService';
  final AudioPlayer _player;
  bool _isPlaying = false;
  bool _contextConfigured = false;

  AppAudioAlarmService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  @override
  bool get isPlaying => _isPlaying;

  Future<void> _configureAudioContext() async {
    if (_contextConfigured) return;
    try {
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
      _contextConfigured = true;
    } catch (e) {
      AppLogger.warning(_tag, 'Could not configure audio focus context: $e');
    }
  }

  @override
  Future<void> playAlarm() async {
    if (_isPlaying) {
      return;
    }
    try {
      _isPlaying = true;
      await _configureAudioContext();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource(AppConstants.alarmSoundAsset));
      AppLogger.info(_tag, 'Alarm audio started playing (looping with AudioFocus ducking).');
    } catch (e, st) {
      _isPlaying = false;
      AppLogger.error(_tag, 'Failed to play alarm audio', e, st);
    }
  }

  @override
  Future<void> playTechnicalWarning() async {
    try {
      await _configureAudioContext();
      // Plays once at moderate volume (distinct from screaming continuous drowsiness alarm)
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(0.65);
      await _player.play(AssetSource(AppConstants.technicalWarningSoundAsset));
      AppLogger.info(_tag, 'Technical warning tone triggered.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to play technical warning tone', e, st);
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
