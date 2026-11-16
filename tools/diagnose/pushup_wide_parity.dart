// Replay stable-primary events and live keypoints through the production
// proposal helper, using the app package_config.json.
import 'dart:convert';
import 'dart:io';

import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

Future<void> main(List<String> args) async {
  if (args.length != 4) {
    throw ArgumentError('REPLAY STABLE_EVENTS EXPECTED_PROPOSALS NEW_REPORT');
  }
  Map<String, Map<String, dynamic>> documents(String path) => {
    for (final line in File(path).readAsLinesSync())
      (jsonDecode(line) as Map<String, dynamic>)['source_id'] as String:
          jsonDecode(line) as Map<String, dynamic>,
  };
  final stable = documents(args[1]);
  final expected = documents(args[2]);
  final output = File(args[3]);
  if (output.existsSync()) throw StateError('Use a fresh report path');
  final differences = <String, Object?>{};
  var total = 0, sources = 0;
  await for (final line in File(
    args[0],
  ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    final doc = jsonDecode(line) as Map<String, dynamic>;
    final id = doc['source_id'] as String;
    final detector = PushupWideProposalDetector();
    final primaries = {
      for (final e in stable[id]!['events']['app_default'] as List)
        e[0] as int: e[1] as String,
    };
    final want = [
      for (final e in expected[id]!['events']['app_default'] as List)
        e[0] as int,
    ];
    final actual = <int>[];
    for (final f in doc['frames'] as List) {
      final frameIndex = f[0] as int;
      final now = doc['time_unit'] == 'us'
          ? Duration(microseconds: f[1] as int)
          : Duration(milliseconds: f[1] as int);
      if (f.length > 3 && f[3] == 'abandon') {
        detector.reset();
        continue;
      }
      final positions = f[2] as List?;
      final frame = PoseFrame(
        imageWidth: (doc['width'] as num).toDouble(),
        imageHeight: (doc['height'] as num).toDouble(),
        keypoints: {
          if (positions != null)
            for (var i = 0; i < positions.length; i++)
              if (positions[i] != null)
                BodyLandmark.values[i]: Keypoint(
                  landmark: BodyLandmark.values[i],
                  x: (positions[i][0] as num).toDouble(),
                  y: (positions[i][1] as num).toDouble(),
                  likelihood: (positions[i][2] as num).toDouble(),
                ),
        },
      );
      final label = primaries[frameIndex];
      final primary = label == null
          ? null
          : RepEvent(
              index: 1,
              valid: label == 'normal',
              reason: label == 'normal'
                  ? null
                  : RejectReason.values.byName(label),
              at: now,
            );
      if (detector.update(frame, now, primary: primary) != null) {
        actual.add(frameIndex);
      }
    }
    sources++;
    total += actual.length;
    if (jsonEncode(actual) != jsonEncode(want)) {
      differences[id] = {'expected': want, 'actual': actual};
    }
  }
  final report = {
    'sources': sources,
    'proposals': total,
    'mismatched_sources': differences.length,
    'differences': differences,
  };
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(report.toString());
}
