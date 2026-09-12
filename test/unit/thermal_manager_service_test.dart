import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/services/thermal_manager_service.dart';

class MockThermalManagerService implements ThermalManagerService {
  DeviceThermalState _mockState = DeviceThermalState.none;
  double? _mockHeadroom = 0.85;
  DateTime? _lastCheckedAt;
  void Function(DeviceThermalState state)? _onStateChanged;

  void setMockState(DeviceThermalState state) {
    _mockState = state;
    _lastCheckedAt = DateTime.now();
    _onStateChanged?.call(state);
  }

  void setMockHeadroom(double? headroom) {
    _mockHeadroom = headroom;
  }

  @override
  DeviceThermalState get currentState => _mockState;

  @override
  double? get lastThermalHeadroom => _mockHeadroom;

  @override
  DateTime? get lastCheckedAt => _lastCheckedAt;

  @override
  Future<DeviceThermalState> checkThermalStatus() async {
    _lastCheckedAt = DateTime.now();
    return _mockState;
  }

  @override
  Future<double?> checkThermalHeadroom({int forecastSeconds = 10}) async {
    return _mockHeadroom;
  }

  @override
  void startMonitoring({
    Duration interval = const Duration(seconds: 15),
    void Function(DeviceThermalState state)? onThermalStateChanged,
  }) {
    _onStateChanged = onThermalStateChanged;
  }

  @override
  void stopMonitoring() {
    _onStateChanged = null;
  }

  @override
  void dispose() {
    stopMonitoring();
  }
}

void main() {
  group('ThermalManagerService and DeviceThermalState', () {
    test('Maps Android PowerManager raw integer codes to DeviceThermalState correctly', () {
      expect(DeviceThermalState.fromRawValue(0), equals(DeviceThermalState.none));
      expect(DeviceThermalState.fromRawValue(1), equals(DeviceThermalState.light));
      expect(DeviceThermalState.fromRawValue(2), equals(DeviceThermalState.moderate));
      expect(DeviceThermalState.fromRawValue(3), equals(DeviceThermalState.severe));
      expect(DeviceThermalState.fromRawValue(4), equals(DeviceThermalState.critical));
      expect(DeviceThermalState.fromRawValue(5), equals(DeviceThermalState.emergency));
      expect(DeviceThermalState.fromRawValue(6), equals(DeviceThermalState.shutdown));
      expect(DeviceThermalState.fromRawValue(99), equals(DeviceThermalState.none));
    });

    test('Identifies thermal pressure correctly on moderate, severe, and critical states', () {
      expect(DeviceThermalState.none.isThermalPressure, isFalse);
      expect(DeviceThermalState.light.isThermalPressure, isFalse);
      expect(DeviceThermalState.moderate.isThermalPressure, isTrue);
      expect(DeviceThermalState.severe.isThermalPressure, isTrue);
      expect(DeviceThermalState.critical.isThermalPressure, isTrue);
      expect(DeviceThermalState.emergency.isThermalPressure, isTrue);
    });

    test('MockThermalManagerService notifies listener when thermal state changes', () {
      final mock = MockThermalManagerService();
      DeviceThermalState? notified;

      mock.startMonitoring(
        onThermalStateChanged: (state) {
          notified = state;
        },
      );

      mock.setMockState(DeviceThermalState.moderate);
      expect(mock.currentState, equals(DeviceThermalState.moderate));
      expect(notified, equals(DeviceThermalState.moderate));

      mock.stopMonitoring();
    });
  });
}
