/// Emits one feature vector per causal cycle. Only the caller supplies windows.
/// The separate trainer matches events to labels after feature extraction.
library;

import 'dart:convert';
import 'dart:io';

import '../../gymrats_app/lib/models/pose_frame.dart';
import '../../gymrats_app/lib/services/pose/pose_metrics.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3 ||
      args.length > 4 ||
      (args.length == 4 && args[3] != '--predict')) {
    throw ArgumentError(
      'Expected REPLAY.jsonl WINDOWS.jsonl OUTPUT.jsonl [--predict]',
    );
  }
  final windows = <String, Map<String, dynamic>>{};
  for (final line in File(args[1]).readAsLinesSync()) {
    final row = jsonDecode(line);
    windows[row['source_id'] as String] = row['windows'];
  }
  final sink = File(args[2]).openWrite();
  try {
    await for (final line in File(
      args[0],
    ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      final row = jsonDecode(line);
      final frames = row['frames'] as List;
      final times = {
        for (final f in frames)
          f[0] as int: (row['time_unit'] == 'us'
              ? Duration(microseconds: f[1] as int)
              : Duration(milliseconds: f[1] as int)),
      };
      final unique = <String>{};
      final ends = <int, List<List<int>>>{};
      for (final config in windows[row['source_id']]!.values) {
        for (final w in config) {
          final triple = List<int>.from(w);
          if (unique.add(triple.join(','))) {
            ends.putIfAbsent(triple.last, () => []).add(triple);
          }
        }
      }
      final history = PushupSpanHistory(), outputs = <String, dynamic>{};
      for (final f in frames) {
        final index = f[0] as int, lm = f[2] as List?;
        if (f.length > 3 && f[3] == 'abandon') {
          history.reset();
          continue;
        }
        final points = <BodyLandmark, Keypoint>{};
        if (lm != null) {
          for (final joint in BodyLandmark.values) {
            final value = lm[joint.index] as List?;
            if (value == null) continue;
            points[joint] = Keypoint(
              landmark: joint,
              x: (value[0] as num).toDouble(),
              y: (value[1] as num).toDouble(),
              likelihood: (value[2] as num).toDouble(),
            );
          }
        }
        history.add(
          PoseFrame(
            imageWidth: (row['width'] as num).toDouble(),
            imageHeight: (row['height'] as num).toDouble(),
            keypoints: points,
          ),
          times[index]!,
        );
        for (final w in ends[index] ?? <List<int>>[]) {
          final start = times[w[0]], bottom = times[w[1]];
          if (start == null || bottom == null) {
            throw StateError('Window frame missing');
          }
          final vector = history.evidence(
            start: start,
            bottom: bottom,
            end: times[index]!,
          );
          outputs[w.join(',')] = args.length == 3
              ? vector
              : vector == null
              ? null
              : pushupSpanFeedback(vector)?.name;
        }
      }
      sink.writeln(
        jsonEncode({'source_id': row['source_id'], 'evidence': outputs}),
      );
    }
  } finally {
    await sink.close();
  }
}
