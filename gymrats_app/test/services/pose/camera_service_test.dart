import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);
const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

/// Controller that never touches the platform. [initialize] waits for
/// [initGate] so tests can interleave other calls.
class _FakeController extends CameraController {
  _FakeController(CameraDescription description)
    : super(description, ResolutionPreset.medium);

  final Completer<void> initGate = Completer();
  Object? initError;
  bool streaming = false;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    await initGate.future;
    if (initError != null) throw initError!;
  }

  @override
  Future<void> startImageStream(onLatestImageAvailable onAvailable) async {
    if (disposed) throw CameraException('Disposed CameraController', '');
    streaming = true;
    value = value.copyWith(isStreamingImages: true);
  }

  @override
  Future<void> stopImageStream() async {
    streaming = false;
    value = value.copyWith(isStreamingImages: false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    streaming = false;
    await super.dispose();
  }
}

void main() {
  late List<_FakeController> controllers;
  late List<CameraDescription> cameras;
  late CameraService service;

  setUp(() {
    controllers = [];
    cameras = [_front, _back];
    service = CameraService(
      listCameras: () async => cameras,
      createController: (d) {
        final c = _FakeController(d);
        controllers.add(c);
        return c;
      },
    );
  });

  void onImage(CameraImage _) {}

  test('starts the front camera and streams', () async {
    final starting = service.start(onImage);
    await pumpEventQueue();
    controllers.single.initGate.complete();
    await starting;
    expect(controllers.single.description, _front);
    expect(controllers.single.streaming, isTrue);
    expect(service.controller, controllers.single);
    expect(service.isFrontCamera, isTrue);
  });

  test('stop releases the camera', () async {
    final starting = service.start(onImage);
    await pumpEventQueue();
    controllers.single.initGate.complete();
    await starting;
    await service.stop();
    await service.stop();
    expect(controllers.single.disposed, isTrue);
    expect(service.controller, isNull);
  });

  test('stop during initialize releases the camera without an error', () async {
    final starting = service.start(onImage);
    await pumpEventQueue();
    final stopping = service.stop();
    controllers.single.initGate.complete();
    await starting;
    await stopping;
    expect(controllers.single.disposed, isTrue);
    expect(controllers.single.streaming, isFalse);
    expect(service.controller, isNull);
  });

  test(
    'stop before the camera list arrives still releases the camera',
    () async {
      final list = Completer<List<CameraDescription>>();
      service = CameraService(
        listCameras: () => list.future,
        createController: (d) {
          final c = _FakeController(d)..initGate.complete();
          controllers.add(c);
          return c;
        },
      );
      final starting = service.start(onImage);
      final stopping = service.stop();
      list.complete(cameras);
      await starting;
      await stopping;
      expect(controllers.single.disposed, isTrue);
      expect(service.controller, isNull);
    },
  );

  test('overlapping starts leave only one camera open', () async {
    final first = service.start(onImage);
    final second = service.start(onImage);
    await pumpEventQueue();
    controllers.first.initGate.complete();
    await pumpEventQueue();
    controllers.last.initGate.complete();
    await first;
    await second;
    expect(controllers, hasLength(2));
    expect(controllers.first.disposed, isTrue);
    expect(controllers.last.streaming, isTrue);
  });

  test('no camera throws CameraUnavailableException', () async {
    cameras = [];
    await expectLater(
      service.start(onImage),
      throwsA(isA<CameraUnavailableException>()),
    );
  });

  test('an empty camera list is not cached, so retry can succeed', () async {
    cameras = [];
    await expectLater(
      service.start(onImage),
      throwsA(isA<CameraUnavailableException>()),
    );
    cameras = [_front];
    final starting = service.start(onImage);
    await pumpEventQueue();
    controllers.single.initGate.complete();
    await starting;
    expect(controllers.single.streaming, isTrue);
  });

  test('non-camera errors are wrapped and release the camera', () async {
    final starting = service.start(onImage);
    await pumpEventQueue();
    controllers.single
      ..initError = StateError('platform failure')
      ..initGate.complete();
    await expectLater(starting, throwsA(isA<CameraUnavailableException>()));
    expect(controllers.single.disposed, isTrue);
    expect(service.controller, isNull);
  });

  test('init failure throws CameraUnavailableException and releases', () async {
    final starting = service.start(onImage);
    await pumpEventQueue();
    controllers.single
      ..initError = CameraException('CameraAccessDenied', 'denied')
      ..initGate.complete();
    await expectLater(starting, throwsA(isA<CameraUnavailableException>()));
    expect(controllers.single.disposed, isTrue);
  });

  test('selectNextCamera switches to the back camera', () async {
    var starting = service.start(onImage);
    await pumpEventQueue();
    controllers.last.initGate.complete();
    await starting;
    service.selectNextCamera();
    starting = service.start(onImage);
    await pumpEventQueue();
    controllers.last.initGate.complete();
    await starting;
    expect(controllers.last.description, _back);
    expect(service.isFrontCamera, isFalse);
  });

  group('rotationFor', () {
    int rotation(int sensor, CameraLensDirection lens, DeviceOrientation d) =>
        CameraService.rotationFor(
          sensorOrientation: sensor,
          lens: lens,
          device: d,
        );

    test('portrait uses the sensor orientation', () {
      expect(
        rotation(270, CameraLensDirection.front, DeviceOrientation.portraitUp),
        270,
      );
      expect(
        rotation(90, CameraLensDirection.back, DeviceOrientation.portraitUp),
        90,
      );
    });

    test('landscape compensates in opposite directions per lens', () {
      expect(
        rotation(
          270,
          CameraLensDirection.front,
          DeviceOrientation.landscapeLeft,
        ),
        0,
      );
      expect(
        rotation(90, CameraLensDirection.back, DeviceOrientation.landscapeLeft),
        0,
      );
      expect(
        rotation(
          270,
          CameraLensDirection.front,
          DeviceOrientation.landscapeRight,
        ),
        180,
      );
      expect(
        rotation(
          90,
          CameraLensDirection.back,
          DeviceOrientation.landscapeRight,
        ),
        180,
      );
    });
  });
}
