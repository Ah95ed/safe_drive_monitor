import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/services/alarm_controller.dart';
import 'package:safe_drive_monitor/core/services/audio_alarm_service.dart';
import 'package:safe_drive_monitor/core/services/haptic_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';

class FakeAudioAlarmService implements AudioAlarmService {
  int playAlarmCount = 0;
  int stopAlarmCount = 0;
  int playWarningCount = 0;
  int disposeCount = 0;
  bool _playing = false;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> playAlarm() async {
    playAlarmCount++;
    _playing = true;
  }

  @override
  Future<void> stopAlarm() async {
    stopAlarmCount++;
    _playing = false;
  }

  @override
  Future<void> playTechnicalWarning() async {
    playWarningCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _playing = false;
  }
}

class FakeHapticService implements HapticService {
  int startAlarmCount = 0;
  int stopAlarmCount = 0;
  int warningCount = 0;
  int disposeCount = 0;

  @override
  Future<void> startAlarmHaptic() async {
    startAlarmCount++;
  }

  @override
  Future<void> stopAlarmHaptic() async {
    stopAlarmCount++;
  }

  @override
  Future<void> playWarningHaptic() async {
    warningCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

void main() {
  group('AlarmController Unit Tests', () {
    late FakeAudioAlarmService audioService;
    late FakeHapticService hapticService;
    late AlarmController controller;

    setUp(() {
      audioService = FakeAudioAlarmService();
      hapticService = FakeHapticService();
      controller = AlarmController(audioService, hapticService);
    });

    test('Initial state is not playing', () {
      expect(controller.isPlaying, isFalse);
      expect(audioService.playAlarmCount, 0);
      expect(audioService.stopAlarmCount, 0);
    });

    test('Syncing ALARM triggers audio and haptics exactly once', () async {
      await controller.sync(DriverAlertState.alarm);
      expect(controller.isPlaying, isTrue);
      expect(audioService.playAlarmCount, 1);
      expect(hapticService.startAlarmCount, 1);

      // Subsequent ALARM frames while already playing do not re-trigger
      await controller.sync(DriverAlertState.alarm);
      await controller.sync(DriverAlertState.alarm);
      expect(audioService.playAlarmCount, 1);
      expect(hapticService.startAlarmCount, 1);
    });

    test('Transition from ALARM to NORMAL stops audio and haptics exactly once', () async {
      await controller.sync(DriverAlertState.alarm);
      expect(controller.isPlaying, isTrue);

      await controller.sync(DriverAlertState.normal);
      expect(controller.isPlaying, isFalse);
      expect(audioService.stopAlarmCount, 1);
      expect(hapticService.stopAlarmCount, 1);

      // Subsequent NORMAL frames while stopped do not re-stop
      await controller.sync(DriverAlertState.normal);
      await controller.sync(DriverAlertState.normal);
      expect(audioService.stopAlarmCount, 1);
      expect(hapticService.stopAlarmCount, 1);
    });

    test('Transition from ALARM to DROWSY or WATCHING stops loud alarm', () async {
      await controller.sync(DriverAlertState.alarm);
      expect(controller.isPlaying, isTrue);

      await controller.sync(DriverAlertState.drowsy);
      expect(controller.isPlaying, isFalse);
      expect(audioService.stopAlarmCount, 1);

      await controller.sync(DriverAlertState.alarm);
      expect(controller.isPlaying, isTrue);

      await controller.sync(DriverAlertState.watching);
      expect(controller.isPlaying, isFalse);
      expect(audioService.stopAlarmCount, 2);
    });

    test('Explicit stop cancels playback', () async {
      await controller.sync(DriverAlertState.alarm);
      expect(controller.isPlaying, isTrue);

      await controller.stop();
      expect(controller.isPlaying, isFalse);
      expect(audioService.stopAlarmCount, 1);
    });

    test('Explicit stop cancels audio unconditionally even if controller was not in alarm state', () async {
      expect(controller.isPlaying, isFalse);

      await controller.stop();
      expect(controller.isPlaying, isFalse);
      expect(audioService.stopAlarmCount, 1);
    });
  });
}
