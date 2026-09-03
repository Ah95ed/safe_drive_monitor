/// Base exception class for safe drive monitor errors.
sealed class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Thrown when camera initialization or configuration fails.
class CameraInitializationException extends AppException {
  const CameraInitializationException(super.message, [super.cause]);
}

/// Thrown when required permissions (e.g. camera) are denied.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException(super.message, [super.cause]);
}

/// Thrown when the TensorFlow Lite model fails to load or initialize.
class ModelLoadException extends AppException {
  const ModelLoadException(super.message, [super.cause]);
}

/// Thrown when converting or preprocessing a camera frame fails.
class ImageConversionException extends AppException {
  const ImageConversionException(super.message, [super.cause]);
}

/// Thrown when running inference on the TensorFlow Lite interpreter fails.
class InferenceException extends AppException {
  const InferenceException(super.message, [super.cause]);
}

/// Thrown when audio alarm playback fails.
class AudioAlarmException extends AppException {
  const AudioAlarmException(super.message, [super.cause]);
}

/// Thrown when starting, stopping or communicating with the Android Foreground Service fails.
class ForegroundServiceException extends AppException {
  const ForegroundServiceException(super.message, [super.cause]);
}

/// Thrown when lighting measurement or exposure adaptation fails.
class LightingException extends AppException {
  const LightingException(super.message, [super.cause]);
}

/// Thrown when checking or requesting battery optimization exemption fails.
class BatteryOptimizationException extends AppException {
  const BatteryOptimizationException(super.message, [super.cause]);
}

/// Thrown when the watchdog fails to recover the monitoring pipeline.
class MonitoringRecoveryException extends AppException {
  const MonitoringRecoveryException(super.message, [super.cause]);
}

/// Thrown when thermal throttling severely impairs monitoring safety.
class ThermalException extends AppException {
  const ThermalException(super.message, [super.cause]);
}
