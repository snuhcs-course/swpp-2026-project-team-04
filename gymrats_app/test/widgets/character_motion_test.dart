import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/widgets/character_motion.dart';
import 'package:gymrats_app/widgets/character_motion_data.dart';

/// The design bundle's test values (`golden` of w4_home_rig.json).
final _golden = jsonDecode(
  File('test/widgets/character_motion_golden.json').readAsStringSync(),
) as Map<String, dynamic>;

const _ids = ['mouse', 'kangaroo', 'bear', 'penguin', 'seal'];

const _w3Keys = [
  'tail',
  'l1',
  'l2',
  's1',
  's2',
  'a1',
  'a2',
  'torso',
  'head',
  'g1',
  'g2',
  'wb',
  'wc',
  'fx',
];

final _rig = CharacterMotionRig.standard;
final _w3 = CharacterRig.standard;
final _anchor = Offset(_w3.anchorX, _w3.anchorY);

/// A pose table as the rigs write it: key -> [letter, numbers...] items.
Map<String, List<List<Object>>> _written(RigPoseTable table) => {
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

/// Fails unless [actual] is [expected] (the golden form) within [tolerance]
/// in every number, with the same letters and lengths.
void _expectPose(
  RigPoseTable actual,
  Map<String, dynamic> expected,
  double tolerance,
  String where,
) {
  final written = _written(actual);
  expect(written.keys.toSet(), expected.keys.toSet(), reason: where);
  for (final MapEntry(:key, :value) in expected.entries) {
    final items = value as List;
    expect(written[key]!.length, items.length, reason: '$where $key');
    for (var i = 0; i < items.length; i++) {
      final want = items[i] as List;
      final got = written[key]![i];
      expect(got.first, want.first, reason: '$where $key[$i]');
      expect(got.length, want.length, reason: '$where $key[$i]');
      for (var j = 1; j < want.length; j++) {
        expect(
          got[j] as double,
          closeTo((want[j] as num).toDouble(), tolerance),
          reason: '$where $key[$i][$j]',
        );
      }
    }
  }
}

/// A one-key-pose-pair motion read from [json] over two simple key poses.
Map<String, RigPoseTable> _twoPoses() => readKeyPoses({
  'a': {
    'torso': [
      ['t', 0, 0],
    ],
    'l1': [
      ['M', 0, 0],
      ['L', 10, 0],
    ],
  },
  'b': {
    'torso': [
      ['t', 10, 20],
    ],
    'l1': [
      ['M', 0, 10],
      ['L', 20, 0],
    ],
  },
});

CharacterMotion _motion(
  Map<String, dynamic> changes,
) => CharacterMotion.fromJson({
  'label': 'test',
  'durMs': 1000,
  'loop': true,
  'keys': ['a', 'b'],
  'seg': [
    {'fromMs': 100, 'toMs': 300, 'fromKey': 'a', 'toKey': 'b', 'ease': 'lin'},
    {'fromMs': 500, 'toMs': 700, 'fromKey': 'b', 'toKey': 'a', 'ease': 'lin'},
  ],
  'expr': [
    {'atMs': 0, 'expr': 'idle'},
    {'atMs': 400, 'expr': 'atk'},
  ],
  'delayMs': <String, Object>{},
  'global': <Object>[],
  'flags': {'gBack': false, 'pa': false},
  'rest': {'key': 'a', 'expr': 'idle'},
  ...changes,
});

double _torsoX(CharacterMotionFrame frame) =>
    frame.pose.transform('torso').single.values[0];

void main() {
  group('the data (W4 spec 8, "데이터 검사")', () {
    test('is the home rig, on top of the W3 rig', () {
      expect(_rig.version, 'w4-home-rig-1');
      expect(_rig.extendsVersion, _w3.version);
    });

    test('has the five characters a person picks, with their exercises', () {
      expect(_rig.characters.keys.toSet(), _ids.toSet());
      expect(
        [for (final art in _w3.selectable) art.id],
        _ids,
        reason: 'every character a person picks moves on home',
      );
      expect(
        {for (final id in _ids) id: _rig.characters[id]!.exercise},
        {
          'mouse': 'push',
          'kangaroo': 'push',
          'bear': 'bOne',
          'penguin': 'squat',
          'seal': 'squat',
        },
      );
      expect(_rig.characters['bear']!.motion.label, '원투 펀치');
    });

    for (final id in _ids) {
      test('$id: every key pose has all 17 pose keys, alike in steps', () {
        final home = _rig.characters[id]!;
        final first = home.keyPoses.values.first;
        for (final MapEntry(key: name, value: pose) in home.keyPoses.entries) {
          expect(
            {...pose.transforms.keys, ...pose.paths.keys},
            {..._w3Keys, 'belly', 'p1', 'p2'},
            reason: '$id $name',
          );
          for (final key in first.transforms.keys) {
            expect(
              [for (final m in pose.transform(key)) m.kind],
              [for (final m in first.transform(key)) m.kind],
              reason: '$id $name $key',
            );
          }
          for (final key in first.paths.keys) {
            expect(
              [for (final s in pose.path(key)) s.command],
              [for (final s in first.path(key)) s.command],
              reason: '$id $name $key',
            );
          }
        }
      });

      test('$id: the timetable names only key poses that exist', () {
        final home = _rig.characters[id]!;
        final motion = home.motion;
        expect(motion.keys.toSet(), home.keyPoses.keys.toSet());
        for (final s in motion.segments) {
          expect(home.keyPoses, contains(s.fromKey));
          expect(home.keyPoses, contains(s.toKey));
        }
        expect(home.keyPoses, contains(motion.restKey));
        expect(motion.loop, isTrue);
      });
    }

    test('the golden values are for these five and their exercises', () {
      expect(_golden['tolerance'], 0.01);
      final golden = _golden['characters'] as Map<String, dynamic>;
      expect(golden.keys.toSet(), _ids.toSet());
      for (final id in _ids) {
        expect(golden[id]['motion'], _rig.characters[id]!.exercise);
      }
    });

    test('a malformed rig is a FormatException', () {
      expect(() => CharacterMotionRig.parse('[]'), throwsFormatException);
      expect(() => CharacterMotionRig.parse('{}'), throwsFormatException);
      final source = jsonDecode(characterMotionJson) as Map<String, dynamic>;
      Map<String, dynamic> copy() =>
          jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
      // A key pose that draws a leg with one step more.
      final longer = copy();
      (longer['characters']['mouse']['keyposes']['down']['l1'] as List).add([
        'L',
        0,
        0,
      ]);
      expect(
        () => CharacterMotionRig.parse(jsonEncode(longer)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"l1"'),
          ),
        ),
      );
      // A timetable that names a key pose that is not there.
      final missing = copy();
      missing['characters']['bear']['motion']['rest']['key'] = 'x';
      expect(
        () => CharacterMotionRig.parse(jsonEncode(missing)),
        throwsFormatException,
      );
      // An easing the rule does not know.
      final ease = copy();
      ease['characters']['seal']['motion']['seg'][0]['ease'] = 'bounce';
      expect(
        () => CharacterMotionRig.parse(jsonEncode(ease)),
        throwsFormatException,
      );
      // A move with a number short.
      final short = copy();
      short['characters']['penguin']['keyposes']['up']['torso'][0] = ['t', 1];
      expect(
        () => CharacterMotionRig.parse(jsonEncode(short)),
        throwsFormatException,
      );
    });
  });

  group('against the golden values (W4 spec 8, "대조 검사")', () {
    final tolerance = (_golden['tolerance'] as num).toDouble();
    final characters = _golden['characters'] as Map<String, dynamic>;

    for (final id in _ids) {
      final golden = characters[id] as Map<String, dynamic>;
      for (final sample in golden['samples'] as List) {
        final t = (sample['tMs'] as num).toDouble();
        test('$id at ${t.toInt()} ms: pose, expression and whole move', () {
          final frame = _rig.characters[id]!.frameAt(t);
          expect(frame.expression, sample['expr']);
          final global = sample['global'] as Map<String, dynamic>;
          expect(frame.global.up, closeTo(global['up'] as num, tolerance));
          expect(
            frame.global.rotDeg,
            closeTo(global['rotDeg'] as num, tolerance),
          );
          expect(frame.global.sx, closeTo(global['sx'] as num, tolerance));
          expect(frame.global.sy, closeTo(global['sy'] as num, tolerance));
          _expectPose(
            frame.pose,
            sample['pose'] as Map<String, dynamic>,
            tolerance,
            '$id ${t.toInt()}',
          );
        });
      }

      test('$id still: the rest picture with less motion', () {
        final still = golden['still'] as Map<String, dynamic>;
        final rest = _rig.characters[id]!.rest;
        expect(rest.expression, still['expr']);
        expect(rest.global.up, 0);
        expect(rest.global.rotDeg, 0);
        expect((rest.global.sx, rest.global.sy), (1, 1));
        _expectPose(
          rest.pose,
          still['pose'] as Map<String, dynamic>,
          tolerance,
          '$id still',
        );
      });
    }

    test('the samples cover wrapping and the parts that run late', () {
      for (final id in _ids) {
        final golden = characters[id] as Map<String, dynamic>;
        final dur = _rig.characters[id]!.motion.durMs;
        expect(
          (golden['samples'] as List).any((s) => (s['tMs'] as num) >= dur),
          isTrue,
          reason: id,
        );
      }
      expect(_rig.characters['mouse']!.motion.delayMs, {'tail': 96});
      expect(_rig.characters['seal']!.motion.delayMs, {'belly': 96});
    });
  });

  group('the timing rules (W4 spec 5, "시간 계산")', () {
    test('the easings', () {
      expect(MotionEase.lin.at(0.25), 0.25);
      expect(MotionEase.ei.at(0.5), 0.125);
      expect(MotionEase.eo.at(0.5), 0.875);
      expect(MotionEase.eio.at(0.25), closeTo(0.0625, 1e-12));
      expect(MotionEase.eio.at(0.75), closeTo(0.9375, 1e-12));
      expect(MotionEase.sin.at(0.5), closeTo(0.5, 1e-12));
      for (final ease in MotionEase.values) {
        expect(ease.at(0), closeTo(0, 1e-12), reason: ease.name);
        expect(ease.at(1), closeTo(1, 1e-12), reason: ease.name);
      }
    });

    test('before, inside, between and after the segments', () {
      final motion = _motion({});
      final poses = _twoPoses();
      double x(double t) => _torsoX(motion.frameAt(t, poses));
      expect(x(50), 0, reason: 'before the first: its fromKey');
      expect(x(100), 0);
      expect(x(200), 5, reason: 'half way, linear');
      expect(x(300), 10);
      expect(x(400), 10, reason: 'between: the toKey before');
      expect(x(600), 5);
      expect(x(900), 0, reason: 'after the last: its toKey');
      // Paths blend number by number, the letters kept.
      final l1 = motion.frameAt(200, poses).pose.path('l1');
      expect(
        [for (final s in l1) s.command],
        [RigCommand.move, RigCommand.line],
      );
      expect(l1[0].values, [0, 5]);
      expect(l1[1].values, [15, 0]);
    });

    test('a loop wraps the time either way; a motion that does not loop '
        'holds its end', () {
      final poses = _twoPoses();
      final loop = _motion({});
      double x(CharacterMotion m, double t) => _torsoX(m.frameAt(t, poses));
      expect(x(loop, 1200), x(loop, 200));
      expect(x(loop, -800), x(loop, 200));
      expect(loop.wrap(-250), 750);
      final once = _motion({'loop': false});
      expect(x(once, 1200), 0);
      expect(once.wrap(1200), 1200);
    });

    test('a part that runs late follows on its own time', () {
      final motion = _motion({
        'delayMs': {'l1': 100},
      });
      final frame = motion.frameAt(200, _twoPoses());
      expect(_torsoX(frame), 5);
      expect(frame.pose.path('l1')[1].values, [10, 0], reason: 'as at 100');
    });

    test('the expression is the last one begun', () {
      final motion = _motion({});
      final poses = _twoPoses();
      expect(motion.frameAt(399, poses).expression, 'idle');
      expect(motion.frameAt(400, poses).expression, 'atk');
      expect(motion.frameAt(1399, poses).expression, 'idle');
    });

    test('hop, rock and landing add up into the whole move', () {
      final motion = _motion({
        'global': [
          {'k': 'hop', 'amp': 2, 'ms': 320},
          {'k': 'hop', 'amp': 1, 'ms': 400, 'ph': 100},
          {'k': 'rock', 'deg': 9, 'ms': 640},
          {'k': 'land', 'at': 400, 'ms': 220, 'sy': 0.08, 'sx': 0.05},
        ],
      });
      final at160 = motion.globalAt(160);
      expect(
        at160.up,
        closeTo(2 + 1 * math.sin(math.pi * 60 / 400).abs(), 1e-9),
      );
      expect(at160.rotDeg, closeTo(9 * math.sin(math.pi / 2), 1e-9));
      expect((at160.sx, at160.sy), (1, 1), reason: 'before the landing');
      final at510 = motion.globalAt(510);
      expect(at510.sx, closeTo(1.05, 1e-9));
      expect(at510.sy, closeTo(0.92, 1e-9));
      expect(motion.globalAt(620).sy, 1, reason: 'the landing is over');
    });

    test('only flags that are on count', () {
      expect(_rig.characters['mouse']!.motion.flags, {'gBack'});
      expect(_rig.characters['kangaroo']!.motion.flags, {'gBack'});
      expect(_rig.characters['seal']!.motion.flags, {'pa'});
      expect(_rig.characters['bear']!.motion.flags, isEmpty);
      expect(_rig.characters['penguin']!.motion.flags, isEmpty);
    });
  });

  group('expressions', () {
    test('home maps idle and atk to their own tag', () {
      for (final id in _ids) {
        expect(_rig.tagsOf('idle', id), {'idle'});
        expect(_rig.tagsOf('atk', id), {'atk'});
      }
      expect(() => _rig.tagsOf('grin', 'seal'), throwsArgumentError);
    });

    test('a map by character with a default (W5) reads too', () {
      final tags = readExpressionTags({
        'grit': ['atk', 'teeth'],
        'grin': {
          'seal': ['grin'],
          'default': ['win'],
        },
      });
      expect(tags['grit'], {
        'default': ['atk', 'teeth'],
      });
      expect(tags['grin']!['seal'], ['grin']);
      expect(tags['grin']!['default'], ['win']);
      expect(
        () => readExpressionTags({
          'grin': {
            'seal': ['grin'],
          },
        }),
        throwsFormatException,
      );
    });
  });

  group('where the character stands (W4 spec 3, "배치 검사")', () {
    final layout =
        (jsonDecode(characterMotionJson) as Map<String, dynamic>)['layout']
            as Map<String, dynamic>;
    final area = layout['characterArea'] as Map<String, dynamic>;
    final left = (area['x'] as num).toDouble();

    for (final bar in ['threeButton', 'gesture']) {
      final room = layout[bar] as Map<String, dynamic>;
      final top = (room['areaTop'] as num).toDouble();
      final size = Size(
        (area['w'] as num).toDouble(),
        (room['areaH'] as num).toDouble(),
      );
      for (final id in _ids) {
        test('360×780 with the $bar bar: $id at the scale and feet of its '
            'placement', () {
          final placement =
              (jsonDecode(characterMotionJson)
                      as Map)['characters'][id]['placement'][bar]
                  as Map<String, dynamic>;
          final place = _rig.characters[id]!.placeIn(size, _anchor);
          expect(place.scale, placement['scale']);
          final foot = placement['foot'] as List;
          expect(place.foot.dx + left, closeTo(foot[0] as num, 0.01));
          expect(place.foot.dy + top, closeTo(foot[1] as num, 0.01));
          expect(place.foot.dy + top, room['floorY']);
          // The motion's whole room drawn there stays inside the room.
          final b = _rig.characters[id]!.bounds;
          final drawn = Rect.fromLTRB(
            place.foot.dx + (b.left - _anchor.dx) * place.scale,
            place.foot.dy + (b.top - _anchor.dy) * place.scale,
            place.foot.dx + (b.right - _anchor.dx) * place.scale,
            place.foot.dy + (b.bottom - _anchor.dy) * place.scale,
          );
          final want = placement['drawn'] as Map<String, dynamic>;
          expect(drawn.left + left, closeTo(want['left'] as num, 0.01));
          expect(drawn.top + top, closeTo(want['top'] as num, 0.01));
          expect(drawn.right + left, closeTo(want['right'] as num, 0.01));
          expect((Offset.zero & size).contains(drawn.topLeft), isTrue);
        });
      }
    }

    test('a lower room shrinks the character (그루 1.28x in 200)', () {
      expect(
        _rig.characters['kangaroo']!.placeIn(const Size(320, 200), _anchor),
        isA<CharacterPlacement>().having((p) => p.scale, 'scale', 1.28),
      );
    });

    test('a narrow room shrinks it too, and no room draws nothing', () {
      final kangaroo = _rig.characters['kangaroo']!;
      // 300 / 168.5 across in 320; 140 / 168.5 in 160.
      expect(kangaroo.placeIn(const Size(160, 300), _anchor).scale, 0.83);
      expect(kangaroo.placeIn(const Size(320, 20), _anchor).scale, 0);
      expect(kangaroo.placeIn(Size.zero, _anchor).scale, 0);
    });
  });

  test('the stage draws 그루\'s inner tail fur and nothing else of home\'s '
      '(user, 2026-11-14)', () {
    final fur = _rig.stagePatchOf('kangaroo');
    expect(fur, hasLength(1));
    expect(fur.single.group, 'tailInner');
    for (final id in ['mouse', 'bear', 'penguin', 'seal', 'bot', 'rabbit']) {
      expect(_rig.stagePatchOf(id), isEmpty, reason: id);
    }
  });

  test('an unknown character moves as the default mouse', () {
    expect(_rig.motionOf('rabbit'), same(_rig.characters['mouse']));
    expect(_rig.motionOf('bot'), same(_rig.characters['mouse']));
  });

  test('a placement is equal by value', () {
    const a = CharacterPlacement(scale: 1.6, foot: Offset(1, 2));
    expect(a, const CharacterPlacement(scale: 1.6, foot: Offset(1, 2)));
    expect(
      a.hashCode,
      const CharacterPlacement(scale: 1.6, foot: Offset(1, 2)).hashCode,
    );
    expect(a, isNot(const CharacterPlacement(scale: 1.5, foot: Offset(1, 2))));
    expect('$a', contains('1.6'));
  });
}
