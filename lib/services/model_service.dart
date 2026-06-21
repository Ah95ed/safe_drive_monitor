import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;

  ModelService._internal();

  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      // تحميل النموذج من assets
      _interpreter = await Interpreter.fromAsset(
        'assets/models/eye_state_model_tensorFlow.tflite',
      );
    } catch (e) {
      debugPrint("Error loading model: $e");
      throw Exception('فشل في تحميل نموذج الذكاء الاصطناعي: $e');
    }
  }

  Interpreter? get interpreter => _interpreter;

  void dispose() {
    _interpreter?.close();
  }
}
