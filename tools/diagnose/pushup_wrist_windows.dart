// From gymrats_app: dart --packages=.dart_tool/package_config.json
// ../tools/diagnose/pushup_wrist_windows.dart replay.jsonl|--fixtures
// existing-events.jsonl preset output.jsonl [--split development] [--models model.json]
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../gymrats_app/lib/models/pose_frame.dart';
import '../../gymrats_app/lib/services/pose/pose_metrics.dart';

/// Causal feature windows, ending on the current frame. Missing samples are
/// kept missing even when earlier reliable observations remain in the window.
class WristReasonHistory {
  final _rows = ListQueue<(int, List<double?>)>();
  final _lastSeen = List<int?>.filled(8, null);
  final _ema = List<double?>.filled(8, null);

  void clear() {
    _rows.clear();
    _lastSeen.fillRange(0, 8, null);
    _ema.fillRange(0, 8, null);
  }

  void add(PoseFrame frame, int micros) {
    if (_rows.isNotEmpty &&
        (micros < _rows.last.$1 || micros - _rows.last.$1 > 500000)) {
      clear();
    }
    Keypoint? present(BodyLandmark id) {
      final point = frame[id];
      return point != null && point.likelihood >= .55 ? point : null;
    }

    double? average(double? a, double? b) =>
        a == null ? b : (b == null ? a : (a + b) / 2);
    final raw = measurePose(frame, minLikelihood: .55);
    final shoulder = raw.shoulderY;
    final wrist = average(
      present(BodyLandmark.leftWrist)?.y,
      present(BodyLandmark.rightWrist)?.y,
    );
    final width = raw.shoulderWidth;
    final validWidth = width != null && width >= 2;
    final left = raw.leftElbowAngle, right = raw.rightElbowAngle;
    final lessArm = left == null
        ? right
        : right == null
        ? left
        : math.min(left, right);
    final knee = average(
      angleDegrees(
        present(BodyLandmark.leftHip),
        present(BodyLandmark.leftKnee),
        present(BodyLandmark.leftAnkle),
      ),
      angleDegrees(
        present(BodyLandmark.rightHip),
        present(BodyLandmark.rightKnee),
        present(BodyLandmark.rightAnkle),
      ),
    );
    final sample = <double?>[
      validWidth && wrist != null && shoulder != null
          ? (wrist - shoulder) / width
          : null,
      raw.elbowAngle,
      lessArm,
      raw.tilt,
      knee,
      validWidth ? raw.kneeHandGap : null,
      validWidth ? raw.hipHandGap : null,
      validWidth ? raw.torsoDrop : null,
    ];
    for (var col = 0; col < sample.length; col++) {
      final observation = sample[col];
      if (observation == null) continue;
      final last = _lastSeen[col];
      final prev = _ema[col];
      final value = last == null || prev == null || micros - last > 350000
          ? observation
          : prev +
                (1 - math.exp(-(micros - last) / 65000)) * (observation - prev);
      sample[col] = _ema[col] = value;
      _lastSeen[col] = micros;
    }
    _rows.addLast((micros, sample));
    while (_rows.first.$1 < micros - 1650000) {
      _rows.removeFirst();
    }
  }

  static double? _percentile(List<double> values, double fraction) {
    if (values.isEmpty) return null;
    values.sort();
    final k = fraction * (values.length - 1);
    final low = values[k.floor()], high = values[k.ceil()];
    return low + (high - low) * (k - k.floor());
  }

  List<double?> features(String original) {
    final out = <double?>[
      for (final c in [
        'insufficientDepth',
        'shouldersNotLevel',
        'kneesDown',
        'incompleteExtension',
      ])
        c == original ? 1 : 0,
    ];
    final now = _rows.last.$1;
    for (final window in [650000, 1650000]) {
      final samples = _rows
          .where((r) => r.$1 >= now - window)
          .map((r) => r.$2)
          .toList();
      List<double> values(int col) => [
        for (final row in samples)
          if (row[col] != null) row[col]!,
      ];
      final heights = values(0);
      final hi = _percentile(heights, .9), low = _percentile(heights, .1);
      final current = samples.last;
      out.addAll([
        hi == null || low == null ? null : hi - low,
        current[0] == null || low == null ? null : current[0]! - low,
        _percentile(values(1), 0),
        current[2],
        _percentile(values(3), .8),
        _percentile(values(4), .5),
        _percentile(values(5), .5),
        _percentile(values(6), 1),
        _percentile(values(7), 0),
        _percentile(values(7), 1),
      ]);
    }
    // Max number of successive observed frames with each specific anatomical
    // cue. Only form evidence gates read these, never the fitted decision tree.
    final longest = List<int>.filled(5, 0), streak = List<int>.filled(5, 0);
    int? previous;
    for (final row in _rows) {
      if (previous != null && row.$1 - previous > 200000)
        streak.fillRange(0, 5, 0);
      previous = row.$1;
      final v = row.$2;
      final knee = v[4], gap = v[5], tilt = v[3];
      final flags = [
        knee != null && knee < 155,
        gap != null && gap >= -.22 && gap <= .45,
        tilt != null && tilt >= 8,
        knee != null && knee < 145 && gap != null && gap > -.65,
        tilt != null && tilt >= 12,
      ];
      for (var i = 0; i < flags.length; i++) {
        streak[i] = flags[i] ? streak[i] + 1 : 0;
        longest[i] = math.max(longest[i], streak[i]);
      }
    }
    return [...out, ...longest.map((x) => x.toDouble())];
  }
}

String predictWristReason(String old, List<double?> features, Map model) {
  if (old != 'insufficientDepth') return old;
  final nodes = model['nodes'] as List;
  var n = 0;
  while (true) {
    final node = nodes[n] as List;
    if (node[0] == -1) {
      final label = node[1] as String;
      if (node[2] < model['confidence']) return old;
      final strict = model['evidence'] == 'strict';
      final ok = switch (label) {
        'kneesDown' =>
          strict
              ? features[27]! >= 3
              : features[24]! >= 3 || features[25]! >= 3,
        'shouldersNotLevel' => strict ? features[28]! >= 3 : features[26]! >= 3,
        _ => false,
      };
      return ok ? label : old;
    }
    n = (features[node[0] as int] ?? -999) <= node[1]
        ? node[2] as int
        : node[3] as int;
  }
}

PoseFrame _pose(
  List values,
  double w,
  double h, {
  List<BodyLandmark>? order,
  bool flat = false,
}) {
  final points = <BodyLandmark, Keypoint>{};
  for (var i = 0; i < 33; i++) {
    final k = order?[i] ?? BodyLandmark.values[i];
    if (flat ? values[4 * i] == null : values[i] == null) continue;
    final p = flat ? values.sublist(4 * i, 4 * i + 4) : values[i] as List;
    points[k] = Keypoint(
      landmark: k,
      x: (p[0] as num).toDouble(),
      y: (p[1] as num).toDouble(),
      likelihood: (p[flat ? 3 : 2] as num).toDouble(),
    );
  }
  return PoseFrame(imageWidth: w, imageHeight: h, keypoints: points);
}

Future<void> main(List<String> args) async {
  if (args.length < 4)
    throw ArgumentError(
      'replay.jsonl|--fixtures events.jsonl preset output.jsonl [--split development|holdout] [--models model.json]',
    );
  String? option(String k) =>
      args.contains(k) ? args[args.indexOf(k) + 1] : null;
  final split = option('--split'), modelFile = option('--models');
  final modelSpec = modelFile == null
      ? null
      : jsonDecode(File(modelFile).readAsStringSync()) as Map;
  if (modelSpec != null && modelSpec['base'] != args[2]) {
    throw StateError('Selected event stream and model base differ');
  }
  final models = modelSpec == null
      ? <String, dynamic>{}
      : (modelSpec['models'] as Map).cast<String, dynamic>();
  final bySource = <String, List>{};
  for (final line in File(args[1]).readAsLinesSync()) {
    final row = jsonDecode(line) as Map;
    bySource[row['source_id'] as String] = row['events'][args[2]] as List;
  }
  final out = File(args[3]);
  if (out.existsSync()) throw StateError('Output already exists: ${out.path}');
  final temp = File('${out.path}.$pid.tmp');
  final sink = temp.openWrite();
  var n = 0;
  void source(Map row, bool fixture) {
    final sid = (row[fixture ? 'id' : 'source_id']) as String;
    if (!fixture && split != null && row['split'] != split) return;
    final events = bySource[sid]!;
    final predicted = {for (final k in models.keys) k: <List>[]},
        featureRows = <List>[];
    final history = WristReasonHistory();
    final order = fixture
        ? [
            for (final e in row['landmarks'])
              BodyLandmark.values.byName(e as String),
          ]
        : null;
    final sequence = row['frames'] as List;
    var eventAt = 0;
    for (var i = 0; i < sequence.length; i++) {
      final dynamic f = sequence[i];
      late int index;
      if (fixture) {
        index = i;
        if (f['mark'] == 'abandon') {
          history.clear();
          continue;
        }
        if (f['p'] == null) continue;
        history.add(
          _pose(
            f['p'] as List,
            (f['w'] as num).toDouble(),
            (f['h'] as num).toDouble(),
            order: order,
            flat: true,
          ),
          f['t'] as int,
        );
      } else {
        index = f[0] as int;
        history.add(
          _pose(
            f[2] as List,
            (row['width'] as num).toDouble(),
            (row['height'] as num).toDouble(),
          ),
          (f[1] as int) * 1000,
        );
      }
      if (eventAt < events.length && events[eventAt][0] == index) {
        final old = events[eventAt++][1] as String;
        final features = history.features(old);
        featureRows.add(features);
        for (final entry in models.entries) {
          predicted[entry.key]!.add([
            index,
            predictWristReason(old, features, entry.value as Map),
          ]);
        }
      }
    }
    if (eventAt != events.length)
      throw StateError('Missing event frame for $sid');
    sink.writeln(
      jsonEncode({
        'source_id': sid,
        'events': {args[2]: events, ...predicted},
        'wrist_features': featureRows,
      }),
    );
    n++;
  }

  if (args[0] == '--fixtures') {
    for (final dir in ['test/ai_eval/cases', 'test/fixtures/pushup_cases']) {
      for (final f
          in Directory(dir)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))) {
        source(jsonDecode(f.readAsStringSync()) as Map, true);
      }
    }
  } else {
    await for (final line in File(
      args[0],
    ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      source(jsonDecode(line) as Map, false);
    }
  }
  await sink.close();
  temp.renameSync(out.path);
  stdout.writeln('Wrote $n originals');
}
