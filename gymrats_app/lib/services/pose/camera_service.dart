import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera permission result, independent of the permission plugin.
enum CameraPermission { granted, denied, permanentlyDenied }

/// Thrown when no camera is available or the camera fails to start.
class CameraUnavailableException implements Exception {
  const CameraUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'CameraUnavailableException: $message';
}

/// Owns the [CameraController] lifecycle and its image stream.
///
/// Frames stay on the device: they are only handed to [start]'s callback.
///
/// [start] and [stop] run one after another, never interleaved, so a stop
/// requested while the camera is still opening releases it afterwards. The
/// order holds across every instance: the Android camera plugin keeps one
/// camera for the whole app, and disposing any controller releases whichever
/// camera is open. A screen that opens its camera while the previous screen
/// is still closing would otherwise lose its preview and frames.
class CameraService {
  CameraService({
    this.preferredLens = CameraLensDirection.front,
    Future<List<CameraDescription>> Function()? listCameras,
    CameraController Function(CameraDescription description)? createController,
  }) : _listCameras = listCameras ?? availableCameras,
       _createController = createController ?? _defaultController;

  /// Lens used on the first [start].
  final CameraLensDirection preferredLens;

  final Future<List<CameraDescription>> Function() _listCameras;
  final CameraController Function(CameraDescription) _createController;
  static Future<void> _lastOperation = Future.value();

  List<CameraDescription>? _cameras;
  CameraDescription? _current;
  CameraController? _controller;

  /// The active controller, for the preview. Null while stopped.
  CameraController? get controller => _controller;

  bool get isFrontCamera =>
      (_current?.lensDirection ?? preferredLens) == CameraLensDirection.front;

  /// Whether a second camera exists to switch to.
  bool get canSwitchCamera => (_cameras?.length ?? 0) > 1;

  /// Asks for camera permission if it has not been decided yet.
  Future<CameraPermission> requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return CameraPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermission.permanentlyDenied;
    }
    return CameraPermission.denied;
  }

  /// Opens the system settings page for this app.
  Future<bool> openSettings() => openAppSettings();

  /// Opens the camera and streams frames to [onImage].
  ///
  /// Throws [CameraUnavailableException] if there is no camera or it fails
  /// to start.
  Future<void> start(void Function(CameraImage image) onImage) =>
      _serialized(() => _start(onImage));

  /// Stops the image stream and releases the camera. Safe to call twice.
  Future<void> stop() => _serialized(_stop);

  Future<void> _serialized(Future<void> Function() operation) {
    final result = _lastOperation.then((_) => operation());
    _lastOperation = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  static CameraController _defaultController(CameraDescription description) =>
      CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        // ML Kit on Android expects NV21 bytes.
        imageFormatGroup: ImageFormatGroup.nv21,
      );

  Future<void> _start(void Function(CameraImage image) onImage) async {
    await _stop();
    try {
      final cameras = _cameras ?? await _listCameras();
      if (cameras.isEmpty) {
        throw const CameraUnavailableException('No camera found.');
      }
      _cameras = cameras;
      final description = _current ??= cameras.firstWhere(
        (c) => c.lensDirection == preferredLens,
        orElse: () => cameras.first,
      );
      final controller = _createController(description);
      _controller = controller;
      await controller.initialize();
      await controller.startImageStream(onImage);
    } on CameraUnavailableException {
      rethrow;
    } on CameraException catch (e) {
      await _stop();
      throw CameraUnavailableException(e.description ?? e.code);
    } catch (e) {
      await _stop();
      throw CameraUnavailableException('$e');
    }
  }

  /// Uses the next camera on the following [start].
  void selectNextCamera() {
    final cameras = _cameras;
    if (cameras == null || cameras.length < 2) return;
    final index = _current == null ? 0 : cameras.indexOf(_current!);
    _current = cameras[(index + 1) % cameras.length];
  }

  Future<void> _stop() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } on CameraException {
      // The controller is disposed below either way.
    }
    try {
      await controller.dispose();
    } on CameraException {
      // Already released by the plugin; the next start opens a new camera.
    } on PlatformException {
      // Same, reported by the Android plugin as a platform error.
    }
  }

  /// Rotation to apply to camera frames so they are upright, in degrees.
  int get rotationDegrees {
    final controller = _controller;
    if (controller == null) return 0;
    return rotationFor(
      sensorOrientation: controller.description.sensorOrientation,
      lens: controller.description.lensDirection,
      device: controller.value.deviceOrientation,
    );
  }

  /// Frame rotation for a sensor mounted at [sensorOrientation] degrees
  /// while the device is held in [device] orientation.
  static int rotationFor({
    required int sensorOrientation,
    required CameraLensDirection lens,
    required DeviceOrientation device,
  }) {
    final deviceDegrees = _deviceDegrees[device] ?? 0;
    return lens == CameraLensDirection.front
        ? (sensorOrientation + deviceDegrees) % 360
        : (sensorOrientation - deviceDegrees + 360) % 360;
  }

  static const _deviceDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
}
