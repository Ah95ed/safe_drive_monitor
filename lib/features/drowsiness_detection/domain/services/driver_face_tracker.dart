import 'dart:math';
import 'dart:ui';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_face.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/roi_strategy.dart';

/// Service responsible for selecting, tracking, smoothing, and validating the driver's face.
class DriverFaceTracker {
  final Duration faceLossTimeout;
  final double smoothingFactor; // EMA alpha [0.0 - 1.0]

  int? _activeTrackingId;
  DriverFace? _lastValidFace;
  Rect? _smoothedEyeRoi;
  Rect? _smoothedFaceBox;
  DateTime? _lastDetectedTimestamp;
  int _consecutiveStableDetections = 0;
  int _currentEpoch = 0;

  DriverFaceTracker({
    // Keep the tracked ROI usable during background audio/inference load.
    // 2500ms provides stability against dropped frames while avoiding stale lock.
    this.faceLossTimeout = const Duration(milliseconds: 2500),
    this.smoothingFactor = 0.35, // 35% new, 65% previous for smooth transitions
  });

  int? get activeTrackingId => _activeTrackingId;
  DriverFace? get lastValidFace => _lastValidFace;
  Rect? get currentEyeRoi => _smoothedEyeRoi;
  Rect? get currentFaceBox => _smoothedFaceBox;
  int get consecutiveStableDetections => _consecutiveStableDetections;
  int get currentEpoch => _currentEpoch;
  bool get isTrackingStable => _consecutiveStableDetections >= 2 && _activeTrackingId != null;

  /// Check if the driver face is currently active, within freshness timeout, and matches active epoch.
  bool isDriverFaceActive(DateTime now, {int? epoch}) {
    if (_lastDetectedTimestamp == null || _smoothedEyeRoi == null) {
      return false;
    }
    if (epoch != null && _lastValidFace?.lifecycleEpoch != epoch) {
      return false;
    }
    return now.difference(_lastDetectedTimestamp!) <= faceLossTimeout;
  }

  /// Check if the cached ROI is fresh enough for low-frequency ML Kit cycles and matches active epoch.
  bool isRoiFresh(
    DateTime now, {
    Duration maxFreshDuration = const Duration(milliseconds: 900),
    int? epoch,
  }) {
    if (_lastDetectedTimestamp == null || _smoothedEyeRoi == null) return false;
    if (epoch != null && _lastValidFace?.lifecycleEpoch != epoch) return false;
    return now.difference(_lastDetectedTimestamp!) <= maxFreshDuration;
  }

  /// Resets the tracker (e.g. at session start/stop or lifecycle epoch boundary).
  void reset([int? epoch]) {
    _activeTrackingId = null;
    _lastValidFace = null;
    _smoothedEyeRoi = null;
    _smoothedFaceBox = null;
    _lastDetectedTimestamp = null;
    _consecutiveStableDetections = 0;
    if (epoch != null) {
      _currentEpoch = epoch;
    }
  }

  /// Updates tracking with a list of detected candidate faces from the camera frame.
  DriverFace? update(
    List<DriverFace> detectedFaces, {
    required DateTime timestamp,
    RoiStrategy roiStrategy = RoiStrategy.eyeBand,
    int lifecycleEpoch = 0,
  }) {
    // If epoch changed across lifecycle boundary, invalidate previous epoch state immediately
    if (lifecycleEpoch != _currentEpoch) {
      _currentEpoch = lifecycleEpoch;
      _activeTrackingId = null;
      _lastValidFace = null;
      _smoothedEyeRoi = null;
      _smoothedFaceBox = null;
      _lastDetectedTimestamp = null;
      _consecutiveStableDetections = 0;
    }

    if (detectedFaces.isEmpty) {
      _consecutiveStableDetections = 0;
      if (!isDriverFaceActive(timestamp, epoch: lifecycleEpoch)) {
        _smoothedEyeRoi = null;
        _smoothedFaceBox = null;
        _activeTrackingId = null;
      }
      return isDriverFaceActive(timestamp, epoch: lifecycleEpoch) ? _lastValidFace : null;
    }

    // 1. Select the driver face from candidates
    DriverFace selectedFace;

    if (_activeTrackingId != null) {
      // Find candidate matching active tracking ID
      final match = detectedFaces.firstWhere(
        (f) => f.trackingId == _activeTrackingId,
        orElse: () => _findBestSpatialMatch(detectedFaces, _smoothedFaceBox),
      );
      if (match.trackingId == _activeTrackingId) {
        _consecutiveStableDetections++;
      } else {
        _consecutiveStableDetections = 1;
      }
      selectedFace = match;
    } else {
      // First acquisition: select the dominant (largest / most centered) face
      selectedFace = _selectDominantFace(detectedFaces);
      _consecutiveStableDetections = 1;
    }

    _activeTrackingId = selectedFace.trackingId;
    _lastDetectedTimestamp = timestamp;

    // 2. Smooth the face bounding box
    _smoothedFaceBox = _smoothRect(_smoothedFaceBox, selectedFace.boundingBox);

    // 3. Compute and smooth the target ROI according to strategy
    final rawRoi = _computeTargetRoi(selectedFace, roiStrategy);
    _smoothedEyeRoi = _smoothRect(_smoothedEyeRoi, rawRoi);

    _lastValidFace = DriverFace(
      trackingId: selectedFace.trackingId,
      boundingBox: _smoothedFaceBox!,
      eyeRoi: _smoothedEyeRoi!,
      leftEye: selectedFace.leftEye,
      rightEye: selectedFace.rightEye,
      headEulerAngleX: selectedFace.headEulerAngleX,
      headEulerAngleY: selectedFace.headEulerAngleY,
      headEulerAngleZ: selectedFace.headEulerAngleZ,
      leftEyeOpenProbability: selectedFace.leftEyeOpenProbability,
      rightEyeOpenProbability: selectedFace.rightEyeOpenProbability,
      detectedAt: timestamp,
      lifecycleEpoch: lifecycleEpoch,
    );

    return _lastValidFace;
  }

  /// Selects the dominant driver face (largest area).
  DriverFace _selectDominantFace(List<DriverFace> faces) {
    if (faces.length == 1) return faces.first;

    DriverFace dominant = faces.first;
    double maxArea = dominant.boundingBox.width * dominant.boundingBox.height;

    for (int i = 1; i < faces.length; i++) {
      final area = faces[i].boundingBox.width * faces[i].boundingBox.height;
      if (area > maxArea) {
        dominant = faces[i];
        maxArea = area;
      }
    }
    return dominant;
  }

  /// Finds the candidate closest to the previous known face position via IoU / center distance.
  DriverFace _findBestSpatialMatch(List<DriverFace> faces, Rect? lastBox) {
    if (lastBox == null || faces.length == 1) return _selectDominantFace(faces);

    DriverFace bestMatch = faces.first;
    double minDistance = double.infinity;

    final lastCenter = lastBox.center;

    for (final face in faces) {
      final currentCenter = face.boundingBox.center;
      final distance = (currentCenter.dx - lastCenter.dx) * (currentCenter.dx - lastCenter.dx) +
          (currentCenter.dy - lastCenter.dy) * (currentCenter.dy - lastCenter.dy);
      if (distance < minDistance) {
        minDistance = distance;
        bestMatch = face;
      }
    }
    return bestMatch;
  }

  /// Computes target ROI based on face geometry and landmarks.
  Rect _computeTargetRoi(DriverFace face, RoiStrategy strategy) {
    switch (strategy) {
      case RoiStrategy.fullFace:
        // Pad the tight ML Kit box outward (~12% sides, ~18% vertical) so the
        // crop includes brow/jaw context the classifier expects.
        final box = face.boundingBox;
        final padX = box.width * 0.12;
        final padY = box.height * 0.18;
        return Rect.fromLTRB(
          box.left - padX,
          box.top - padY,
          box.right + padX,
          box.bottom + padY,
        );

      case RoiStrategy.legacyCenterCrop:
        return face.boundingBox;

      case RoiStrategy.eyeBand:
        if (face.hasEyeLandmarks) {
          // Precise eye-band computed from left and right eye points
          final p1 = face.leftEye!;
          final p2 = face.rightEye!;

          final minX = min(p1.x, p2.x).toDouble();
          final maxX = max(p1.x, p2.x).toDouble();
          final minY = min(p1.y, p2.y).toDouble();
          final maxY = max(p1.y, p2.y).toDouble();

          final eyeWidth = (maxX - minX);
          final eyeHeight = max(18.0, (maxY - minY));

          // Apply padding around eye zone: 45% horizontal, 70% vertical
          final padX = eyeWidth * 0.45;
          final padY = max(eyeWidth * 0.35, eyeHeight * 1.2);

          return Rect.fromLTRB(
            minX - padX,
            minY - padY,
            maxX + padX,
            maxY + padY,
          );
        } else {
          // Fallback eye band: upper 20% to 55% region of the face bounding box
          final box = face.boundingBox;
          final top = box.top + box.height * 0.18;
          final bottom = box.top + box.height * 0.58;
          return Rect.fromLTRB(box.left, top, box.right, bottom);
        }
    }
  }

  /// Applies Exponential Moving Average (EMA) smoothing to a rectangle.
  Rect _smoothRect(Rect? previous, Rect target) {
    if (previous == null) return target;

    final left = previous.left + (target.left - previous.left) * smoothingFactor;
    final top = previous.top + (target.top - previous.top) * smoothingFactor;
    final right = previous.right + (target.right - previous.right) * smoothingFactor;
    final bottom = previous.bottom + (target.bottom - previous.bottom) * smoothingFactor;

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
