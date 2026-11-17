// Replay actual saved ML Kit frames through the production single-frame API.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../gymrats_app/lib/models/pose_frame.dart';
import '../../gymrats_app/lib/services/pose/pose_metrics.dart';

Map<String, dynamic> loadJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

PoseFrame poseFromJson(Map<String, dynamic> row) {
  final keypoints = <BodyLandmark, Keypoint>{};
  final points = row['points'] as List?;
  if (points != null) {
    if (points.length != 33)
      throw FormatException('Expected 33 landmark slots');
    for (var index = 0; index < points.length; index++) {
      final point = points[index] as List?;
      if (point == null) continue;
      final landmark = BodyLandmark.values[index];
      keypoints[landmark] = Keypoint(
        landmark: landmark,
        x: (point[0] as num).toDouble(),
        y: (point[1] as num).toDouble(),
        likelihood: (point[2] as num).toDouble(),
      );
    }
  }
  return PoseFrame(
    imageWidth: (row['width'] as num).toDouble(),
    imageHeight: (row['height'] as num).toDouble(),
    keypoints: keypoints,
  );
}

String stateName(KneeFrameState state) => switch (state) {
  KneeFrameState.touching => 'kneesDown',
  KneeFrameState.lifted => 'kneesUp',
  KneeFrameState.occluded => 'occluded',
};

Map<String, dynamic> newTally() => {
  for (final label in ['kneesUp', 'kneesDown'])
    label: <String, int>{
      'kneesUp': 0,
      'kneesDown': 0,
      'occluded': 0,
      'total': 0,
    },
};

Map<String, dynamic> summarize(Map<String, dynamic> counts) {
  final up = counts['kneesUp'] as Map<String, int>;
  final down = counts['kneesDown'] as Map<String, int>;
  return {
    'confusion': counts,
    'normal_lifted_recall': up['kneesUp']! / up['total']!,
    'knee_touching_recall': down['kneesDown']! / down['total']!,
    'normal_false_touching_rate': up['kneesDown']! / up['total']!,
    'normal_occluded_rate': up['occluded']! / up['total']!,
    'knee_occluded_rate': down['occluded']! / down['total']!,
  };
}

double percentile(List<int> values, double fraction) {
  final ordered = [...values]..sort();
  final index = (ordered.length - 1) * fraction;
  final lower = index.floor();
  final upper = index.ceil();
  return ordered[lower] + (ordered[upper] - ordered[lower]) * (index - lower);
}

Future<void> main(List<String> args) async {
  final root = args.isEmpty ? 'C:/SWPP/iter4/frame-knee' : args[0];
  final input = args.length < 2
      ? 'C:/SWPP/iter4/mobile-pose-benchmark/phone-results/full-mlkit-accurate.jsonl'
      : args[1];
  final manifest = loadJson('$root/frame-manifest.json');
  final frames = <String, Map<String, dynamic>>{
    for (final value in manifest['frames'] as List)
      value['key'] as String: value as Map<String, dynamic>,
  };
  final excluded = <String>{
    for (final row in manifest['provenance']['excluded_frames'] as List)
      row['key'] as String,
  };
  final classifier = KneeFrameClassifier();
  final seen = <String>{};
  final excludedSeen = <String>{};
  final tallies = {'development': newTally(), 'holdout': newTally()};
  final reasons = <String, Map<String, int>>{};
  final timings = <int>[];
  await for (final line in File(
    input,
  ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    final row = jsonDecode(line) as Map<String, dynamic>;
    final key = row['key'] as String;
    if (!seen.add(key)) throw StateError('Duplicate frame $key');
    if (excluded.contains(key)) {
      excludedSeen.add(key);
      continue;
    }
    final expected = frames[key];
    if (expected == null) throw StateError('Unexpected frame $key');
    for (final field in ['source_id', 'index', 'width', 'height']) {
      if (row[field] != expected[field]) {
        throw StateError('Mismatched $field for $key');
      }
    }
    final pose = poseFromJson(row);
    final watch = Stopwatch()..start();
    final reading = classifier.classify(pose);
    watch.stop();
    timings.add(watch.elapsedMicroseconds);
    final split = expected['split'] as String;
    final label = expected['label'] as String;
    final state = stateName(reading.state);
    final counts = tallies[split]![label] as Map<String, int>;
    counts[state] = counts[state]! + 1;
    counts['total'] = counts['total']! + 1;
    if (reading.reason != null) {
      final group = reasons.putIfAbsent('$split/$label', () => {});
      group.update(reading.reason!, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  if (seen.length != frames.length + excluded.length ||
      !seen.containsAll(frames.keys) ||
      !excludedSeen.containsAll(excluded)) {
    throw StateError('Input coverage differs from the training manifest');
  }
  final golden = loadJson('$root/golden-frames.json');
  var maxError = 0.0;
  var decisionMismatches = 0;
  for (final value in golden['frames'] as List) {
    final row = value as Map<String, dynamic>;
    final actual = SingleFrameKneeModel.probability(poseFromJson(row));
    if (actual == null || !actual.isFinite) {
      throw StateError('Golden model prediction unavailable');
    }
    final expected = (row['probability'] as num).toDouble();
    maxError = math.max(maxError, (actual - expected).abs());
    if ((actual > SingleFrameKneeModel.rejectionThreshold) !=
        (expected > SingleFrameKneeModel.rejectionThreshold)) {
      decisionMismatches++;
    }
  }
  if (maxError > 1e-10 || decisionMismatches != 0) {
    throw StateError('Golden probability or decision parity failed');
  }
  final report = {
    'schema': 'gymrats-actual-single-frame-classifier-v1',
    'created_at_utc': DateTime.now().toUtc().toIso8601String(),
    'scope':
        'Production KneeFrameClassifier on saved ML Kit Accurate frames. '
        'Inherited weak clip labels and a reused source-group holdout. '
        'Desktop Dart VM timing excludes pose inference, camera, and rendering.',
    'threshold': SingleFrameKneeModel.rejectionThreshold,
    'read_frames': seen.length,
    'classified_frames': timings.length,
    'excluded_frames': excludedSeen.toList()..sort(),
    'holdout': summarize(tallies['holdout']!),
    'development_fitted_model_descriptive': summarize(tallies['development']!),
    'occluded_reasons_by_split_label': reasons,
    'golden_parity': {
      'frames': (golden['frames'] as List).length,
      'model_json_sha256': golden['model_sha256'],
      'max_probability_error': maxError,
      'decision_mismatches': decisionMismatches,
    },
    'desktop_classification_microseconds': {
      'frames': timings.length,
      'total': timings.fold(0, (sum, value) => sum + value),
      'p50': percentile(timings, .5),
      'p95': percentile(timings, .95),
      'max': timings.reduce(math.max),
      'warmup_policy': 'All calls included, including first-call VM warmup.',
    },
  };
  File('$root/actual-classifier-report.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
