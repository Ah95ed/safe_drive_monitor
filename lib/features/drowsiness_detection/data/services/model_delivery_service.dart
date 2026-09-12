import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto_lib;
import 'package:flutter/services.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

/// Exception thrown when model integrity or security validation fails.
class ModelSecurityException implements Exception {
  final String message;
  const ModelSecurityException(this.message);

  @override
  String toString() => 'ModelSecurityException: $message';
}

/// Secure service handling model decryption, SHA-256 integrity checks,
/// anti-rollback validation, and Cloudflare delivery.
class ModelDeliveryService {
  static const String _tag = 'ModelDeliveryService';
  static const MethodChannel _channel = MethodChannel(
    'com.eyewatchdriver.eye.safe_drive_monitor/foreground_service',
  );

  /// Tracks the highest verified model version accepted by this device (Anti-Rollback).
  static int _highestAcceptedModelVersion = ModelConstants.currentModelVersion;

  static int get highestAcceptedModelVersion => _highestAcceptedModelVersion;

  /// Verifies SHA-256 digest of arbitrary bytes against expected hexadecimal digest.
  static bool verifySha256(Uint8List bytes, String expectedHexDigest) {
    final actualDigest = sha256.convert(bytes).toString().toLowerCase();
    final expected = expectedHexDigest.trim().toLowerCase();
    return actualDigest == expected;
  }

  /// Validates anti-rollback rules: new versions must be >= highest accepted version.
  static bool validateAntiRollback(int incomingVersion) {
    if (incomingVersion < _highestAcceptedModelVersion) {
      AppLogger.error(
        _tag,
        'Anti-Rollback Violation: Incoming model version $incomingVersion is older than highest accepted version $_highestAcceptedModelVersion',
      );
      return false;
    }
    return true;
  }

  /// Decrypts an encrypted model container (DAM1 format) using native hardware AES-256-GCM
  /// or pure Dart cryptography fallback if platform channel is not available.
  static Future<Uint8List> decryptContainer(
    Uint8List encryptedBytes, {
    Uint8List? wrappedKeyBytes,
    Uint8List? directKeyBytes,
  }) async {
    try {
      final arguments = <String, dynamic>{
        'encryptedBytes': encryptedBytes,
      };
      if (wrappedKeyBytes != null) {
        arguments['wrappedKeyBytes'] = wrappedKeyBytes;
      }
      if (directKeyBytes != null) {
        arguments['keyBytes'] = directKeyBytes;
      }

      final dynamic result = await _channel.invokeMethod('decryptModelContainer', arguments);

      if (result is Uint8List) {
        AppLogger.info(_tag, 'Model successfully decrypted via native hardware AES-256-GCM.');
        return result;
      } else if (result is List<int>) {
        AppLogger.info(_tag, 'Model successfully decrypted via native hardware AES-256-GCM (List<int>).');
        return Uint8List.fromList(result);
      } else {
        throw ModelSecurityException(
          'Unexpected decryption result format from platform channel: ${result.runtimeType}',
        );
      }
    } on MissingPluginException catch (_) {
      if (directKeyBytes != null) {
        AppLogger.info(_tag, 'Platform channel unavailable; using pure Dart AES-256-GCM decryption');
        return decryptContainerInDart(encryptedBytes, directKeyBytes);
      }
      rethrow;
    } on PlatformException catch (e) {
      AppLogger.error(_tag, 'Platform error during model decryption: ${e.message}', e);
      rethrow;
    } catch (e, st) {
      AppLogger.error(_tag, 'Error decrypting model container', e, st);
      rethrow;
    }
  }

  /// Pure Dart AES-256-GCM decryption for tests and non-Android environments.
  static Future<Uint8List> decryptContainerInDart(
    Uint8List encryptedContainer,
    Uint8List keyBytes,
  ) async {
    if (encryptedContainer.length < 32) {
      throw const ModelSecurityException('Encrypted container too short');
    }
    final magic = utf8.decode(encryptedContainer.sublist(0, 4));
    if (magic != 'DAM1') {
      throw const ModelSecurityException('Invalid container format: magic mismatch');
    }
    final iv = encryptedContainer.sublist(4, 16);
    final tag = encryptedContainer.sublist(16, 32);
    final ciphertext = encryptedContainer.sublist(32);

    final algorithm = crypto_lib.AesGcm.with256bits();
    final secretKey = crypto_lib.SecretKey(keyBytes);
    final secretBox = crypto_lib.SecretBox(
      ciphertext,
      nonce: iv,
      mac: crypto_lib.Mac(tag),
    );
    final decrypted = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(decrypted);
  }

  /// Loads the encrypted model from assets, verifies its encrypted SHA-256 hash,
  /// decrypts it into memory, and verifies the decrypted plaintext hash.
  static Future<Uint8List> loadAndDecryptModelAsset({String? assetPath}) async {
    final path = assetPath ?? ModelConstants.modelAssetPath;
    AppLogger.info(_tag, 'Loading encrypted model asset from: $path');

    final byteData = await rootBundle.load(path);
    final encryptedBytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    // 1. Anti-Tamper: Verify encrypted container hash
    final isEncryptedValid = verifySha256(
      encryptedBytes,
      ModelConstants.bundledEncryptedSha256,
    );
    if (!isEncryptedValid) {
      throw const ModelSecurityException(
        'Encrypted model container SHA-256 mismatch. Tampering detected!',
      );
    }

    // 2. Hardware-backed / native AES-GCM Decryption
    final decryptedBytes = await decryptContainer(encryptedBytes);

    // 3. Anti-Tamper: Verify decrypted model SHA-256 hash
    final isPlainValid = verifySha256(
      decryptedBytes,
      ModelConstants.bundledPlainModelSha256,
    );
    if (!isPlainValid) {
      throw const ModelSecurityException(
        'Decrypted TFLite model SHA-256 digest mismatch. Model integrity check failed!',
      );
    }

    AppLogger.info(
      _tag,
      'Model verified & authenticated successfully (${decryptedBytes.lengthInBytes} bytes).',
    );
    return decryptedBytes;
  }

  /// Atomic activation of a downloaded model candidate:
  /// Verifies encrypted SHA-256, decrypts, verifies decrypted SHA-256, and updates version.
  static Future<Uint8List> verifyAndActivateCandidate({
    required Uint8List candidateEncryptedBytes,
    required String expectedEncryptedSha256,
    required String expectedPlainSha256,
    required int candidateVersion,
    Uint8List? wrappedKeyBytes,
  }) async {
    // 1. Anti-rollback check
    if (!validateAntiRollback(candidateVersion)) {
      throw ModelSecurityException(
        'Candidate version $candidateVersion violates anti-rollback policy.',
      );
    }

    // 2. Verify encrypted hash
    if (!verifySha256(candidateEncryptedBytes, expectedEncryptedSha256)) {
      throw const ModelSecurityException(
        'Candidate encrypted SHA-256 digest mismatch.',
      );
    }

    // 3. Decrypt candidate
    final decryptedBytes = await decryptContainer(
      candidateEncryptedBytes,
      wrappedKeyBytes: wrappedKeyBytes,
    );

    // 4. Verify decrypted plain hash
    if (!verifySha256(decryptedBytes, expectedPlainSha256)) {
      throw const ModelSecurityException(
        'Candidate decrypted plaintext SHA-256 mismatch.',
      );
    }

    // 5. Commit new version atomically
    _highestAcceptedModelVersion = candidateVersion;
    AppLogger.info(
      _tag,
      'Model candidate version $candidateVersion successfully activated.',
    );
    return decryptedBytes;
  }
}
