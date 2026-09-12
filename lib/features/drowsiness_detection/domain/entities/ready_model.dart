import 'dart:typed_data';

/// Immutable contract representing a verified, authenticated, and tested TFLite model
/// that is active and ready for inference by [EyeStateClassifier].
class ReadyModel {
  /// Monotonic version integer of the model
  final int version;

  /// Absolute file path of the verified model in app-private storage
  final String path;

  /// In-memory plaintext TFLite buffer ready for [Interpreter.fromBuffer]
  final Uint8List bytes;

  /// Expected SHA-256 digest of the plaintext model
  final String sha256;

  const ReadyModel({
    required this.version,
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  @override
  String toString() =>
      'ReadyModel(version: $version, path: $path, bytes: ${bytes.lengthInBytes}, sha256: ${sha256.substring(0, 8)}...)';
}
