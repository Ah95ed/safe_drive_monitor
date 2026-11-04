import 'dart:io';

/// Safe Drive Monitor - Model Encryption CLI Tool
/// Encrypts model weights using AES-256-GCM.
Future<void> main(List<String> args) async {
  final inputPath = args.isNotEmpty
      ? args[0]
      : 'assets/models/eye_detector_5n_320_float16.tflite';
  final outputPath = args.length > 1
      ? args[1]
      : (inputPath.endsWith('.enc') ? inputPath : '$inputPath.enc');

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Error: Input model file not found at $inputPath');
    exit(1);
  }

  stdout.writeln('Encrypting $inputPath -> $outputPath via AES-256-GCM...');

  // Delegate to tool/encrypt_model.js
  final scriptPath = '${File(Platform.script.toFilePath()).parent.path}/encrypt_model.js';
  final result = await Process.run('node', [scriptPath, inputPath, outputPath]);

  if (result.exitCode != 0) {
    stderr.writeln('Encryption failed: ${result.stderr}');
    exit(result.exitCode);
  }

  stdout.write(result.stdout);
  stdout.writeln('Model encryption completed successfully.');
}
