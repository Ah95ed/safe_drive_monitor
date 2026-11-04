import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';

void main() {
  group('Section C Packaging & Sound Assets Verification Tests', () {
    test('Mandatory AI model asset exists and is non-empty', () {
      final modelFile = File(ModelConstants.modelAssetPath);
      expect(modelFile.existsSync(), isTrue,
          reason: 'Model asset file must exist at ${ModelConstants.modelAssetPath}');
      expect(modelFile.lengthSync(), greaterThan(1000000),
          reason: 'Model asset file should contain valid model weights (> 1MB)');
    });

    test('Mandatory drowsiness alarm sound asset exists and is non-empty', () {
      final alarmFile = File('assets/${AppConstants.alarmSoundAsset}');
      expect(alarmFile.existsSync(), isTrue,
          reason: 'Drowsiness alarm asset must exist at assets/${AppConstants.alarmSoundAsset}');
      expect(alarmFile.lengthSync(), greaterThan(1000),
          reason: 'Alarm sound asset should be a valid audio file');
    });

    test('Mandatory technical warning sound asset exists and is non-empty (Section C3)', () {
      final warningFile = File('assets/${AppConstants.technicalWarningSoundAsset}');
      expect(warningFile.existsSync(), isTrue,
          reason: 'Technical warning asset must exist at assets/${AppConstants.technicalWarningSoundAsset}');
      expect(warningFile.lengthSync(), greaterThan(1000),
          reason: 'Warning sound asset should be a valid audio file');
    });

    test('AudioAssetLoadException formats descriptive safety message', () {
      const exception = AudioAssetLoadException('Sound loading failed');
      expect(exception.message, contains('Sound loading failed'));
      expect(exception.toString(), contains('AudioAssetLoadException'));
    });
  });
}
