import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

void main() {
  test('compare isolated judge settings on ML Kit video landmarks', () {
    final cases = jsonDecode(
      File(r'C:\SWPP\iter4\pose-eval-results.json').readAsStringSync(),
    ) as List;
    final configs = <String, RepJudgeConfig>{
      'baseline': const RepJudgeConfig(),
      'hold200ms': const RepJudgeConfig(topHold: Duration(milliseconds: 200)),
      'hold100ms': const RepJudgeConfig(topHold: Duration(milliseconds: 100)),
      'smooth45ms': const RepJudgeConfig(
        smoothingTau: Duration(milliseconds: 45),
      ),
    };
    for (final rawCase in cases) {
      final c = rawCase as Map<String, dynamic>;
      for (final setting in configs.entries) {
        var now = Duration.zero;
        final judge = RepJudge(config: setting.value, clock: () => now);
        var detected = 0, valid = 0, rejected = 0;
        for (final rawFrame in c['frames'] as List) {
          final f = rawFrame as Map<String, dynamic>;
          now = Duration(milliseconds: f['ms'] as int);
          final points = f['keypoints'] as Map<String, dynamic>;
          if (points.isNotEmpty) detected++;
          final pose = PoseFrame(
            imageWidth: (c['width'] as num).toDouble(),
            imageHeight: (c['height'] as num).toDouble(),
            keypoints: {
              for (final entry in points.entries)
                BodyLandmark.values.byName(entry.key): Keypoint(
                  landmark: BodyLandmark.values.byName(entry.key),
                  x: (entry.value[0] as num).toDouble(),
                  y: (entry.value[1] as num).toDouble(),
                  z: (entry.value[2] as num).toDouble(),
                  likelihood: (entry.value[3] as num).toDouble(),
                ),
            },
          );
          final event = judge.update(pose).event;
          if (event != null) {
            if (event.valid) {
              valid++;
            } else {
              rejected++;
            }
          }
        }
        // Counts only; these videos do not have verified per-rep truth labels.
        // ignore: avoid_print
        print(
          '${c['clip']} | ${setting.key} | frames=$detected | valid=$valid rejected=$rejected',
        );
      }
    }
  });
}
