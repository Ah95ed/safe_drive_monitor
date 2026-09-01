/// Mode of raw output produced by the eye state classification model.
enum ModelOutputMode {
  /// Detect the shape of the raw output per-inference: if both scores are within
  /// [0,1] and sum ≈ 1, treat them as probabilities; otherwise apply a
  /// numerically stable softmax. This is the safe default while the exact export
  /// of the .tflite model is unverified (PHASE 2).
  auto,

  /// Raw output is already normalized probabilities in range [0.0, 1.0] where sum ≈ 1.0.
  probabilities,

  /// Raw output contains unnormalized logits that require stable softmax.
  logits,
}
