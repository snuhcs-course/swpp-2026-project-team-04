import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_idle_motion.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/character_rig_data.dart';

const _ids = ['mouse', 'kangaroo', 'bear', 'penguin', 'seal', 'bot'];

/// The rig as JSON, to break on purpose.
Map<String, dynamic> _source() =>
    jsonDecode(characterRigJson) as Map<String, dynamic>;

Map<String, dynamic> _mouse(Map<String, dynamic> source) =>
    source['characters']['mouse'] as Map<String, dynamic>;

/// Checks that the rig, broken by [breakIt], is rejected.
void _expectRejected(void Function(Map<String, dynamic> source) breakIt) {
  final source = _source();
  breakIt(source);
  expect(() => CharacterRig.parse(jsonEncode(source)), throwsFormatException);
}

/// Where [moves] put the point (x, y): the canvas applies the first move
/// outermost, so the point goes through them from the last one.
(double, double) _place(List<RigTransform> moves, double x, double y) {
  for (final move in moves.reversed) {
    final v = move.values;
    switch (move.kind) {
      case RigTransformKind.translate:
        x += v[0];
        y += v[1];
      case RigTransformKind.rotate:
        final a = v[0] * math.pi / 180;
        final dx = x - v[1];
        final dy = y - v[2];
        x = v[1] + dx * math.cos(a) - dy * math.sin(a);
        y = v[2] + dx * math.sin(a) + dy * math.cos(a);
      case RigTransformKind.scale:
        x *= v[0];
        y *= v[1];
    }
  }
  return (x, y);
}

void main() {
  final rig = CharacterRig.standard;

  group('the rig data', () {
    test('matches assets/characters/w3_rig.json, its source', () {
      final file = File('assets/characters/w3_rig.json').readAsStringSync();
      expect(jsonDecode(characterRigJson), jsonDecode(file));
    });

    test('is w3-rig-2: a 140 x 160 box, feet at (70, 150), facing right', () {
      expect(rig.version, 'w3-rig-2');
      expect((rig.boxWidth, rig.boxHeight), (140, 160));
      expect((rig.anchorX, rig.anchorY), (70, 150));
    });

    test('has six characters in order, the mouse first and RepBot last', () {
      expect(rig.order, _ids);
      expect(rig.characters.keys, _ids);
      expect(rig.defaultCharacter, 'mouse');
      for (final id in _ids) {
        expect(rig.characters[id]!.id, id);
      }
    });

    test('names the characters as decided on 2026-11-13', () {
      expect(
        {for (final id in _ids) id: (rig.art(id).name, rig.art(id).species)},
        {
          'mouse': ('GYM마우스', '쥐'),
          'kangaroo': ('그루', '캥거루'),
          'bear': ('곰탱이', '곰'),
          'penguin': ('펭뚱이', '펭귄'),
          'seal': ('물렁범', '물범'),
          'bot': ('RepBot', '로봇'),
        },
      );
    });

    test('lets a person pick every character but RepBot', () {
      expect(rig.selectable.map((art) => art.id), _ids.take(5));
      expect(rig.art('bot').selectable, isFalse);
    });

    test('gives every character the five poses, each with its fourteen '
        'values', () {
      expect(rig.poses, ['idle', 'atk', 'hit', 'ko', 'win']);
      for (final id in _ids) {
        final poses = rig.art(id).poses;
        expect(poses.keys, rig.poses, reason: id);
        for (final table in poses.values) {
          expect(table.transforms.keys, RigPoseTable.transformKeys);
          expect(table.paths.keys, RigPoseTable.pathKeys);
        }
      }
    });

    test('every key a shape names is in every pose table', () {
      var keyed = 0;
      for (final id in _ids) {
        final art = rig.art(id);
        for (final op in art.ops) {
          for (final table in art.poses.values) {
            expect(() => op.transformsIn(table), returnsNormally);
            expect(() => op.prim.segmentsIn(table), returnsNormally);
          }
          if (op.chain.any((part) => part.key != null) ||
              op.prim.pathKey != null) {
            keyed++;
          }
        }
      }
      expect(keyed, greaterThan(0));
    });

    test('draws each character with the number of shapes of the spec', () {
      expect(
        {for (final id in _ids) id: rig.art(id).ops.length},
        {
          'mouse': 38,
          'kangaroo': 50,
          'bear': 40,
          'penguin': 31,
          'seal': 43,
          'bot': 35,
        },
      );
    });

    test('shows the expressions only in their own poses', () {
      for (final id in _ids) {
        for (final op in rig.art(id).ops) {
          if (op.show == null) continue;
          expect(op.show, isNotEmpty);
          expect(rig.poses, containsAll(op.show!));
          for (final pose in rig.poses) {
            expect(op.showsIn(pose), op.show!.contains(pose));
          }
        }
      }
      final always = rig.art('mouse').ops.firstWhere((op) => op.show == null);
      expect(rig.poses.every(always.showsIn), isTrue);
    });

    test('has the design colors, and no character is itself lime or pink', () {
      expect(rig.ink, 0xFF141A26);
      expect(rig.teamMe, 0xFFC6FF3D);
      expect(rig.teamOpponent, 0xFFFF4F81);
      var teamShapes = 0;
      for (final id in _ids) {
        for (final op in rig.art(id).ops) {
          for (final paint in [op.prim.fill, op.prim.stroke]) {
            if (paint == null) continue;
            if (paint.team) {
              teamShapes++;
            } else {
              expect(paint.argb, isNot(anyOf(rig.teamMe, rig.teamOpponent)));
              expect(paint.argb >> 24, 0xFF, reason: 'opaque');
            }
          }
        }
      }
      expect(teamShapes, greaterThan(0));
    });

    test('reads outlines: width, round or flat ends, opacity', () {
      final prims = [
        for (final id in _ids) ...rig.art(id).ops.map((op) => op.prim),
      ];
      expect(
        prims.where((p) => p.stroke != null && p.strokeWidth <= 0),
        isEmpty,
      );
      expect(
        prims.where((p) => p.stroke == null && p.strokeWidth != 0),
        isEmpty,
      );
      expect(prims.where((p) => !p.roundCap), isNotEmpty);
      expect(
        prims.map((p) => p.strokeOpacity).toSet(),
        containsAll([1.0, 0.45, 0.5]),
      );
      final rect = prims.firstWhere((p) => p.shape == RigShape.rect);
      expect([rect.x, rect.y, rect.w, rect.h, rect.rx], [51, 92, 36, 35, 12]);
      final ellipse = prims.firstWhere((p) => p.shape == RigShape.ellipse);
      expect(ellipse.rx, greaterThan(0));
      expect(ellipse.ry, greaterThan(0));
      final circle = prims.firstWhere((p) => p.shape == RigShape.circle);
      expect(circle.r, greaterThan(0));
      final arcs = [
        for (final p in prims)
          ...p.segments.where((s) => s.command == RigCommand.arc),
      ];
      expect(arcs, hasLength(4), reason: 'the penguin\'s eyes');
    });
  });

  group('choosing a character', () {
    test('an unknown or missing id draws the default mouse', () {
      expect(rig.art(null).id, 'mouse');
      expect(rig.art('rabbit').id, 'mouse');
      expect(rig.art('bot').id, 'bot');
    });

    test('a person\'s choice keeps the five ids a person may pick', () {
      for (final id in _ids.take(5)) {
        expect(rig.selectableOrDefault(id), id);
      }
    });

    test('a missing, empty, unknown or RepBot choice becomes the mouse', () {
      for (final id in [null, '', 'rabbit', 'avatar_01', 'Bear', 'bot']) {
        expect(rig.selectableOrDefault(id), 'mouse', reason: '$id');
      }
    });
  });

  group('the stage values (spec 6)', () {
    test('every attack ends at the same place: the front glove at x 136-141, '
        'y 90-97, as measured in hit_contact.json', () {
      const measured = {
        'mouse': (137.0, 96.0),
        'kangaroo': (138.0, 96.0),
        'bear': (137.0, 96.0),
        'penguin': (139.0, 91.0),
        'seal': (140.0, 91.0),
        'bot': (138.0, 96.0),
      };
      for (final id in _ids) {
        final (x, y) = _place(rig.art(id).poses['atk']!.transform('g2'), 0, 0);
        expect(x, inInclusiveRange(136, 141), reason: id);
        expect(y, inInclusiveRange(90, 97), reason: id);
        expect(x, closeTo(measured[id]!.$1, 0.5), reason: id);
        expect(y, closeTo(measured[id]!.$2, 0.5), reason: id);
      }
    });

    test(
      'the hit star sits 48 px toward the one hit, 58 px above the floor',
      () {
        expect((rig.hitStarDx, rig.hitStarUp), (48, 58));
      },
    );

    test('the opponent idles 230 ms later', () {
      expect(rig.idleOpponentOffsetMs, 230);
    });

    test('the rig\'s W2 breathing is the exact one to its rounding', () {
      final rounded = rig.idleMotionW2Default;
      const exact = CharacterIdleMotion.w2Default;
      expect(rounded.stretch, exact.stretch);
      expect(rounded.stretchPeriodMs, closeTo(exact.stretchPeriodMs, 0.01));
      expect(rounded.hopAmp + rounded.rockDeg + rounded.squash, 0);
    });

    test('each character has its own idle motion (spec 6 table)', () {
      final mouse = rig.art('mouse').idleMotion;
      expect((mouse.hopAmp, mouse.hopPeriodMs), (3, 320));
      final kangaroo = rig.art('kangaroo').idleMotion;
      expect((kangaroo.hopAmp, kangaroo.hopPeriodMs), (6, 460));
      final bear = rig.art('bear').idleMotion;
      expect(
        (bear.stretch, bear.squash, bear.stretchPeriodMs),
        (0.01, 0.03, 2400),
      );
      final penguin = rig.art('penguin').idleMotion;
      expect((penguin.rockDeg, penguin.rockPeriodMs), (4, 1300));
      final seal = rig.art('seal').idleMotion;
      expect(
        (seal.stretch, seal.squash, seal.stretchPeriodMs),
        (0.03, 0.03, 1100),
      );
      final bot = rig.art('bot').idleMotion;
      expect((bot.rockDeg, bot.rockPeriodMs, bot.stepped), (1.5, 1200, true));
      expect(mouse.stepped, isFalse);
    });
  });

  group('a malformed rig is rejected', () {
    test('not a JSON object, or not JSON at all', () {
      expect(() => CharacterRig.parse('[]'), throwsFormatException);
      expect(() => CharacterRig.parse('{'), throwsFormatException);
    });

    test('a value of the wrong type says where it was', () {
      final source = _source()..['box'] = 'wide';
      expect(
        () => CharacterRig.parse(jsonEncode(source)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('rig:'),
          ),
        ),
      );
    });

    test('a character in the order that is not drawn', () {
      _expectRejected((s) => (s['order'] as List).add('rabbit'));
    });

    test('a default character that is not in the order', () {
      _expectRejected((s) => s['defaultCharacter'] = 'rabbit');
    });

    test('a pose missing from a character', () {
      _expectRejected((s) => (_mouse(s)['poses'] as Map).remove('ko'));
    });

    test('a value missing from a pose', () {
      _expectRejected((s) => (_mouse(s)['poses']['atk'] as Map).remove('g2'));
    });

    test('an unknown move, or a move with the wrong count of numbers', () {
      _expectRejected(
        (s) => _mouse(s)['poses']['atk']['g2'] = [
          ['k', 1, 2],
        ],
      );
      _expectRejected(
        (s) => _mouse(s)['poses']['atk']['g2'] = [
          ['t', 1],
        ],
      );
    });

    test('an unknown path step, or a step with the wrong count of numbers', () {
      _expectRejected(
        (s) => _mouse(s)['poses']['atk']['l1'] = [
          ['m', 1, 2],
        ],
      );
      _expectRejected(
        (s) => _mouse(s)['poses']['atk']['l1'] = [
          ['Q', 1, 2],
        ],
      );
    });

    test('an unknown shape, color or line end', () {
      Map<String, dynamic> prim(Map<String, dynamic> s) =>
          (_mouse(s)['ops'] as List).first['prim'] as Map<String, dynamic>;
      _expectRejected((s) => prim(s)['type'] = 'star');
      _expectRejected((s) => prim(s)['stroke'] = 'lime');
      _expectRejected((s) => prim(s)['stroke'] = 7);
      _expectRejected((s) => prim(s)['cap'] = 'square');
    });

    test('an empty move or path step', () {
      _expectRejected((s) => _mouse(s)['poses']['atk']['g2'] = [[]]);
      _expectRejected((s) => _mouse(s)['poses']['atk']['l1'] = [[]]);
    });

    test('a shape without the geometry it needs', () {
      Map<String, dynamic> first(Map<String, dynamic> s, String type) =>
          (_mouse(s)['ops'] as List).firstWhere(
                (op) => op['prim']['type'] == type,
              )['prim']
              as Map<String, dynamic>;
      _expectRejected((s) => first(s, 'circle').remove('r'));
      _expectRejected((s) => first(s, 'ellipse').remove('ry'));
      _expectRejected((s) => first(s, 'rect').remove('rx'));
      _expectRejected((s) => first(s, 'path').remove('d'));
    });

    test('a number that is not a number', () {
      _expectRejected((s) => s['hitStar'] = {'dx': '48', 'up': 58});
    });
  });

  test('a pose table asked for a key it lacks throws', () {
    final table = rig.art('mouse').poses['idle']!;
    expect(() => table.transform('wing'), throwsFormatException);
    expect(() => table.path('wing'), throwsFormatException);
  });
}
