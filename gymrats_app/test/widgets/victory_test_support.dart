import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/widgets/character_motion.dart';
import 'package:gymrats_app/widgets/victory_motion.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

/// The design bundle's test values (`victory_golden.json`, a copy of the
/// bundle's file).
final victoryGolden = jsonDecode(
  File('test/widgets/victory_golden.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The golden's tolerance (0.01).
final victoryTolerance = (victoryGolden['tolerance'] as num).toDouble();

const victoryIds = ['mouse', 'kangaroo', 'bear', 'penguin', 'seal'];

/// The design's screen and seat (spec 2): 360 x 780, the seat at (200, 36).
const designSize = Size(360, 780);
const designSeat = Offset(200, 36);

/// [id]'s scene for [result] on the design's screen.
VictoryScene designScene(String id, VictoryResult result) {
  final rig = VictoryRig.standard;
  return VictoryScene(
    rig: rig,
    character: rig.characterOf(id),
    result: result,
    layout: VictoryLayout(
      size: designSize,
      seat: designSeat,
      values: rig.scene,
    ),
  );
}

/// A pose table as the rigs write it: key -> [letter, numbers...] items.
Map<String, List<List<Object>>> writtenPose(RigPoseTable table) => {
  for (final MapEntry(:key, :value) in table.transforms.entries)
    key: [
      for (final move in value)
        [
          switch (move.kind) {
            RigTransformKind.translate => 't',
            RigTransformKind.rotate => 'r',
            RigTransformKind.scale => 's',
          },
          ...move.values,
        ],
    ],
  for (final MapEntry(:key, :value) in table.paths.entries)
    key: [
      for (final step in value)
        [
          switch (step.command) {
            RigCommand.move => 'M',
            RigCommand.line => 'L',
            RigCommand.quad => 'Q',
            RigCommand.cubic => 'C',
            RigCommand.arc => 'A',
            RigCommand.close => 'Z',
          },
          ...step.values,
        ],
    ],
};

/// Fails unless [actual] is [expected] (the golden form) within the
/// tolerance in every number, with the same letters and lengths.
void expectPose(RigPoseTable actual, Object? expected, String where) {
  final want = expected as Map<String, dynamic>;
  final written = writtenPose(actual);
  expect(written.keys.toSet(), want.keys.toSet(), reason: where);
  for (final MapEntry(:key, :value) in want.entries) {
    final items = value as List;
    expect(written[key]!.length, items.length, reason: '$where $key');
    for (var i = 0; i < items.length; i++) {
      final item = items[i] as List;
      final got = written[key]![i];
      expect(got.first, item.first, reason: '$where $key[$i]');
      expect(got.length, item.length, reason: '$where $key[$i]');
      for (var j = 1; j < item.length; j++) {
        expect(
          got[j] as double,
          closeTo((item[j] as num).toDouble(), victoryTolerance),
          reason: '$where $key[$i][$j]',
        );
      }
    }
  }
}

/// Fails unless [frame] has the golden [sample]'s expression, whole-picture
/// move and pose.
void expectFrame(
  CharacterMotionFrame frame,
  Map<String, dynamic> sample,
  String where,
) {
  expect(frame.expression, sample['expr'], reason: '$where expr');
  // A still sample of the scene leaves out its move: it has none.
  final global =
      (sample['global'] ?? const {'up': 0, 'rotDeg': 0, 'sx': 1, 'sy': 1})
          as Map<String, dynamic>;
  for (final (name, value) in [
    ('up', frame.global.up),
    ('rotDeg', frame.global.rotDeg),
    ('sx', frame.global.sx),
    ('sy', frame.global.sy),
  ]) {
    expect(
      value,
      closeTo((global[name] as num).toDouble(), victoryTolerance),
      reason: '$where global.$name',
    );
  }
  expectPose(frame.pose, sample['pose'], where);
}

/// A number of the golden within the tolerance.
Matcher near(Object? golden) =>
    closeTo((golden as num).toDouble(), victoryTolerance);

/// A point of the golden ([x, y]) within the tolerance.
void expectPoint(Offset actual, Object? golden, String where) {
  final xy = golden as List;
  expect(actual.dx, near(xy[0]), reason: '$where x');
  expect(actual.dy, near(xy[1]), reason: '$where y');
}
