/// Detection pipeline implementation choice.
enum DetectionPipeline {
  /// Center 224x224 crop directly from camera preview stream (Java reference behavior).
  legacyCenterCrop,

  /// Face & eye region crop pipeline (Phase 2 enhancement).
  faceAware,
}

/// Tensor memory layout for the 3 color channels.
enum TensorChannelLayout {
  /// Planar RGB: All R pixels, then all G pixels, then all B pixels (RRRR...GGGG...BBBB...)
  /// Exactly matches original Java implementation.
  planarRgb,

  /// Standard interleaved RGB: R, G, B, R, G, B...
  interleavedRgb,
}
