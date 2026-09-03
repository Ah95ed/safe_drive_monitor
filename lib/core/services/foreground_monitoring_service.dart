import 'package:flutter/services.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

abstract class ForegroundMonitoringService {
  Future<bool> startForegroundService();
  Future<bool> stopForegroundService();
  Future<bool> isForegroundServiceRunning();
  Future<bool> isLowLightBoostSupported();
  Future<void> openBatterySettings();
}

class AppForegroundMonitoringService implements ForegroundMonitoringService {
  static const String _tag = 'ForegroundMonitoringService';
  static const MethodChannel _channel =
      MethodChannel('com.eyewatchdriver.eye.safe_drive_monitor/foreground_service');

  @override
  Future<bool> startForegroundService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startForegroundService');
      AppLogger.info(_tag, 'startForegroundService result: $result');
      return result ?? false;
    } on PlatformException catch (e, st) {
      AppLogger.error(_tag, 'Failed to start foreground service', e, st);
      throw ForegroundServiceException(
        'تعذر تشغيل خدمة المراقبة الأمامية: ${e.message}',
        e,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Unexpected error starting foreground service', e, st);
      throw ForegroundServiceException('خطأ غير متوقع عند بدء الخدمة الأمامية', e);
    }
  }

  @override
  Future<bool> stopForegroundService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopForegroundService');
      AppLogger.info(_tag, 'stopForegroundService result: $result');
      return result ?? false;
    } on PlatformException catch (e, st) {
      AppLogger.error(_tag, 'Failed to stop foreground service', e, st);
      return false;
    } catch (e, st) {
      AppLogger.error(_tag, 'Unexpected error stopping foreground service', e, st);
      return false;
    }
  }

  @override
  Future<bool> isForegroundServiceRunning() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isForegroundServiceRunning');
      return result ?? false;
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to query isForegroundServiceRunning: $e');
      return false;
    }
  }

  @override
  Future<bool> isLowLightBoostSupported() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isLowLightBoostSupported');
      return result ?? false;
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to query isLowLightBoostSupported: $e');
      return false;
    }
  }

  @override
  Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
      AppLogger.info(_tag, 'openBatterySettings invoked.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to open battery settings', e, st);
    }
  }
}
