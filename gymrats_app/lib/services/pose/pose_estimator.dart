import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../models/pose_frame.dart';

/// Runs ML Kit pose detection on camera frames, one frame at a time.
class PoseEstimator {
  PoseEstimator({PoseDetector? detector})
    : _detector =
          detector ??
          PoseDetector(
            options: PoseDetectorOptions(
              mode: PoseDetectionMode.stream,
              model: PoseDetectionModel.base,
            ),
          );

  final PoseDetector _detector;
  bool _busy = false;
  Future<void>? _closing;
  Future<List<Pose>>? _inFlight;

  bool get _closed => _closing != null;

  /// Whether a frame is being processed right now.
  bool get isBusy => _busy;

  /// Detects the pose in [image].
  ///
  /// Returns null without processing when a frame is already in progress
  /// (the frame is dropped, never queued) or after [close].
  /// Throws if the frame format is unsupported or ML Kit fails.
  Future<PoseFrame?> process(CameraImage image, int rotationDegrees) async {
    if (_busy || _closed) return null;
    _busy = true;
    try {
      final input = _toInputImage(image, rotationDegrees);
      final poses = await (_inFlight = _detector.processImage(input));
      if (_closed) return null;
      final upright = _uprightSize(image, rotationDegrees);
      if (poses.isEmpty) {
        return PoseFrame.empty(
          imageWidth: upright.width,
          imageHeight: upright.height,
        );
      }
      return PoseFrame(
        imageWidth: upright.width,
        imageHeight: upright.height,
        keypoints: {
          for (final l in poses.first.landmarks.values)
            // BodyLandmark follows ML Kit's order (see pose_frame_test.dart).
            BodyLandmark.values[l.type.index]: Keypoint(
              landmark: BodyLandmark.values[l.type.index],
              x: l.x,
              y: l.y,
              z: l.z,
              likelihood: l.likelihood,
            ),
        },
      );
    } finally {
      _busy = false;
      _inFlight = null;
    }
  }

  /// Releases the ML Kit detector after the frame in progress, if any,
  /// has finished. Safe to call twice.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // The frame's error is reported by process(); only wait here.
      }
    }
    await _detector.close();
  }

  InputImage _toInputImage(CameraImage image, int rotationDegrees) {
    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (rotation == null ||
        format != InputImageFormat.nv21 ||
        image.planes.length != 1) {
      throw UnsupportedError(
        'Unsupported camera frame: format ${image.format.raw}, '
        '${image.planes.length} planes, rotation $rotationDegrees',
      );
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// ML Kit reports landmarks in the rotated (upright) image.
  static Size _uprightSize(CameraImage image, int rotationDegrees) {
    final w = image.width.toDouble(), h = image.height.toDouble();
    return rotationDegrees == 90 || rotationDegrees == 270
        ? Size(h, w)
        : Size(w, h);
  }
}
