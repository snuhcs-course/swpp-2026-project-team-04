// Emit causal cycle windows from the same detector used by the app.
// dart --packages=gymrats_app/.dart_tool/package_config.json tools/diagnose/pushup_span_events.dart INPUT OUTPUT [pitch]
import 'dart:convert';
import 'dart:io';

import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

Future<void> main(List<String> args) async {
  final input = File(args[0]), output = File(args[1]);
  if (output.existsSync()) throw StateError('Choose a new window file');
  final degrees = args.length > 2 ? double.tryParse(args[2]) : null;
  final spans = args.length > 3
      ? args[3].split(',').map(double.parse).toList()
      : [.12, .16, .20, .24];
  final sink = output.openWrite();
  await for (final line
      in input
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    final source = jsonDecode(line) as Map;
    final detectors = {
      for (final span in spans) span: PushupSpanDetector(minSpan: span),
    };
    final windows = {
      for (final span in detectors.keys) span.toString(): <List<int>>[],
    };
    final indexAt = <Duration, int>{};
    final trace = <List<int>>[];
    var now = Duration.zero;
    final primary = RepJudge(clock: () => now);
    final width = (source['width'] as num).toDouble(),
        height = (source['height'] as num).toDouble();
    for (final raw in source['frames'] as List) {
      final index = raw[0] as int;
      final time = source['time_unit'] == 'us'
          ? Duration(microseconds: raw[1] as int)
          : Duration(milliseconds: raw[1] as int);
      indexAt[time] = index;
      now = time;
      if (raw.length > 3 && raw[3] == 'abandon') {
        for (final detector in detectors.values) {
          detector.reset();
        }
        primary.abandon();
        continue;
      }
      final points = <BodyLandmark, Keypoint>{};
      final coords = raw[2] as List?;
      if (coords != null) {
        for (var i = 0; i < coords.length; i++) {
          final p = coords[i] as List?;
          if (p == null) continue;
          final joint = BodyLandmark.values[i];
          points[joint] = Keypoint(
            landmark: joint,
            x: (p[0] as num).toDouble(),
            y: (p[1] as num).toDouble(),
            likelihood: (p[2] as num).toDouble(),
          );
        }
      }
      final pose = PoseFrame(
        imageWidth: width,
        imageHeight: height,
        keypoints: points,
      );
      primary.updateWithPhoneTilt(pose, degrees);
      final open = primary.openPrimaryAttempt;
      if (open != null) trace.add([index, indexAt[open]!]);
      for (final entry in detectors.entries) {
        final cycle = entry.value.update(
          pose,
          time,
          phoneAngleDegrees: degrees,
        );
        if (cycle != null)
          windows[entry.key.toString()]!.add([
            indexAt[cycle.start]!,
            indexAt[cycle.bottom]!,
            index,
          ]);
      }
    }
    sink.writeln(
      jsonEncode({
        'source_id': source['source_id'],
        'windows': windows,
        'primary_open': trace,
      }),
    );
  }
  await sink.close();
}
