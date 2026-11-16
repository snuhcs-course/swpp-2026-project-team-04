// Offline replay of JPEG video frames through the app's ML Kit model and judge.
// Run only as a separate diagnostic entry point, never as the shipping app.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

const folder =
    '/storage/emulated/0/Android/data/com.gymrats.pose_video_eval/files/pose_eval';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Video pose evaluation running')),
      ),
    ),
  );
  final manifest =
      jsonDecode(await File('$folder/manifest.json').readAsString()) as List;
  final results = <Object>[];
  for (final rawClip in manifest) {
    final clip = rawClip as Map<String, dynamic>;
    final detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
    var time = Duration.zero;
    final judge = RepJudge(clock: () => time);
    final records = <Object>[];
    for (final raw in clip['frames'] as List) {
      final frame = raw as Map<String, dynamic>;
      time = Duration(milliseconds: frame['ms'] as int);
      final poses = await detector.processImage(
        InputImage.fromFilePath('$folder/${frame['file']}'),
      );
      final pose = PoseFrame(
        imageWidth: (clip['width'] as num).toDouble(),
        imageHeight: (clip['height'] as num).toDouble(),
        keypoints: poses.isEmpty
            ? {}
            : {
                for (final l in poses.first.landmarks.values)
                  BodyLandmark.values[l.type.index]: Keypoint(
                    landmark: BodyLandmark.values[l.type.index],
                    x: l.x,
                    y: l.y,
                    z: l.z,
                    likelihood: l.likelihood,
                  ),
              },
      );
      final update = judge.update(pose);
      final event = update.event;
      records.add({
        'ms': time.inMilliseconds,
        'keypoints': {
          for (final entry in pose.keypoints.entries)
            entry.key.name: [
              entry.value.x,
              entry.value.y,
              entry.value.z,
              entry.value.likelihood,
            ],
        },
        'phase': update.snapshot.phase.name,
        'depth': update.snapshot.depth,
        'elbow': update.snapshot.elbowAngle,
        if (event != null)
          'event': {
            'valid': event.valid,
            'reason': event.reason?.name,
            'maxDepth': event.maxDepth,
            'minElbowAngle': event.minElbowAngle,
          },
      });
    }
    await detector.close();
    results.add({
      'clip': clip['clip'],
      'width': clip['width'],
      'height': clip['height'],
      'frames': records,
    });
    await File('$folder/results.json').writeAsString(jsonEncode(results));
    await Process.run('/system/bin/chmod', ['644', '$folder/results.json']);
    debugPrint('POSE_EVAL_DONE ${clip['clip']} ${records.length} frames');
  }
  await File('$folder/complete.txt').writeAsString('complete');
}
