import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../models/pose_frame.dart';
import 'camera_service.dart' show iosFramesMirrored;

/// Runs ML Kit pose detection on camera frames, one frame at a time.
///
/// Uses the accurate model: on the H1 push-up recordings the base model
/// read a straight plank's hip at 127-139° (accurate: 157-170°), which
/// rejected every normal rep as knees, and accurate still ran at 23-25 fps
/// against 27 for base on the SM-S741N used for the recordings.
class PoseEstimator {
  PoseEstimator({PoseDetector? detector})
    : _detector =
          detector ??
          PoseDetector(
            options: PoseDetectorOptions(
              mode: PoseDetectionMode.stream,
              model: PoseDetectionModel.accurate,
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
        (format != InputImageFormat.nv21 &&
            format != InputImageFormat.bgra8888) ||
        image.planes.length != 1) {
      throw UnsupportedError(
        'Unsupported camera frame: format ${image.format.raw}, '
        '${image.planes.length} planes, rotation $rotationDegrees',
      );
    }
    final plane = image.planes.first;
    // The iOS plugin ignores the rotation, so turn the frame upright here.
    if (Platform.isIOS && rotationDegrees != 0) {
      final upright = _rotateBgra(
        plane.bytes,
        image.width,
        image.height,
        plane.bytesPerRow,
        rotationDegrees,
      );
      final turned = rotationDegrees == 90 || rotationDegrees == 270;
      final w = turned ? image.height : image.width;
      final h = turned ? image.width : image.height;
      return InputImage.fromBytes(
        bytes: upright,
        metadata: InputImageMetadata(
          size: Size(w.toDouble(), h.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: format!,
          bytesPerRow: w * 4,
        ),
      );
    }
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

  /// BGRA [bytes] of a [width]x[height] frame turned [degrees] clockwise.
  static Uint8List _rotateBgra(
    Uint8List bytes,
    int width,
    int height,
    int bytesPerRow,
    int degrees,
  ) {
    // Copy first: the plane may not start on a 4-byte boundary.
    final aligned = Uint8List(bytesPerRow * height)
      ..setRange(0, bytesPerRow * height, bytes);
    final src = aligned.buffer.asUint32List();
    final stride = bytesPerRow ~/ 4;
    final turned = degrees == 90 || degrees == 270;
    final outW = turned ? height : width;
    final out = Uint32List(width * height);
    for (var y = 0; y < height; y++) {
      final row = y * stride;
      for (var x = 0; x < width; x++) {
        final int nx, ny;
        switch (degrees) {
          case 90:
            nx = height - 1 - y;
            ny = x;
          case 180:
            nx = width - 1 - x;
            ny = height - 1 - y;
          default: // 270
            nx = y;
            ny = width - 1 - x;
        }
        out[ny * outW + (iosFramesMirrored ? outW - 1 - nx : nx)] =
            src[row + x];
      }
    }
    return out.buffer.asUint8List();
  }

  /// ML Kit reports landmarks in the rotated (upright) image.
  static Size _uprightSize(CameraImage image, int rotationDegrees) {
    final w = image.width.toDouble(), h = image.height.toDouble();
    return rotationDegrees == 90 || rotationDegrees == 270
        ? Size(h, w)
        : Size(w, h);
  }
}

/// A conservative continuity check, not biometric identification.
///
/// ML Kit supplies one pose and no identity. Once a user has finished setup,
/// an abrupt position/size change or prolonged loss suspends scoring until a
/// person explicitly confirms who is in front of the camera. Similar or
/// gradual substitutions cannot be distinguished by this geometry alone.
class PersonContinuityGuard {
  static const maxGap = Duration(milliseconds: 750);
  static const _scaleChangeHold = Duration(milliseconds: 200);
  _PersonAnchor? _previous;
  _PersonAnchor? _candidate;
  Duration? _lastGood;
  Duration? _candidateAt;
  Duration? _scaleMismatchSince;
  bool _enabled = false;
  bool needsConfirmation = false;
  bool get enabled => _enabled;

  /// Camera restarts cannot silently transfer the tracked person.
  void invalidate() {
    if (!_enabled) return;
    needsConfirmation = true;
    _candidate = null;
    _candidateAt = null;
    _scaleMismatchSince = null;
  }

  void begin(PoseFrame? frame, Duration now) {
    _enabled = true;
    _previous = frame == null ? null : _PersonAnchor.fromFrame(frame);
    _candidate = _previous;
    _lastGood = _previous == null ? null : now;
    _candidateAt = _lastGood;
    _scaleMismatchSince = null;
    needsConfirmation = _previous == null;
  }

  /// False means do not score this frame. A brief partial pose is dropped;
  /// a longer loss or large jump additionally requires user confirmation.
  bool accepts(PoseFrame frame, Duration now) {
    if (!_enabled) return true;
    final next = _PersonAnchor.fromFrame(frame);
    _candidate = next;
    _candidateAt = next == null ? null : now;
    if (needsConfirmation) return false;
    final previous = _previous;
    final lastGood = _lastGood;
    if (next == null) {
      _scaleMismatchSince = null;
      if (lastGood == null || now - lastGood > maxGap) {
        needsConfirmation = true;
      }
      return false;
    }
    if (previous == null ||
        lastGood == null ||
        now - lastGood > maxGap ||
        now < lastGood ||
        !previous.near(next)) {
      needsConfirmation = true;
      return false;
    }
    if (!previous.similarScale(next)) {
      // ML Kit can briefly collapse one shoulder into the other during a
      // normal rep. Never score that frame or adopt its scale as the anchor.
      // A persistent scale change still needs explicit user confirmation;
      // position jumps and long losses above remain immediately latched.
      _scaleMismatchSince ??= now;
      if (now - _scaleMismatchSince! >= _scaleChangeHold) {
        needsConfirmation = true;
      }
      return false;
    }
    _scaleMismatchSince = null;
    _previous = next;
    _lastGood = now;
    return true;
  }

  /// Latch a stalled stream even when no further frame arrives.
  bool expire(Duration now) {
    final last = _lastGood;
    if (!_enabled ||
        needsConfirmation ||
        last == null ||
        (now >= last && now - last <= maxGap)) {
      return false;
    }
    invalidate();
    return true;
  }

  /// The user must verify the camera view; never silently adopt a new pose.
  bool confirm(Duration now) {
    final next = _candidate;
    final at = _candidateAt;
    if (next == null || at == null || now < at || now - at > maxGap) {
      return false;
    }
    _previous = next;
    _lastGood = now;
    _scaleMismatchSince = null;
    needsConfirmation = false;
    return true;
  }

  void clear() {
    _enabled = false;
    _previous = _candidate = null;
    _lastGood = _candidateAt = null;
    _scaleMismatchSince = null;
    needsConfirmation = false;
  }
}

class _PersonAnchor {
  const _PersonAnchor(this.x, this.y, this.width);
  final double x, y, width;

  static _PersonAnchor? fromFrame(PoseFrame frame) {
    final l = frame[BodyLandmark.leftShoulder];
    final r = frame[BodyLandmark.rightShoulder];
    if (l == null ||
        r == null ||
        !l.likelihood.isFinite ||
        !r.likelihood.isFinite ||
        l.likelihood < .6 ||
        r.likelihood < .6 ||
        !l.x.isFinite ||
        !l.y.isFinite ||
        !r.x.isFinite ||
        !r.y.isFinite ||
        !frame.imageWidth.isFinite ||
        !frame.imageHeight.isFinite ||
        frame.imageWidth <= 0 ||
        frame.imageHeight <= 0 ||
        l.x < 0 ||
        l.x > frame.imageWidth ||
        l.y < 0 ||
        l.y > frame.imageHeight ||
        r.x < 0 ||
        r.x > frame.imageWidth ||
        r.y < 0 ||
        r.y > frame.imageHeight) {
      return null;
    }
    final scale = math.max(frame.imageWidth, frame.imageHeight);
    final width =
        math.sqrt(math.pow(l.x - r.x, 2) + math.pow(l.y - r.y, 2)) / scale;
    if (width < .015) return null;
    return _PersonAnchor(
      (l.x + r.x) / 2 / scale,
      (l.y + r.y) / 2 / scale,
      width,
    );
  }

  bool near(_PersonAnchor other) {
    final distance = math.sqrt(
      math.pow(x - other.x, 2) + math.pow(y - other.y, 2),
    );
    return distance <= math.max(.08, math.max(width, other.width));
  }

  bool similarScale(_PersonAnchor other) {
    final ratio = other.width / width;
    return ratio >= .5 && ratio <= 2.0;
  }
}
