/// High-level detection mode.
enum DetectionMode {
  /// Emulates legacy Java Android logic for exact parity and debug comparison.
  javaCompatible,

  /// Enhanced modern pipeline with temporal smoothing and robust confidence filtering.
  improved,
}
