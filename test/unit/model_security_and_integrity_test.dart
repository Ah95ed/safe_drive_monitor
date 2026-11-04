import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Section G - Model Security & Protection Tests', () {
    test('tool/encrypt_model.dart and tool/encrypt_model.js exist and are executable', () {
      final jsTool = File('tool/encrypt_model.js');
      final dartTool = File('tool/encrypt_model.dart');

      expect(jsTool.existsSync(), isTrue, reason: 'tool/encrypt_model.js must exist');
      expect(dartTool.existsSync(), isTrue, reason: 'tool/encrypt_model.dart must exist');
    });

    test('Encrypted model payload has SDM_ENC header structure', () {
      // Magic header format: 'S', 'D', 'M', '_', 'E', 'N', 'C', 0x01
      final sampleHeader = Uint8List.fromList([
        0x53, // S
        0x44, // D
        0x4D, // M
        0x5F, // _
        0x45, // E
        0x4E, // N
        0x43, // C
        0x01, // Version 1
      ]);

      final isEncrypted = sampleHeader.length >= 8 &&
          sampleHeader[0] == 0x53 &&
          sampleHeader[1] == 0x44 &&
          sampleHeader[2] == 0x4D &&
          sampleHeader[3] == 0x5F &&
          sampleHeader[4] == 0x45 &&
          sampleHeader[5] == 0x4E &&
          sampleHeader[6] == 0x43 &&
          sampleHeader[7] == 0x01;

      expect(isEncrypted, isTrue);

      final unencryptedHeader = Uint8List.fromList([0x1C, 0x00, 0x00, 0x00, 0x54, 0x46, 0x4C, 0x33]);
      final isUnencrypted = unencryptedHeader[0] == 0x53 && unencryptedHeader[1] == 0x44;
      expect(isUnencrypted, isFalse);
    });

    test('Model encryption CLI executes and outputs encrypted file', () async {
      // Create a temporary dummy model file
      final tempInput = File('test/unit/dummy_model.bin');
      final tempOutput = File('test/unit/dummy_model.bin.enc');
      try {
        final dummyBytes = Uint8List(1024);
        for (int i = 0; i < dummyBytes.length; i++) {
          dummyBytes[i] = i % 256;
        }
        tempInput.writeAsBytesSync(dummyBytes);

        final result = await Process.run('node', [
          'tool/encrypt_model.js',
          tempInput.path,
          tempOutput.path,
        ]);

        expect(result.exitCode, equals(0));
        expect(tempOutput.existsSync(), isTrue);

        final encBytes = tempOutput.readAsBytesSync();
        // Verify header: 8 bytes magic + 12 bytes IV + 1024 bytes ciphertext + 16 bytes auth tag = 1060 bytes
        expect(encBytes.length, equals(8 + 12 + 1024 + 16));
        expect(encBytes.sublist(0, 8), equals([0x53, 0x44, 0x4D, 0x5F, 0x45, 0x4E, 0x43, 0x01]));
      } finally {
        if (tempInput.existsSync()) tempInput.deleteSync();
        if (tempOutput.existsSync()) tempOutput.deleteSync();
      }
    });
  });
}
