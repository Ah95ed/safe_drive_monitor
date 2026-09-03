import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

abstract class BatteryOptimizationService {
  Future<bool> isIgnoringBatteryOptimizations();
  Future<bool> requestIgnoreBatteryOptimizations();
  Future<void> openBatterySettings();
}

class AppBatteryOptimizationService implements BatteryOptimizationService {
  static const String _tag = 'BatteryOptService';
  static const MethodChannel _channel =
      MethodChannel('com.eyewatchdriver.eye.safe_drive_monitor/foreground_service');

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to check battery optimization status', e, st);
      return false;
    }
  }

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        AppLogger.info(_tag, 'Battery optimizations already ignored.');
        return true;
      }

      final result = await Permission.ignoreBatteryOptimizations.request();
      AppLogger.info(_tag, 'Requested ignore battery optimizations: ${result.name}');
      return result.isGranted;
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to request battery optimization exemption', e, st);
      return false;
    }
  }

  @override
  Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
      AppLogger.info(_tag, 'Opened system battery optimization settings.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to open battery optimization settings', e, st);
      // Fallback: attempt to open application settings via permission_handler
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }
}
