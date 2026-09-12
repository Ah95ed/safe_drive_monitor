import 'dart:async';
import 'package:flutter/services.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

/// Device thermal state corresponding to Android PowerManager.THERMAL_STATUS_*
enum DeviceThermalState {
  none(0, 'عادي (Normal)', false),
  light(1, 'حرارة طفيفة (Light)', false),
  moderate(2, 'حرارة متوسطة (Moderate)', true),
  severe(3, 'حرارة شديدة (Severe)', true),
  critical(4, 'حرارة حرجة (Critical)', true),
  emergency(5, 'طوارئ حرارية (Emergency)', true),
  shutdown(6, 'إغلاق وقائي (Shutdown)', true);

  final int rawValue;
  final String arabicLabel;
  final bool isThermalPressure;

  const DeviceThermalState(this.rawValue, this.arabicLabel, this.isThermalPressure);

  static DeviceThermalState fromRawValue(int value) {
    switch (value) {
      case 1:
        return DeviceThermalState.light;
      case 2:
        return DeviceThermalState.moderate;
      case 3:
        return DeviceThermalState.severe;
      case 4:
        return DeviceThermalState.critical;
      case 5:
        return DeviceThermalState.emergency;
      case 6:
        return DeviceThermalState.shutdown;
      case 0:
      default:
        return DeviceThermalState.none;
    }
  }
}

abstract class ThermalManagerService {
  DeviceThermalState get currentState;
  double? get lastThermalHeadroom;
  DateTime? get lastCheckedAt;

  Future<DeviceThermalState> checkThermalStatus();
  Future<double?> checkThermalHeadroom({int forecastSeconds = 10});
  void startMonitoring({Duration interval = const Duration(seconds: 15), void Function(DeviceThermalState state)? onThermalStateChanged});
  void stopMonitoring();
  void dispose();
}

class AppThermalManagerService implements ThermalManagerService {
  static const String _tag = 'ThermalManager';
  static const MethodChannel _channel =
      MethodChannel('com.eyewatchdriver.eye.safe_drive_monitor/foreground_service');

  DeviceThermalState _currentState = DeviceThermalState.none;
  double? _lastThermalHeadroom;
  DateTime? _lastCheckedAt;
  Timer? _pollingTimer;
  void Function(DeviceThermalState state)? _onThermalStateChanged;

  @override
  DeviceThermalState get currentState => _currentState;

  @override
  double? get lastThermalHeadroom => _lastThermalHeadroom;

  @override
  DateTime? get lastCheckedAt => _lastCheckedAt;

  @override
  Future<DeviceThermalState> checkThermalStatus() async {
    try {
      final int? statusInt = await _channel.invokeMethod<int>('getThermalStatus');
      final newState = DeviceThermalState.fromRawValue(statusInt ?? 0);
      final previousState = _currentState;
      _currentState = newState;
      _lastCheckedAt = DateTime.now();

      if (newState != previousState) {
        AppLogger.info(_tag, 'Device thermal state shifted: ${previousState.name} -> ${newState.name} (${newState.arabicLabel})');
        _onThermalStateChanged?.call(newState);
      }
      return _currentState;
    } on MissingPluginException {
      // Fallback for non-Android / widget tests
      _currentState = DeviceThermalState.none;
      return _currentState;
    } catch (e) {
      AppLogger.warning(_tag, 'Thermal status check error: $e');
      return _currentState;
    }
  }

  @override
  Future<double?> checkThermalHeadroom({int forecastSeconds = 10}) async {
    try {
      final double? headroom = await _channel.invokeMethod<double>(
        'getThermalHeadroom',
        {'forecastSeconds': forecastSeconds},
      );
      if (headroom != null && headroom >= 0.0) {
        _lastThermalHeadroom = headroom;
        return headroom;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  void startMonitoring({
    Duration interval = const Duration(seconds: 15),
    void Function(DeviceThermalState state)? onThermalStateChanged,
  }) {
    stopMonitoring();
    _onThermalStateChanged = onThermalStateChanged;

    // Check once initially
    checkThermalStatus();

    _pollingTimer = Timer.periodic(interval, (_) async {
      await checkThermalStatus();
    });
    AppLogger.info(_tag, 'Thermal monitoring started (interval: ${interval.inSeconds}s)');
  }

  @override
  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _onThermalStateChanged = null;
  }

  @override
  void dispose() {
    stopMonitoring();
  }
}
