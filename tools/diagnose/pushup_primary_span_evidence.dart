/// Extracts a causal 1.6-second span window for each prior app verdict.
import 'dart:convert';
import 'dart:io';

import '../../gymrats_app/lib/models/pose_frame.dart';
import '../../gymrats_app/lib/services/pose/pose_metrics.dart';
import '../../gymrats_app/lib/services/pose/rep_judge.dart';

Future<void> main(List<String> args) async {
  final events = <String, Map<int, String>>{};
  for (final line in File(args[1]).readAsLinesSync()) {
    final row = jsonDecode(line);
    events[row['source_id']] = {
      for (final e in row['events']['app_default']) e[0] as int: e[1] as String,
    };
  }
  final sink = File(args[2]).openWrite();
  await for (final line in File(
    args[0],
  ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    final source = jsonDecode(line), id = source['source_id'] as String;
    final old = events[id]!, features = <List<Object?>>[];
    final hist = PushupSpanHistory();
    var now = Duration.zero;
    final judge = RepJudge(clock: () => now);
    Duration? previousPrimary, first, priorFrame;
    for (final f in source['frames']) {
      final index = f[0] as int;
      final t = source['time_unit'] == 'us'
          ? Duration(microseconds: f[1])
          : Duration(milliseconds: f[1]);
      now = t;
      if ((f.length > 3 && f[3] == 'abandon') ||
          priorFrame != null &&
              t - priorFrame > const Duration(milliseconds: 350)) {
        hist.reset();
        judge.abandon();
        previousPrimary = first = null;
        if (f.length > 3 && f[3] == 'abandon') continue;
      }
      first ??= t;
      priorFrame = t;
      final pts = <BodyLandmark, Keypoint>{}, lm = f[2] as List?;
      if (lm != null) {
        for (final name in BodyLandmark.values) {
          final p = lm[name.index];
          if (p == null) continue;
          pts[name] = Keypoint(
            landmark: name,
            x: (p[0] as num).toDouble(),
            y: (p[1] as num).toDouble(),
            likelihood: (p[2] as num).toDouble(),
          );
        }
      }
      final pose = PoseFrame(
        imageWidth: (source['width'] as num).toDouble(),
        imageHeight: (source['height'] as num).toDouble(),
        keypoints: pts,
      );
      hist.add(pose, t);
      final onset = judge.openPrimaryAttempt;
      judge.update(pose);
      if (!old.containsKey(index)) continue;
      final start = hist.primaryWindowStart(t, previousPrimary)!;
      final bottom = start + (t - start) ~/ 2;
      final values = hist.evidence(start: start, bottom: bottom, end: t);
      features.add([
        index,
        old[index],
        values,
        onset != null && hist.observedReturn(pose, start, t, notBefore: onset),
      ]);
      previousPrimary = t;
    }
    sink.writeln(jsonEncode({'source_id': id, 'primary': features}));
  }
  await sink.close();
}
