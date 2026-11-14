import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/character_rig_data.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/character_draw_patch.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/character_motion.dart';

const _ids = ['mouse', 'kangaroo', 'bear', 'penguin', 'seal'];

final _w3 = CharacterRig.standard;
final _home = CharacterMotionRig.standard;

/// The W3 drawing list of [id] as written in the rig.
List<dynamic> _w3Ops(String id) =>
    (jsonDecode(characterRigJson)
            as Map<String, dynamic>)['characters'][id]['ops']
        as List;

CharacterFigurePainter _painter(
  CharacterArt art, {
  RigPoseTable? values,
  Set<String>? tags,
  List<CharacterDrawPatch> patches = const [],
  Set<String> flags = const {},
  List<CharacterOpMatch> effects = const [],
}) => CharacterFigurePainter(
  rig: _w3,
  art: art,
  teamColor: AppColors.accent,
  values: values,
  tags: tags,
  patches: patches,
  flags: flags,
  effects: effects,
);

/// [painter] on a white ground, 2x, with room around the box.
Future<Uint8List> _render(CharacterFigurePainter painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  canvas.translate(60, 40);
  canvas.scale(2);
  painter.paint(canvas, const Size(140, 160));
  final image = await recorder.endRecording().toImage(400, 400);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

int _differentPixels(Uint8List a, Uint8List b) {
  var different = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
      different++;
    }
  }
  return different;
}

/// A patch read from JSON.
CharacterDrawPatch _patch(Map<String, dynamic> json) =>
    CharacterDrawPatch.fromJson(json);

void main() {
  group('the five characters\' patches (W4 spec 8, "그리기 검사")', () {
    for (final id in _ids) {
      test('$id: every patch is aimed at exactly one W3 shape', () {
        final art = _w3.art(id);
        for (final patch in _home.characters[id]!.drawPatch) {
          expect(
            art.ops.where((op) => sameRigOp(op, patch.target)),
            hasLength(1),
            reason: '$id ${patch.kind.name} ${patch.group}',
          );
        }
        expect(
          () => characterDrawList(
            art,
            _home.characters[id]!.drawPatch,
            _home.effects,
          ),
          returnsNormally,
        );
      });
    }

    test('the patches are the spec\'s: back gloves, the tail fur, the '
        'paddles and the belly', () {
      String describe(CharacterDrawPatch p) =>
          '${p.kind.name}:${p.group ?? p.condition ?? p.append.join()}';
      expect(
        {
          for (final id in _ids)
            id: [for (final p in _home.characters[id]!.drawPatch) describe(p)],
        },
        {
          'mouse': ['insertAfter:backGlove', 'onlyWhen:!gBack'],
          'kangaroo': [
            'insertAfter:tailInner',
            'insertAfter:backGlove',
            'onlyWhen:!gBack',
          ],
          'bear': <String>[],
          'penguin': <String>[],
          'seal': [
            'onlyWhen:!pa',
            'onlyWhen:!pa',
            'appendChain:belly',
            'insertAfter:paddle',
            'onlyWhen:!pa',
            'onlyWhen:!pa',
            'onlyWhen:!pa',
            'onlyWhen:!pa',
            'insertAfter:paddle',
          ],
        },
      );
    });

    for (final id in _ids) {
      test('$id: added shapes sit right after their W3 shape, the flags and '
          'the belly where the patches say', () {
        final art = _w3.art(id);
        final patches = _home.characters[id]!.drawPatch;
        final list = characterDrawList(art, patches, const []);
        final added = patches
            .where((p) => p.kind == CharacterPatchKind.insertAfter)
            .expand((p) => p.ops)
            .length;
        expect(list, hasLength(art.ops.length + added));
        int indexOfW3(RigOp target) => list.indexWhere(
          (item) => art.ops.contains(item.op) && sameRigOp(item.op, target),
        );
        for (final patch in patches) {
          switch (patch.kind) {
            case CharacterPatchKind.insertAfter:
              final at = indexOfW3(patch.target);
              for (var i = 0; i < patch.ops.length; i++) {
                expect(list[at + 1 + i].op, same(patch.ops[i].op));
                expect(
                  '${list[at + 1 + i].condition}',
                  '${patch.ops[i].condition}',
                );
              }
            case CharacterPatchKind.onlyWhen:
              expect(
                '${list[indexOfW3(patch.target)].condition}',
                '${patch.condition}',
              );
            case CharacterPatchKind.appendChain:
              final belly = list.singleWhere(
                (item) => item.op.chain.any((part) => part.key == 'belly'),
              );
              expect(
                [for (final part in belly.op.chain) part.key],
                ['torso', 'belly'],
              );
              // The W3 belly with the belly key added, nothing else.
              expect(
                sameRigOp(
                  RigOp(
                    chain: belly.op.chain.sublist(0, 1),
                    show: belly.op.show,
                    prim: belly.op.prim,
                  ),
                  patch.target,
                ),
                isTrue,
              );
          }
        }
      });
    }

    test('the back glove copy equals the front glove, yet the front one is '
        'the one turned off', () {
      final art = _w3.art('mouse');
      final list = characterDrawList(
        art,
        _home.characters['mouse']!.drawPatch,
        const [],
      );
      final gloves = [
        for (final (i, item) in list.indexed)
          if (item.op.chain.length == 1 &&
              item.op.chain.single.key == 'g1' &&
              item.op.prim.shape == RigShape.circle)
            (i, '${item.condition}', art.ops.contains(item.op)),
      ];
      // The copy (added, behind the body) first, then the W3 front glove.
      expect(gloves, hasLength(2));
      expect((gloves[0].$2, gloves[0].$3), ('gBack', false));
      expect((gloves[1].$2, gloves[1].$3), ('!gBack', true));
      expect(gloves[0].$1, lessThan(gloves[1].$1));
    });

    test('every character paints every key pose with both expressions', () {
      var drawn = 0;
      for (final id in _ids) {
        final home = _home.characters[id]!;
        for (final pose in home.keyPoses.values) {
          for (final expression in ['idle', 'atk']) {
            final recorder = ui.PictureRecorder();
            _painter(
              _w3.art(id),
              values: pose,
              tags: _home.tagsOf(expression, id),
              patches: home.drawPatch,
              flags: home.motion.flags,
              effects: _home.effects,
            ).paint(Canvas(recorder), const Size(140, 160));
            recorder.endRecording().dispose();
            drawn++;
          }
        }
      }
      // Two key poses each, the bear's three.
      expect(drawn, (2 + 2 + 3 + 2 + 2) * 2);
    });
  });

  group('the five stage effects are not drawn', () {
    test('each effect rule finds its W3 shapes, and only W3 ones', () {
      final counts = <String, int>{};
      for (final id in _ids) {
        final list = characterDrawList(
          _w3.art(id),
          _home.characters[id]!.drawPatch,
          _home.effects,
        );
        counts[id] = list.where((item) => item.effect).length;
        for (final item in list.where((item) => item.effect)) {
          expect(_w3.art(id).ops, contains(item.op), reason: id);
        }
      }
      // hit lines 1, ko stars 2, win sparkles 1; the penguin's and the
      // seal's attack also have the fin hand and the swing lines.
      expect(counts, {
        'mouse': 4,
        'kangaroo': 4,
        'bear': 4,
        'penguin': 6,
        'seal': 6,
      });
      for (final (i, match) in _home.effects.indexed) {
        expect(
          _ids.any((id) => _w3.art(id).ops.any(match.matches)),
          isTrue,
          reason: 'effect $i',
        );
      }
    });

    for (final (id, tags) in [
      ('penguin', {'atk'}),
      ('seal', {'atk'}),
      ('mouse', {'hit', 'ko', 'win'}),
    ]) {
      test(
        '$id with $tags draws as if the effect shapes were not there',
        () async {
          final art = _w3.art(id);
          final home = _home.characters[id]!;
          final pose = home.keyPoses.values.last;
          final effectIndices = [
            for (final (i, op) in art.ops.indexed)
              if (_home.effects.any((m) => m.matches(op))) i,
          ];
          expect(effectIndices, isNotEmpty);
          final source = jsonDecode(characterRigJson) as Map<String, dynamic>;
          final ops = source['characters'][id]['ops'] as List;
          for (final i in effectIndices.reversed) {
            ops.removeAt(i);
          }
          final without = CharacterRig.parse(jsonEncode(source)).art(id);
          final skipped = await _render(
            _painter(art, values: pose, tags: tags, effects: _home.effects),
          );
          final removed = await _render(
            _painter(without, values: pose, tags: tags),
          );
          expect(_differentPixels(skipped, removed), 0);
          // And the effects would show without the rule.
          final kept = await _render(_painter(art, values: pose, tags: tags));
          expect(_differentPixels(skipped, kept), greaterThan(0));
        },
      );
    }

    test('a stage pose by name still draws them', () async {
      final art = _w3.art('mouse');
      final stage = await _render(
        CharacterFigurePainter(
          rig: _w3,
          art: art,
          pose: 'ko',
          teamColor: AppColors.accent,
        ),
      );
      final source = jsonDecode(characterRigJson) as Map<String, dynamic>;
      (source['characters']['mouse']['ops'] as List).removeWhere(
        (op) => (op['chain'] as List).any(
          (part) => part is Map && part['key'] == 'fx',
        ),
      );
      final noStars = CharacterRig.parse(jsonEncode(source)).art('mouse');
      final without = await _render(
        CharacterFigurePainter(
          rig: _w3,
          art: noStars,
          pose: 'ko',
          teamColor: AppColors.accent,
        ),
      );
      expect(_differentPixels(stage, without), greaterThan(0));
    });
  });

  group('the motion flags', () {
    test('with gBack off the push-up patches draw the W3 gloves; on, the '
        'far glove goes behind the body', () async {
      for (final id in ['mouse', 'kangaroo']) {
        final art = _w3.art(id);
        final home = _home.characters[id]!;
        final gloves = home.drawPatch
            .where((p) => p.group != 'tailInner')
            .toList();
        for (final name in ['up', 'down']) {
          final pose = home.keyPoses[name]!;
          final plain = await _render(_painter(art, values: pose));
          final off = await _render(
            _painter(art, values: pose, patches: gloves),
          );
          expect(_differentPixels(off, plain), 0, reason: '$id $name');
        }
        // At the bottom the body covers the far glove (at the top the two
        // hardly meet).
        final down = home.keyPoses['down']!;
        final plain = await _render(_painter(art, values: down));
        final back = await _render(
          _painter(art, values: down, patches: gloves, flags: {'gBack'}),
        );
        expect(_differentPixels(back, plain), greaterThan(100), reason: id);
      }
    });

    test('pa swaps the seal\'s W3 arms for the paddle fins', () async {
      final art = _w3.art('seal');
      final home = _home.characters['seal']!;
      final list = characterDrawList(art, home.drawPatch, const []);
      final paddles = list.where(
        (item) => item.op.chain.any((p) => p.key == 'p1' || p.key == 'p2'),
      );
      expect(paddles, hasLength(5));
      for (final item in paddles) {
        expect('${item.condition}', 'pa');
      }
      final arms = list.where(
        (item) =>
            {'a1', 'a2', 'wb', 'wc'}.contains(item.op.prim.pathKey) &&
            art.ops.contains(item.op),
      );
      expect(arms, hasLength(6));
      for (final item in arms) {
        expect('${item.condition}', '!pa');
      }
      final pose = home.keyPoses['down']!;
      final fins = await _render(
        _painter(art, values: pose, patches: home.drawPatch, flags: {'pa'}),
      );
      final armsDrawn = await _render(
        _painter(art, values: pose, patches: home.drawPatch),
      );
      expect(_differentPixels(fins, armsDrawn), greaterThan(0));
    });

    test('a flag test reads "flag" and "!flag"', () {
      expect(CharacterFlagTest.parse(null), isNull);
      final on = CharacterFlagTest.parse('gBack')!;
      expect((on.flag, on.on, '$on'), ('gBack', true, 'gBack'));
      expect(on.passes({'gBack'}), isTrue);
      expect(on.passes({}), isFalse);
      final off = CharacterFlagTest.parse('!pa')!;
      expect((off.flag, off.on, '$off'), ('pa', false, '!pa'));
      expect(off.passes({}), isTrue);
      expect(off.passes({'pa'}), isFalse);
      expect(() => CharacterFlagTest.parse('!'), throwsFormatException);
    });
  });

  group('patches as W5 adds them', () {
    Map<String, dynamic> eyeTarget() {
      // The mouse's first W3 shape with a fixed move after its head.
      final op = _w3Ops('mouse').firstWhere(
        (op) => (op['chain'] as List).length == 2,
      ) as Map<String, dynamic>;
      return {'chain': op['chain'], 'prim': op['prim']};
    }

    Map<String, dynamic> dot(double x) => {
      'chain': <Object>[],
      'show': ['teeth'],
      'prim': {'type': 'circle', 'cx': x, 'cy': 0, 'r': 1, 'fill': '#FFFFFF'},
    };

    test('a fixed move written alone in the chain finds its W3 shape', () {
      final target = eyeTarget();
      final chain = target['chain'] as List;
      // ["t", -4, 1] instead of [["t", -4, 1]], as W5's file writes it.
      final flat = {
        'chain': [chain[0], ...(chain[1] as List)],
        'prim': target['prim'],
      };
      final patch = _patch({
        'kind': 'insertAfter',
        'after': flat,
        'ops': [dot(1)],
      });
      final list = characterDrawList(_w3.art('mouse'), [patch], const []);
      final at = list.indexWhere((item) => item.op == patch.ops.single.op);
      expect(sameRigOp(list[at - 1].op, patch.target), isTrue);
    });

    test('a later patch at the same shape goes before an earlier one\'s '
        'shapes, and its tags show only for them', () {
      final first = _patch({
        'kind': 'insertAfter',
        'after': eyeTarget(),
        'ops': [dot(1)],
      });
      final second = _patch({
        'kind': 'insertAfter',
        'after': eyeTarget(),
        'ops': [dot(2)],
      });
      final list = characterDrawList(_w3.art('mouse'), [
        first,
        second,
      ], const []);
      final a = list.indexWhere((item) => item.op == first.ops.single.op);
      final b = list.indexWhere((item) => item.op == second.ops.single.op);
      expect(b, a - 1);
      expect(first.ops.single.op.show, {'teeth'});
    });

    test('a patch with no W3 shape to aim at is an error', () {
      final patch = _patch({
        'kind': 'onlyWhen',
        'flag': 'pa',
        'match': {
          'chain': <Object>[],
          'prim': {'type': 'circle', 'cx': 999, 'cy': 0, 'r': 1},
        },
      });
      expect(
        () => characterDrawList(_w3.art('bear'), [patch], const []),
        throwsStateError,
      );
    });
  });

  group('reading and comparing shapes', () {
    test('a malformed patch or effect rule is a FormatException', () {
      expect(
        () => _patch({'kind': 'replace', 'match': eyeless}),
        throwsFormatException,
      );
      expect(
        () => _patch({'kind': 'onlyWhen', 'flag': 'pa'}),
        throwsFormatException,
      );
      expect(
        () => _patch({
          'kind': 'insertAfter',
          'after': eyeless,
          'ops': [
            {
              'chain': <Object>[],
              'show': null,
              'prim': {'type': 'blob'},
            },
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => CharacterOpMatch.fromJson({
          'prim': {'fill': '#FFFFFF'},
        }),
        throwsFormatException,
      );
      expect(() => CharacterOpMatch.fromJson(const {}), throwsFormatException);
      expect(
        () => CharacterOpMatch.fromJson({'chainKey': 3}),
        throwsFormatException,
      );
    });

    test('shapes read as the W3 rig reads them: cubic paths, team colors', () {
      final ops = readRigOps([
        {
          'chain': [
            {'key': 'p2'},
          ],
          'show': null,
          'prim': {
            'type': 'path',
            'd': [
              ['M', -7, -3],
              ['C', -8.5, 7, -10.5, 17, -7, 24],
              ['Z'],
            ],
            'fill': 'team',
            'stroke': '#141A26',
            'strokeWidth': 4,
            'cap': 'butt',
          },
        },
      ]);
      final prim = ops.single.prim;
      expect(
        [for (final s in prim.segments) s.command],
        [RigCommand.move, RigCommand.cubic, RigCommand.close],
      );
      expect(prim.fill!.team, isTrue);
      expect(prim.stroke!.argb, 0xFF141A26);
      expect(prim.roundCap, isFalse);
      expect(ops.single.chain.single.key, 'p2');
    });

    test('the same shape: chain and drawn part, whatever its poses', () {
      RigOp read(Map<String, dynamic> prim, {List<Object?>? show}) =>
          readRigOps([
            {
              'chain': [
                {'key': 'head'},
              ],
              'show': show,
              'prim': prim,
            },
          ]).single;
      const circle = {'type': 'circle', 'cx': 1, 'cy': 2, 'r': 3};
      expect(sameRigOp(read(circle), read(circle, show: ['idle'])), isTrue);
      expect(sameRigOp(read(circle), read({...circle, 'r': 3.5})), isFalse);
      expect(
        sameRigOp(
          read({...circle, 'stroke': '#141A26', 'strokeWidth': 2}),
          read({...circle, 'stroke': '#141A26', 'strokeWidth': 3}),
        ),
        isFalse,
      );
      expect(
        sameRigOp(
          read({...circle, 'fill': 'team'}),
          read({...circle, 'fill': '#C6FF3D'}),
        ),
        isFalse,
      );
    });

    test('an effect rule checks every field it gives', () {
      final penguin = _w3.art('penguin').ops;
      final finHand = _home.effects.first;
      expect(penguin.where(finHand.matches), hasLength(1));
      const wrongKey = CharacterOpMatch(
        chainKey: 'g1',
        prim: {'type': 'ellipse', 'cx': 0, 'cy': 0, 'rx': 17, 'ry': 9.5},
      );
      expect(penguin.where(wrongKey.matches), isEmpty);
      const wrongStart = CharacterOpMatch(pathStartsWith: ['L', 104, 60]);
      expect(penguin.where(wrongStart.matches), isEmpty);
      // A path a pose gives has no fixed first step.
      const legStart = CharacterOpMatch(pathStartsWith: ['M', 0, 0]);
      expect(
        _w3
            .art('mouse')
            .ops
            .where((op) => op.prim.pathKey != null && legStart.matches(op)),
        isEmpty,
      );
    });

    test('a list is built once for the same art and patches', () {
      final art = _w3.art('seal');
      final patches = _home.characters['seal']!.drawPatch;
      expect(
        characterDrawList(art, patches, _home.effects),
        same(characterDrawList(art, List.of(patches), _home.effects)),
      );
      expect(
        characterDrawList(art, const [], const []),
        same(characterDrawList(art, const [], const [])),
      );
      expect(
        characterDrawList(art, patches, const []),
        isNot(same(characterDrawList(art, patches, _home.effects))),
      );
    });

    test('every path step letter is the rigs\' one', () {
      expect(
        [for (final c in RigCommand.values) rigCommandLetter(c)],
        ['M', 'L', 'Q', 'C', 'A', 'Z'],
      );
    });
  });
}

/// A shape no character has.
const eyeless = {
  'chain': <Object>[],
  'prim': {'type': 'circle', 'cx': -50, 'cy': -50, 'r': 1},
};
