/// Region of Interest (ROI) extraction strategies for drowsiness detection.
enum RoiStrategy {
  /// Legacy fallback: fixed 224x224 crop from center of camera frame.
  legacyCenterCrop,

  /// Full face crop containing entire driver face.
  fullFace,

  /// Eye-band crop focused tightly on both eyes using facial landmarks.
  eyeBand,
}
