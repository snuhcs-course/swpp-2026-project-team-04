import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/widgets/battle_camera_view.dart';
import 'package:gymrats_app/widgets/pose_silhouette_phone_angle.dart';

void main() {
  testWidgets('the display and sensor listener exist only in UAT builds', (
    tester,
  ) async {
    var listens = 0;
    var cancels = 0;
    final samples = StreamController<GravitySample>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    addTearDown(samples.close);
    final monitor = PhoneTiltMonitor(samples: samples.stream);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UatPhoneAngle(monitor: monitor)),
      ),
    );
    if (!uatPhoneAngleEnabled) {
      expect(listens, 0);
      expect(find.textContaining('폰 각도:'), findsNothing);
      return;
    }
    expect(listens, 1);
    expect(find.text('폰 각도: 측정 중'), findsOneWidget);
    GravitySample sample(double angle) {
      final radians = angle * math.pi / 180;
      return GravitySample(9.8 * math.sin(radians), 0, 9.8 * math.cos(radians));
    }

    samples.add(sample(60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('폰 각도: 60.0°'), findsOneWidget);
    samples.add(sample(45));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('폰 각도: 45.0°'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('폰 각도: 측정 중'), findsOneWidget);
    samples.add(const GravitySample(0, 0, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('폰 각도: 측정 중'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(cancels, 1);
  });
  testWidgets('lifecycle and disposal keep another monitor user subscribed', (
    tester,
  ) async {
    if (!uatPhoneAngleEnabled) return;
    var cancels = 0;
    final samples = StreamController<GravitySample>.broadcast(
      onCancel: () => cancels++,
    );
    addTearDown(samples.close);
    final monitor = PhoneTiltMonitor(samples: samples.stream);
    monitor.retain();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UatPhoneAngle(monitor: monitor)),
      ),
    );
    samples.add(GravitySample(9.8 * math.sin(math.pi / 3), 0, 4.9));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('폰 각도: 60.0°'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    // The paused binding does not render; inspect after resuming.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('폰 각도: 측정 중'), findsOneWidget);
    samples.add(GravitySample(4.9, 0, 9.8 * math.cos(math.pi / 6)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('폰 각도: 30.0°'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(cancels, 0);
    monitor.release();
    await tester.pump();
    expect(cancels, 1);
  });

  for (final exercise in ExerciseType.values) {
    testWidgets('battle setup displays live angle for $exercise only in UAT', (
      tester,
    ) async {
      final samples = StreamController<GravitySample>.broadcast();
      PhoneTiltMonitor.debugUsePlatformStream(samples.stream);
      addTearDown(() async {
        PhoneTiltMonitor.debugUsePlatformStream(null);
        await samples.close();
      });
      final guide = BattleCameraView.setupGuide(exercise, ready: false)!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BattleCameraView(
                controller: null,
                guide: guide.widget,
                guideFit: guide.fit,
              ),
            ),
          ),
        ),
      );
      if (uatPhoneAngleEnabled) {
        expect(find.text('폰 각도: 측정 중'), findsOneWidget);
        samples.add(GravitySample(9.8 * math.sin(math.pi / 3), 0, 4.9));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('폰 각도: 60.0°'), findsOneWidget);
      } else {
        expect(find.textContaining('폰 각도:'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(find.textContaining('폰 각도:'), findsNothing);
    });
  }
}
