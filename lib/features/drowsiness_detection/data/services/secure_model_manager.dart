import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' as crypto_lib;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/constants/model_state.dart';
import 'package:safe_drive_monitor/core/errors/model_delivery_exceptions.dart';
import 'package:safe_drive_monitor/core/services/security_environment_service.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/model_delivery_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/ready_model.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Secure Model Manager orchestrating the lifecycle of AI models:
/// Local storage check -> Manifest verification -> Device attestation ->
/// Authenticated download -> Integrity verification -> Hardware Keystore decryption ->
/// TFLite health check -> Atomic activation -> Ready model delivery.
class SecureModelManager extends ChangeNotifier {
  static const String _tag = 'SecureModelManager';

  static final SecureModelManager _instance = SecureModelManager._internal();
  factory SecureModelManager() => _instance;
  SecureModelManager._internal();

  ModelState _state = ModelState.notInstalled;
  double _downloadProgress = 0.0;
  String? _lastErrorCode;
  String? _lastErrorMessage;
  ReadyModel? _readyModel;

  Future<ReadyModel>? _bootstrapFuture;
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  ModelState get state => _state;
  double get downloadProgress => _downloadProgress;
  String? get lastErrorCode => _lastErrorCode;
  String? get lastErrorMessage => _lastErrorMessage;
  ReadyModel? get readyModel => _readyModel;
  bool get isModelReady => _state == ModelState.ready && _readyModel != null;

  void _setState(
    ModelState newState, {
    String? errorCode,
    String? errorMessage,
    double? progress,
  }) {
    _state = newState;
    if (errorCode != null) _lastErrorCode = errorCode;
    if (errorMessage != null) _lastErrorMessage = errorMessage;
    if (progress != null) _downloadProgress = progress;
    notifyListeners();
  }

  /// App-private models directory: `appSupport/models/`
  Future<Directory> get _modelsBaseDir async {
    final supportDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(p.join(supportDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<Directory> get _activeDir async {
    final base = await _modelsBaseDir;
    final dir = Directory(p.join(base.path, 'active'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get _candidatesDir async {
    final base = await _modelsBaseDir;
    final dir = Directory(p.join(base.path, 'candidates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get _metadataDir async {
    final base = await _modelsBaseDir;
    final dir = Directory(p.join(base.path, 'metadata'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Idempotent entry point for bootstrapping the AI model.
  /// Prevents concurrent downloads or multiple parallel initializations.
  Future<ReadyModel> initialize({bool forceRefresh = false}) {
    if (!forceRefresh && _state == ModelState.ready && _readyModel != null) {
      return Future.value(_readyModel);
    }

    if (_bootstrapFuture != null) {
      return _bootstrapFuture!;
    }

    _bootstrapFuture = _executeBootstrapFlow(forceRefresh: forceRefresh)
        .whenComplete(() {
      _bootstrapFuture = null;
    });

    return _bootstrapFuture!;
  }

  Future<ReadyModel> _executeBootstrapFlow({required bool forceRefresh}) async {
    AppLogger.info(_tag, 'MODEL_BOOTSTRAP_START');
    _setState(ModelState.checking, progress: 0.0);

    // 1. Check local model first (Offline First)
    if (!forceRefresh) {
      try {
        final localModel = await _tryLoadLocalActiveModel();
        if (localModel != null) {
          _readyModel = localModel;
          _setState(ModelState.ready, progress: 1.0);
          AppLogger.info(_tag, 'MODEL_BOOTSTRAP_COMPLETE (using local active model)');
          return localModel;
        }
      } catch (e) {
        AppLogger.warning(_tag, 'Local model check failed or corrupted: $e');
      }
    }

    // 2. Local model not found or invalid: Begin Cloud Download Flow with retry backoff
    AppLogger.info(_tag, 'LOCAL_MODEL_NOT_FOUND, initiating Cloudflare download flow');

    int attempt = 0;
    const maxRetries = 3;
    dynamic lastError;

    while (attempt < maxRetries) {
      attempt++;
      try {
        AppLogger.info(_tag, 'Download attempt $attempt of $maxRetries');
        final readyModel = await _downloadVerifyAndActivateModel();
        _readyModel = readyModel;
        _setState(ModelState.ready, progress: 1.0);
        AppLogger.info(_tag, 'MODEL_BOOTSTRAP_COMPLETE');
        return readyModel;
      } catch (e, st) {
        lastError = e;
        AppLogger.error(_tag, 'Download attempt $attempt failed: $e', e, st);
        if (attempt < maxRetries) {
          final backoffMs = 1000 * (1 << (attempt - 1));
          await Future.delayed(Duration(milliseconds: backoffMs));
        }
      }
    }

    // All retries exhausted
    final errorCode = lastError is ModelDeliveryException
        ? lastError.errorCode
        : ModelErrorCodes.modelBootstrapFailed;
    final errorMessage = lastError is ModelDeliveryException
        ? lastError.message
        : 'تعذر تجهيز نظام الذكاء الاصطناعي';

    _setState(
      ModelState.failed,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
    AppLogger.error(_tag, 'MODEL_BOOTSTRAP_FAILED: errorCode=$errorCode');

    if (lastError is ModelDeliveryException) {
      throw lastError;
    }
    throw ModelDeliveryException(
      errorCode: errorCode,
      userMessage: errorMessage,
      originalError: lastError,
    );
  }

  /// Checks for an active, verified model on local storage.
  Future<ReadyModel?> _tryLoadLocalActiveModel() async {
    AppLogger.info(_tag, 'LOCAL_MODEL_CHECK');
    final metaDir = await _metadataDir;
    final activeManifestFile = File(p.join(metaDir.path, 'active_manifest.json'));

    if (!await activeManifestFile.exists()) {
      AppLogger.info(_tag, 'LOCAL_MODEL_NOT_FOUND (no active manifest)');
      return null;
    }

    final manifestContent = await activeManifestFile.readAsString();
    final Map<String, dynamic> manifest = jsonDecode(manifestContent);

    final expectedEncSha256 = manifest['encrypted_sha256'] as String?;
    final expectedPlainSha256 = manifest['sha256'] as String?;
    final version = manifest['version'] as String? ?? '1.0.0';
    final intVersion = int.tryParse(version.replaceAll('.', '')) ?? 1;

    final activeDir = await _activeDir;
    final activeFile = File(p.join(activeDir.path, 'model_v$intVersion.enc'));

    if (!await activeFile.exists() || await activeFile.length() == 0) {
      AppLogger.info(_tag, 'LOCAL_MODEL_NOT_FOUND (active file missing or empty)');
      return null;
    }

    final activeBytes = await activeFile.readAsBytes();
    if (expectedEncSha256 != null &&
        !ModelDeliveryService.verifySha256(activeBytes, expectedEncSha256)) {
      AppLogger.warning(_tag, 'Local active model hash mismatch! Tampering or corruption detected.');
      return null;
    }

    // Decrypt local model
    _setState(ModelState.decrypting);
    final plainBytes = await _decryptContainer(activeBytes);

    if (expectedPlainSha256 != null &&
        !ModelDeliveryService.verifySha256(plainBytes, expectedPlainSha256)) {
      AppLogger.warning(_tag, 'Local decrypted model plain hash mismatch!');
      return null;
    }

    // Health check
    _setState(ModelState.validating);
    final isHealthy = await _runTfliteHealthCheck(plainBytes);
    if (!isHealthy) {
      AppLogger.warning(_tag, 'Local model failed TFLite health check');
      return null;
    }

    AppLogger.info(_tag, 'LOCAL_MODEL_FOUND: active model v$intVersion is valid and healthy');
    return ReadyModel(
      version: intVersion,
      path: activeFile.path,
      bytes: plainBytes,
      sha256: expectedPlainSha256 ?? '',
    );
  }

  /// Downloads manifest, attests device, streams model bytes, decrypts, and activates.
  Future<ReadyModel> _downloadVerifyAndActivateModel() async {
    final baseUrl = ModelConstants.cloudflareWorkerBaseUrl;

    // 1. Fetch manifest
    AppLogger.info(_tag, 'MANIFEST_FETCH_START: $baseUrl/v1/model/manifest');
    _setState(ModelState.checking);

    final manifest = await _fetchManifest(baseUrl);
    AppLogger.info(_tag, 'MANIFEST_OK');

    // 2. Validate manifest signature and rules
    _setState(ModelState.verifying);
    await _validateManifest(manifest);

    final expectedEncSha256 = manifest['encrypted_sha256'] as String;
    final expectedPlainSha256 = manifest['sha256'] as String;
    final expectedFileSize = manifest['file_size'] as int;
    final versionStr = manifest['version'] as String? ?? '1.0.0';
    final intVersion = int.tryParse(versionStr.replaceAll('.', '')) ?? 1;

    // 3. Attest device & obtain short-lived download token and wrapped key
    final attestation = await _attestDevice(baseUrl);
    final downloadToken = attestation['token'] as String;
    final wrappedKeyBase64 = attestation['wrappedKey'] as String?;

    // 4. Download model with real progress
    _setState(ModelState.downloading, progress: 0.0);
    AppLogger.info(_tag, 'DOWNLOAD_START');

    final candidateDir = await _candidatesDir;
    final candidateFile = File(p.join(candidateDir.path, 'model_v$intVersion.download'));

    await _downloadModelBytes(
      downloadUrl: '$baseUrl/v1/model/download',
      token: downloadToken,
      destinationFile: candidateFile,
      expectedSize: expectedFileSize,
    );

    AppLogger.info(_tag, 'DOWNLOAD_COMPLETE');

    // 5. Verify downloaded file on disk
    _setState(ModelState.verifying);
    if (!await candidateFile.exists() || await candidateFile.length() == 0) {
      throw const ModelDeliveryException(
        errorCode: ModelErrorCodes.modelFileEmpty,
        userMessage: 'ملف النموذج الذي تم تنزيله فارغ أو مفقود.',
      );
    }

    final downloadedSize = await candidateFile.length();
    AppLogger.info(_tag, 'MODEL_FILE_DOWNLOADED path=${candidateFile.path} size=$downloadedSize');

    if (downloadedSize != expectedFileSize) {
      await candidateFile.delete().catchError((_) => candidateFile);
      throw const ModelDeliveryException(
        errorCode: ModelErrorCodes.modelSizeMismatch,
        userMessage: 'حجم ملف النموذج لا يتطابق مع الحجم المتوقع.',
      );
    }

    final candidateBytes = await candidateFile.readAsBytes();
    if (!ModelDeliveryService.verifySha256(candidateBytes, expectedEncSha256)) {
      await candidateFile.delete().catchError((_) => candidateFile);
      throw const ModelDeliveryException(
        errorCode: ModelErrorCodes.modelHashMismatch,
        userMessage: 'فشل التحقق من صحة توقيع وهاش النموذج (Hash Mismatch).',
      );
    }
    AppLogger.info(_tag, 'HASH_VERIFY_OK');

    // 6. Decrypt model
    _setState(ModelState.decrypting);
    AppLogger.info(_tag, 'DECRYPT_START');

    Uint8List? wrappedKeyBytes;
    if (wrappedKeyBase64 != null && wrappedKeyBase64.isNotEmpty) {
      wrappedKeyBytes = base64Decode(wrappedKeyBase64);
    }

    final plainBytes = await _decryptContainer(
      candidateBytes,
      wrappedKeyBytes: wrappedKeyBytes,
    );

    if (!ModelDeliveryService.verifySha256(plainBytes, expectedPlainSha256)) {
      await candidateFile.delete().catchError((_) => candidateFile);
      throw const ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDecryptionFailed,
        userMessage: 'فشل فك التشفير: الهاش الناتج لا يطابق النموذج الأصلي.',
      );
    }
    AppLogger.info(_tag, 'DECRYPT_OK');

    // 7. TFLite Health Check
    _setState(ModelState.validating);
    final isHealthy = await _runTfliteHealthCheck(plainBytes);
    if (!isHealthy) {
      await candidateFile.delete().catchError((_) => candidateFile);
      throw const ModelDeliveryException(
        errorCode: ModelErrorCodes.modelTfliteHealthCheckFailed,
        userMessage: 'فشل اختبار صحة نموذج الذكاء الاصطناعي (TFLite Health Check Failed).',
      );
    }
    AppLogger.info(_tag, 'TFLITE_HEALTH_CHECK_OK');

    // 8. Atomic Activation
    final activeDir = await _activeDir;
    final activeFile = File(p.join(activeDir.path, 'model_v$intVersion.enc'));

    if (await activeFile.exists()) {
      // Keep previous as backup if needed
      final prevFile = File(p.join(activeDir.path, 'model_v${intVersion}_previous.enc'));
      await activeFile.copy(prevFile.path);
    }

    await candidateFile.rename(activeFile.path);

    // Persist active manifest
    final metaDir = await _metadataDir;
    final activeManifestFile = File(p.join(metaDir.path, 'active_manifest.json'));
    await activeManifestFile.writeAsString(jsonEncode(manifest));

    AppLogger.info(_tag, 'MODEL_ACTIVATED: activePath=${activeFile.path}');

    return ReadyModel(
      version: intVersion,
      path: activeFile.path,
      bytes: plainBytes,
      sha256: expectedPlainSha256,
    );
  }

  Future<Map<String, dynamic>> _fetchManifest(String baseUrl) async {
    try {
      final request = await _httpClient
          .getUrl(Uri.parse('$baseUrl/v1/model/manifest'))
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw ModelDeliveryException(
          errorCode: 'MODEL_DOWNLOAD_HTTP_${response.statusCode}',
          userMessage: 'تعذر جلب تفاصيل النموذج من الخادم (HTTP ${response.statusCode}).',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } on TimeoutException catch (e) {
      throw ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDownloadTimeout,
        userMessage: 'انتهت مهلة الاتصال بالخادم أثناء جلب تفاصيل الموديل.',
        originalError: e,
      );
    } on SocketException catch (e) {
      throw ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDownloadNetworkError,
        userMessage: 'فشل الاتصال بالشبكة أثناء محاولة الوصول لخادم الموديل.',
        originalError: e,
      );
    }
  }

  Future<void> _validateManifest(Map<String, dynamic> manifest) async {
    final signatureBase64 = manifest['signature'] as String?;
    final versionStr = manifest['version'] as String?;
    final encryptedSha256 = manifest['encrypted_sha256'] as String?;
    final plainSha256 = manifest['sha256'] as String?;
    final fileSize = manifest['file_size'] as int?;

    if (signatureBase64 == null ||
        versionStr == null ||
        encryptedSha256 == null ||
        plainSha256 == null ||
        fileSize == null) {
      throw const ModelDeliveryException(
        errorCode: ModelErrorCodes.manifestSignatureInvalid,
        userMessage: 'بيانات مانيفيست النموذج غير مكتملة أو تالفة.',
      );
    }

    final intVersion = int.tryParse(versionStr.replaceAll('.', '')) ?? 1;
    if (!ModelDeliveryService.validateAntiRollback(intVersion)) {
      throw const ModelDeliveryException(
        errorCode: ModelErrorCodes.modelVersionInvalid,
        userMessage: 'إصدار النموذج أقدم من الإصدار النشط (Anti-Rollback Violation).',
      );
    }

    // Verify Ed25519 digital signature
    final isValidSig = await _verifyEd25519Signature(manifest, signatureBase64);
    if (!isValidSig) {
      throw const ModelDeliveryException(
        errorCode: ModelErrorCodes.manifestSignatureInvalid,
        userMessage: 'التوقيع الرقمي للمانيفيست غير صالح. قد يكون تم التلاعب به.',
      );
    }
  }

  Future<bool> _verifyEd25519Signature(
    Map<String, dynamic> manifest,
    String signatureBase64,
  ) async {
    try {
      final pubKeyDer = base64Decode(ModelConstants.modelSigningPublicKeyBase64);
      // In SPKI format for Ed25519, the last 32 bytes are the raw public key
      final rawPubKey = pubKeyDer.sublist(pubKeyDer.length - 32);

      final payloadMap = Map<String, dynamic>.from(manifest)..remove('signature');
      final payloadJson = jsonEncode(payloadMap);

      final algorithm = crypto_lib.Ed25519();
      final pubKey = crypto_lib.SimplePublicKey(
        rawPubKey,
        type: crypto_lib.KeyPairType.ed25519,
      );

      final sigBytes = base64Decode(signatureBase64);
      final isVerified = await algorithm.verify(
        utf8.encode(payloadJson),
        signature: crypto_lib.Signature(sigBytes, publicKey: pubKey),
      );

      return isVerified;
    } catch (e) {
      AppLogger.error(_tag, 'Error verifying Ed25519 signature: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _attestDevice(String baseUrl) async {
    try {
      final devicePublicKey =
          await SecurityEnvironmentService.getDeviceAttestationPublicKey();

      final request = await _httpClient
          .postUrl(Uri.parse('$baseUrl/v1/auth/attest'))
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final payload = {
        'deviceId': 'device_${Platform.operatingSystem}',
        'appPackage': 'com.eyewatchdriver.eye.safe_drive_monitor',
        'appVersion': '1.0.2',
        'attestationToken': 'mobile_attestation',
        if (devicePublicKey != null) 'devicePublicKey': devicePublicKey,
      };

      request.write(jsonEncode(payload));
      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw ModelDeliveryException(
          errorCode: ModelErrorCodes.downloadAuthFailed,
          userMessage: 'فشل توثيق الجهاز مع الخادم (HTTP ${response.statusCode}).',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['token'] == null) {
        throw const ModelDeliveryException(
          errorCode: ModelErrorCodes.downloadAuthFailed,
          userMessage: 'لم يتم استلام توكن التنزيل المصرح به من الخادم.',
        );
      }

      return data;
    } on TimeoutException catch (e) {
      throw ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDownloadTimeout,
        userMessage: 'انتهت مهلة توثيق الجهاز مع الخادم.',
        originalError: e,
      );
    } on SocketException catch (e) {
      throw ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDownloadNetworkError,
        userMessage: 'فشل الاتصال بالشبكة أثناء توثيق الجهاز.',
        originalError: e,
      );
    }
  }

  Future<void> _downloadModelBytes({
    required String downloadUrl,
    required String token,
    required File destinationFile,
    required int expectedSize,
  }) async {
    try {
      final request = await _httpClient
          .getUrl(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');

      final response = await request.close().timeout(const Duration(seconds: 20));

      if (response.statusCode == 401) {
        throw const ModelDeliveryException(
          errorCode: ModelErrorCodes.modelDownloadHttp401,
          userMessage: 'انتهت صلاحية إذن التنزيل (401 Unauthorized).',
        );
      } else if (response.statusCode == 403) {
        throw const ModelDeliveryException(
          errorCode: ModelErrorCodes.modelDownloadHttp403,
          userMessage: 'تم رفض الوصول لتنزيل النموذج (403 Forbidden).',
        );
      } else if (response.statusCode == 404) {
        throw const ModelDeliveryException(
          errorCode: ModelErrorCodes.modelDownloadHttp404,
          userMessage: 'ملف النموذج غير موجود على الخادم (404 Not Found).',
        );
      } else if (response.statusCode >= 500) {
        throw ModelDeliveryException(
          errorCode: 'MODEL_DOWNLOAD_HTTP_${response.statusCode}',
          userMessage: 'خطأ داخلي في خادم التنزيل (HTTP ${response.statusCode}).',
        );
      } else if (response.statusCode != 200) {
        throw ModelDeliveryException(
          errorCode: 'MODEL_DOWNLOAD_HTTP_${response.statusCode}',
          userMessage: 'فشل تنزيل النموذج (HTTP ${response.statusCode}).',
        );
      }

      final contentLength = response.contentLength > 0
          ? response.contentLength
          : expectedSize;

      AppLogger.info(
        _tag,
        'DOWNLOAD_DESTINATION: ${destinationFile.path}, totalBytes=$contentLength',
      );

      final sink = destinationFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          final progress = receivedBytes / contentLength;
          _setState(ModelState.downloading, progress: progress.clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();
    } on TimeoutException catch (e) {
      throw ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDownloadTimeout,
        userMessage: 'انتهت مهلة تنزيل ملف النموذج.',
        originalError: e,
      );
    } on SocketException catch (e) {
      throw ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDownloadNetworkError,
        userMessage: 'فشل الاتصال بالشبكة أثناء تنزيل النموذج.',
        originalError: e,
      );
    }
  }

  /// Hardware-backed decryption on Android or pure Dart fallback.
  Future<Uint8List> _decryptContainer(
    Uint8List encryptedContainer, {
    Uint8List? wrappedKeyBytes,
  }) async {
    try {
      return await ModelDeliveryService.decryptContainer(
        encryptedContainer,
        wrappedKeyBytes: wrappedKeyBytes,
      );
    } on PlatformException catch (pe) {
      AppLogger.error(_tag, 'Platform Keystore decryption error: ${pe.code} - ${pe.message}');
      if (pe.code == 'KEY_MISSING' || pe.code == 'KEYSTORE_ERROR') {
        throw ModelDeliveryException(
          errorCode: ModelErrorCodes.modelKeyUnwrapFailed,
          userMessage: 'فشل فك تغليف مفتاح التشفير من Android Keystore.',
          originalError: pe,
        );
      }
      throw ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDecryptionFailed,
        userMessage: 'فشل فك تشفير النموذج المشفر.',
        originalError: pe,
      );
    } catch (e) {
      throw ModelDeliveryException(
        errorCode: ModelErrorCodes.modelDecryptionFailed,
        userMessage: 'فشل فك تشفير حاوية النموذج.',
        originalError: e,
      );
    }
  }

  /// Runs TFLite Health Check verifying input tensors, output tensors, and test inference.
  Future<bool> _runTfliteHealthCheck(Uint8List tfliteModelBytes) async {
    Interpreter? testInterpreter;
    try {
      final options = InterpreterOptions()..threads = 2;
      testInterpreter = Interpreter.fromBuffer(tfliteModelBytes, options: options);
      testInterpreter.allocateTensors();

      final inputTensors = testInterpreter.getInputTensors();
      final outputTensors = testInterpreter.getOutputTensors();

      if (inputTensors.isEmpty || outputTensors.isEmpty) {
        AppLogger.error(_tag, 'TFLite health check failed: empty tensors');
        return false;
      }

      final input = inputTensors.first;
      final output = outputTensors.first;

      // Verify shape: [1, H, W, 3]
      if (input.shape.length != 4 ||
          input.shape[0] != 1 ||
          input.shape[3] != 3) {
        AppLogger.error(_tag, 'TFLite health check failed: unexpected input shape ${input.shape}');
        return false;
      }

      // Verify output shape [1, 6300, 7] or [1, 2]
      final bool isYolo = (output.shape.length == 3 && output.shape[2] == 7) ||
                          (output.shape.length == 2 && output.shape[1] == 7);
      final bool isClassification = (output.shape.length == 2 && output.shape[1] == 2) ||
                                    (output.shape.length == 3 && output.shape[2] == 2);

      if (!isYolo && !isClassification) {
        AppLogger.error(_tag, 'TFLite health check failed: unexpected output shape ${output.shape}');
        return false;
      }

      AppLogger.info(
        _tag,
        'TFLITE_HEALTH_CHECK_OK: input=${input.shape} (${input.type.name}), output=${output.shape} (${output.type.name})',
      );
      return true;
    } catch (e) {
      AppLogger.error(_tag, 'TFLite health check exception: $e');
      return false;
    } finally {
      testInterpreter?.close();
    }
  }
}
