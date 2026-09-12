import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/constants/model_state.dart';
import 'package:safe_drive_monitor/core/errors/model_delivery_exceptions.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/model_delivery_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/ready_model.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  HttpOverrides.global = null;

  group('Phase 3: ModelState State Machine Transitions', () {
    test('ModelState transitions follow the strict lifecycle contract', () {
      const states = ModelState.values;
      expect(states, contains(ModelState.notInstalled));
      expect(states, contains(ModelState.checking));
      expect(states, contains(ModelState.downloading));
      expect(states, contains(ModelState.verifying));
      expect(states, contains(ModelState.decrypting));
      expect(states, contains(ModelState.validating));
      expect(states, contains(ModelState.ready));
      expect(states, contains(ModelState.failed));

      expect(ModelState.ready.isReady, isTrue);
      expect(ModelState.failed.isFailed, isTrue);
      expect(ModelState.downloading.isBusy, isTrue);
      expect(ModelState.verifying.isBusy, isTrue);
      expect(ModelState.decrypting.isBusy, isTrue);
      expect(ModelState.validating.isBusy, isTrue);
      expect(ModelState.ready.isBusy, isFalse);
    });

    test('ModelState provides descriptive Arabic user-facing labels', () {
      expect(ModelState.notInstalled.arabicLabel, isNotEmpty);
      expect(ModelState.checking.arabicLabel, isNotEmpty);
      expect(ModelState.downloading.arabicLabel, isNotEmpty);
      expect(ModelState.verifying.arabicLabel, isNotEmpty);
      expect(ModelState.decrypting.arabicLabel, isNotEmpty);
      expect(ModelState.validating.arabicLabel, isNotEmpty);
      expect(ModelState.ready.arabicLabel, contains('✓'));
      expect(ModelState.failed.arabicLabel, contains('تعذر'));
    });
  });

  group('Phase 10 & 19: ReadyModel & Error Taxonomy Contract', () {
    test('ReadyModel contract holds version, path, bytes, and sha256', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);
      final readyModel = ReadyModel(
        version: 1,
        path: '/data/user/0/com.app/models/active/model_v1.enc',
        bytes: dummyBytes,
        sha256: 'dummy_hash',
      );

      expect(readyModel.version, equals(1));
      expect(readyModel.path, contains('model_v1.enc'));
      expect(readyModel.bytes.length, equals(4));
      expect(readyModel.sha256, equals('dummy_hash'));
    });

    test('ModelErrorCodes taxonomy covers all required diagnostics codes', () {
      expect(ModelErrorCodes.modelNotFoundLocal, equals('MODEL_NOT_FOUND_LOCAL'));
      expect(ModelErrorCodes.manifestFetchFailed, equals('MANIFEST_FETCH_FAILED'));
      expect(ModelErrorCodes.manifestSignatureInvalid, equals('MANIFEST_SIGNATURE_INVALID'));
      expect(ModelErrorCodes.downloadAuthFailed, equals('DOWNLOAD_AUTH_FAILED'));
      expect(ModelErrorCodes.modelDownloadHttp401, equals('MODEL_DOWNLOAD_HTTP_401'));
      expect(ModelErrorCodes.modelDownloadHttp403, equals('MODEL_DOWNLOAD_HTTP_403'));
      expect(ModelErrorCodes.modelDownloadHttp404, equals('MODEL_DOWNLOAD_HTTP_404'));
      expect(ModelErrorCodes.modelHashMismatch, equals('MODEL_HASH_MISMATCH'));
      expect(ModelErrorCodes.modelKeyUnwrapFailed, equals('MODEL_KEY_UNWRAP_FAILED'));
      expect(ModelErrorCodes.modelDecryptionFailed, equals('MODEL_DECRYPTION_FAILED'));
      expect(ModelErrorCodes.modelTfliteHealthCheckFailed, equals('MODEL_TFLITE_HEALTH_CHECK_FAILED'));
    });
  });

  group('Phase 28: Cloud Download & Inference Self-Test (Isolated from Camera)', () {
    test('End-to-End: Cloudflare Manifest -> Download -> Verify -> Decrypt -> TFLite Health Check', () async {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      const baseUrl = ModelConstants.cloudflareWorkerBaseUrl;

      // 1. Health check
      final healthReq = await client.getUrl(Uri.parse('$baseUrl/health'));
      final healthRes = await healthReq.close();
      expect(healthRes.statusCode, equals(200), reason: 'Cloudflare Worker health endpoint must return 200');

      // 2. Fetch Manifest
      final manifestReq = await client.getUrl(Uri.parse('$baseUrl/v1/model/manifest'));
      final manifestRes = await manifestReq.close();
      expect(manifestRes.statusCode, equals(200));

      final manifestBody = await manifestRes.transform(utf8.decoder).join();
      final manifest = jsonDecode(manifestBody) as Map<String, dynamic>;

      expect(manifest['model_id'], equals('drivealert-model-v1'));
      expect(manifest['encrypted_sha256'], equals(ModelConstants.bundledEncryptedSha256));
      expect(manifest['sha256'], equals(ModelConstants.bundledPlainModelSha256));
      expect(manifest['file_size'], equals(3621040));

      // 3. Unauthorized download test (Must be 401)
      final unauthReq = await client.getUrl(Uri.parse('$baseUrl/v1/model/download'));
      final unauthRes = await unauthReq.close();
      expect(unauthRes.statusCode, equals(401), reason: 'Unauthenticated download must return 401');

      // 4. Attestation & Token Acquisition
      final attestReq = await client.postUrl(Uri.parse('$baseUrl/v1/auth/attest'));
      attestReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      attestReq.write(jsonEncode({
        'deviceId': 'test_runner_device',
        'appPackage': 'com.eyewatchdriver.eye.safe_drive_monitor',
        'appVersion': '1.0.2',
        'attestationToken': 'test_token',
      }));
      final attestRes = await attestReq.close();
      expect(attestRes.statusCode, equals(200));
      final attestBody = await attestRes.transform(utf8.decoder).join();
      final attestData = jsonDecode(attestBody) as Map<String, dynamic>;
      final downloadToken = attestData['token'] as String;
      expect(downloadToken, isNotEmpty);

      // 5. Authorized Download
      final downloadReq = await client.getUrl(Uri.parse('$baseUrl/v1/model/download'));
      downloadReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $downloadToken');
      final downloadRes = await downloadReq.close();
      expect(downloadRes.statusCode, equals(200));

      final builder = BytesBuilder();
      await for (final chunk in downloadRes) {
        builder.add(chunk);
      }
      final downloadedBytes = builder.takeBytes();
      expect(downloadedBytes.length, equals(3621040));

      // 6. Verify SHA-256
      final isEncryptedValid = ModelDeliveryService.verifySha256(
        downloadedBytes,
        ModelConstants.bundledEncryptedSha256,
      );
      expect(isEncryptedValid, isTrue, reason: 'Downloaded model encrypted hash must match expected SHA-256');

      // 7. Decrypt using AES-256-GCM
      // Read key from local test secrets if present
      final envFile = File('secrets/drivealert_secrets.local.env');
      if (await envFile.exists()) {
        final lines = await envFile.readAsLines();
        String? aesKeyBase64;
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('MODEL_AES_KEY_BASE64=')) {
            aesKeyBase64 = trimmed.substring('MODEL_AES_KEY_BASE64='.length).trim();
            if (aesKeyBase64.startsWith('"') && aesKeyBase64.endsWith('"')) {
              aesKeyBase64 = aesKeyBase64.substring(1, aesKeyBase64.length - 1);
            }
          }
        }

        if (aesKeyBase64 != null) {
          final keyBytes = base64Decode(aesKeyBase64);
          final decryptedBytes = await ModelDeliveryService.decryptContainerInDart(
            downloadedBytes,
            keyBytes,
          );

          expect(decryptedBytes.length, equals(3621008));
          final isPlainValid = ModelDeliveryService.verifySha256(
            decryptedBytes,
            ModelConstants.bundledPlainModelSha256,
          );
          expect(isPlainValid, isTrue, reason: 'Decrypted plaintext model must match expected SHA-256');

          // 8. TFLite Health Check & Dummy Inference (Tested if native library is available on host OS)
          try {
            final options = InterpreterOptions()..threads = 2;
            final interpreter = Interpreter.fromBuffer(decryptedBytes, options: options);
            interpreter.allocateTensors();

            final inputTensors = interpreter.getInputTensors();
            final outputTensors = interpreter.getOutputTensors();

            expect(inputTensors.isNotEmpty, isTrue);
            expect(outputTensors.isNotEmpty, isTrue);

            final input = inputTensors.first;
            final output = outputTensors.first;

            expect(input.shape, equals([1, 320, 320, 3]));
            expect(output.shape, equals([1, 6300, 7]));

            // Run dummy inference with zeros
            final dummyInput = Float32List(1 * 320 * 320 * 3);
            input.data = dummyInput.buffer.asUint8List();
            interpreter.invoke();

            final outputData = output.data;
            expect(outputData.length, greaterThan(0));

            interpreter.close();
          } on ArgumentError catch (_) {
            // Expected on Windows dev host where libtensorflowlite_c-win.dll is not installed
            // (Android runtime contains libtensorflowlite_jni.so)
          }
        }
      }
    });
  });
}
