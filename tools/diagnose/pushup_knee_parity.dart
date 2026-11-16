// Compare frozen features with both production classifiers.
// Input JSONL rows contain features, normal_probability and knee_probability.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../gymrats_app/lib/services/pose/pose_metrics.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('FEATURES.jsonl NEW_REPORT.json');
  }
  final report = File(args[1]);
  if (report.existsSync()) throw StateError('Use a new report path');
  var count = 0, kneeMismatches = 0, normalMismatches = 0;
  var kneeError = 0.0, normalError = 0.0;
  await for (final line in File(
    args[0],
  ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    final row = jsonDecode(line) as Map<String, dynamic>;
    final features = (row['features'] as List)
        .map((value) => (value as num).toDouble())
        .toList();
    final knee = PushupKneeModel.probability(features);
    final normal = PushupMlpModel.normalProbability(features);
    final expectedKnee = (row['knee_probability'] as num).toDouble();
    final expectedNormal = (row['normal_probability'] as num).toDouble();
    kneeError = math.max(kneeError, (knee - expectedKnee).abs());
    normalError = math.max(normalError, (normal - expectedNormal).abs());
    if ((knee > PushupKneeModel.threshold) !=
        (expectedKnee > PushupKneeModel.threshold)) {
      kneeMismatches++;
    }
    if ((normal > .5) != (expectedNormal > .5)) normalMismatches++;
    count++;
  }
  final result = {
    'windows': count,
    'knee_probability_max_error': kneeError,
    'normal_probability_max_error': normalError,
    'knee_decision_mismatches': kneeMismatches,
    'normal_decision_mismatches': normalMismatches,
  };
  report.writeAsStringSync('${jsonEncode(result)}\n');
  stdout.writeln(jsonEncode(result));
  if (kneeMismatches != 0 ||
      normalMismatches != 0 ||
      kneeError > 1e-6 ||
      normalError > 1e-6) {
    exitCode = 1;
  }
}
