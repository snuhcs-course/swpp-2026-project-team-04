import 'dart:convert';
import 'dart:io';
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
import 'package:gymrats_app/widgets/victory_motion.dart';
import 'package:gymrats_app/widgets/victory_rig_data.dart';

import 'victory_test_support.dart';

final _rig = VictoryRig.standard;
final _w3 = CharacterRig.standard;
final _home = CharacterMotionRig.standard;

/// The rig's JSON with [change] made to it, read again.
VictoryRig _parseChanged(void Function(Map<String, dynamic> json) change) {
  final json = jsonDecode(victoryRigJson) as Map<String, dynamic>;
  change(json);
  return VictoryRig.parse(jsonEncode(json), home: _home);
}

/// [character]'s painter for [frame] of [kind], as the overlay draws it.
CharacterFigurePainter _painter(
  VictoryCharacter character,
  VictoryMotionKind kind,
  CharacterMotionFrame frame, {
  CharacterArt? art,
  List<CharacterOpMatch>? effects,
}) => CharacterFigurePainter(
  rig: _w3,
  art: art ?? _w3.art(character.id),
  teamColor: AppColors.accent,
  values: frame.pose,
  tags: _rig.tagsOf(frame.expression, character.id),
  patches: character.drawPatch,
  flags: character.motionOf(kind).motion.flags,
  effects: effects ?? _rig.effects,
);

/// [painter] on a white ground, 2x, with room around the box.
Future<Uint8List> _render(CharacterFigurePainter painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(AppColors.card, BlendMode.src);
  canvas.translate(60, 40);
  canvas.scale(2);
  painter.paint(canvas, const Size(140, 160));
  final image = await recorder.endRecording().toImage(400, 400);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
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

void main() {
  group('the rig data (spec 9, "데이터 검사")', () {
    test('is the bundle\'s file, also in assets/characters', () {
      final asset = File('assets/characters/w5_victory_rig.json')
          .readAsStringSync();
      expect(jsonDecode(victoryRigJson), jsonDecode(asset));
      expect(_rig.version, 'w5-victory-rig-1');
      expect(_rig.extendsVersions, ['w3-rig-2', 'w4-home-rig-1']);
      expect(_rig.extendsVersions, contains(_home.version));
      expect(_rig.extendsVersions, contains(_home.extendsVersion));
    });

    test('all five characters celebrate and frustrate, named as in W3', () {
      expect(_rig.characters.keys, victoryIds);
      for (final id in victoryIds) {
        final character = _rig.characters[id]!;
        expect(character.name, _w3.art(id).name, reason: id);
        expect(character.celebrate.motion.loop, isTrue, reason: id);
        expect(character.frustrate.motion.loop, isFalse, reason: id);
      }
    });

    test('a motion\'s key poses give every key the same steps, and every '
        'key pose the timetable, the end and the rest name is there', () {
      for (final id in victoryIds) {
        for (final kind in VictoryMotionKind.values) {
          final motion = _rig.characters[id]!.motionOf(kind);
          final where = '$id ${kind.name}';
          final named = {
            ...motion.motion.keys,
            for (final s in motion.motion.segments) ...[s.fromKey, s.toKey],
            motion.motion.restKey,
            ?motion.endKey,
          };
          expect(motion.keyPoses.keys.toSet(), containsAll(named));
          final first = writtenPose(motion.keyPoses.values.first);
          expect(first.keys, hasLength(17), reason: where);
          for (final MapEntry(key: name, value: pose)
              in motion.keyPoses.entries) {
            final written = writtenPose(pose);
            expect(written.keys.toSet(), first.keys.toSet(), reason: name);
            for (final key in first.keys) {
              expect(
                [for (final item in written[key]!) item.first],
                [for (final item in first[key]!) item.first],
                reason: '$where $name $key',
              );
            }
          }
        }
      }
    });

    test('a celebration ends in its rest; a frustration has no end and '
        'lasts as long as the scene says', () {
      for (final id in victoryIds) {
        final character = _rig.characters[id]!;
        expect(character.celebrate.endKey, character.celebrate.motion.restKey);
        expect(
          character.celebrate.endExpression,
          character.celebrate.motion.restExpression,
        );
        expect(character.frustrate.endKey, isNull, reason: id);
        expect(
          _rig.scene.loseEndMs[id],
          character.frustrate.motion.durMs,
          reason: id,
        );
      }
      expect(_rig.scene.loseEndMs['seal'], 820);
      expect(_rig.scene.loseEndMs['mouse'], 760);
    });

    test('no motion has more than one landing, so weakening the whole '
        'move by its total is the rig\'s rule', () {
      for (final id in victoryIds) {
        for (final kind in VictoryMotionKind.values) {
          final global = _rig.characters[id]!.motionOf(kind).motion.global;
          expect(
            global.where((g) => g.kind == MotionGlobalKind.land).length,
            lessThanOrEqualTo(1),
          );
        }
      }
    });

    test('the expressions map to the spec\'s tags (spec 7 "표정")', () {
      expect(_rig.tagsOf('idle', 'mouse'), {'idle'});
      expect(_rig.tagsOf('grit', 'bear'), {'atk', 'teeth'});
      expect(_rig.tagsOf('grin', 'seal'), {'grin'});
      expect(_rig.tagsOf('grin', 'mouse'), {'win'});
      expect(_rig.tagsOf('tongue', 'seal'), {'tongue'});
      expect(_rig.tagsOf('tongue', 'penguin'), {'hit'});
      expect(() => _rig.tagsOf('ko', 'mouse'), throwsArgumentError);
    });

    test('RepBot\'s and unknown ids get the default character', () {
      expect(_rig.characterOf('bot').id, 'mouse');
      expect(_rig.characterOf('nobody').id, 'mouse');
      expect(_rig.characterOf(null).id, 'mouse');
      expect(_rig.characterOf('seal').id, 'seal');
    });

    test('malformed data is a FormatException', () {
      expect(() => VictoryRig.parse('[]', home: _home), throwsFormatException);
      expect(
        () => _parseChanged((json) => json.remove('scene')),
        throwsFormatException,
      );
      // A celebration without its end pose.
      expect(
        () => _parseChanged((json) {
          final motion =
              json['characters']['mouse']['celebrate']['motion'] as Map;
          motion.remove('end');
        }),
        throwsFormatException,
      );
      // An end pose that is not there.
      expect(
        () => _parseChanged((json) {
          json['characters']['mouse']['celebrate']['motion']['end']['key'] =
              'z';
        }),
        throwsFormatException,
      );
      // A key pose with another step order.
      expect(
        () => _parseChanged((json) {
          final a1 =
              json['characters']['bear']['frustrate']['keyposes']['f1']['a1']
                  as List;
          a1[1] = ['Q', 0, 0, 0, 0];
        }),
        throwsFormatException,
      );
      // A timetable naming a missing key pose.
      expect(
        () => _parseChanged((json) {
          final keyposes =
              json['characters']['seal']['celebrate']['keyposes'] as Map;
          keyposes.remove('hit');
        }),
        throwsFormatException,
      );
      expect(
        () => _parseChanged((json) {
          (json['scene']['confettiPieces'] as List).removeLast();
        }),
        throwsFormatException,
      );
      expect(
        () => _parseChanged((json) {
          json['scene']['values']['platform']['win'] = 'lime';
        }),
        throwsFormatException,
      );
      expect(
        () => _parseChanged((json) {
          json['characters']['penguin']['bigFootX'] = '167';
        }),
        throwsFormatException,
      );
      expect(
        () => _parseChanged((json) {
          json['characters']['kangaroo']['celebrate']['motion']['seg'][0]['ease'] =
              'bounce';
        }),
        throwsFormatException,
      );
    });
  });

  group('the poses (spec 9, "포즈 대조")', () {
    final golden = victoryGolden['pose'] as Map<String, dynamic>;

    for (final id in victoryIds) {
      test('$id matches every golden sample within 0.01', () {
        final character = _rig.characters[id]!;
        final samples = golden[id] as Map<String, dynamic>;
        var compared = 0;
        for (final MapEntry(key: name, value: value) in samples.entries) {
          final list = value is List ? value : [value];
          for (final sample in list.cast<Map<String, dynamic>>()) {
            final motion = switch (sample['motion']) {
              'cel' => character.celebrate,
              'frus' => character.frustrate,
              final other => throw StateError('motion $other'),
            };
            final frame = sample['still'] == true
                ? motion.rest
                : motion.frameAt(
                    (sample['tMs'] as num).toDouble(),
                    endBlend: (sample['endBlend'] as num).toDouble(),
                  );
            expectFrame(
              frame,
              sample,
              '$id $name t=${sample['tMs']} eb=${sample['endBlend']}',
            );
            compared++;
          }
        }
        expect(compared, greaterThanOrEqualTo(18));
      });
    }

    test('the samples cover the end blends 0.3, 0.6 and 1, wrapped times '
        'and both stills', () {
      final blends = <num>{};
      var wrapped = 0;
      for (final id in victoryIds) {
        final samples = golden[id] as Map<String, dynamic>;
        expect(samples.keys, containsAll(['celebrateStill', 'frustrateStill']));
        final durMs = _rig.characters[id]!.celebrate.motion.durMs;
        for (final sample
            in (samples['celebrate'] as List).cast<Map<String, dynamic>>()) {
          blends.add(sample['endBlend'] as num);
          if ((sample['tMs'] as num) > durMs) wrapped++;
        }
      }
      expect(blends, containsAll([0.3, 0.6, 1]));
      expect(wrapped, greaterThan(0));
    });

    test('an end blend of 1 is the end pose and expression without a move', () {
      for (final id in victoryIds) {
        final motion = _rig.characters[id]!.celebrate;
        for (final t in [0.0, 130, 333]) {
          final frame = motion.frameAt(t.toDouble(), endBlend: 1);
          expect(frame.pose, same(motion.keyPoses[motion.endKey]));
          expect(frame.expression, motion.endExpression);
          expect(frame.global.up, 0);
          expect(frame.global.rotDeg, 0);
          expect(frame.global.sx, 1);
          expect(frame.global.sy, 1);
        }
      }
    });

    test('the end expression shows from a blend of 0.5', () {
      // Every celebration ends in the expression it has all along, so a
      // made-up end expression shows the switch.
      final rig = _parseChanged((json) {
        json['characters']['mouse']['celebrate']['motion']['end']['expr'] =
            'atk';
      });
      final mouse = rig.characters['mouse']!.celebrate;
      expect(mouse.frameAt(100, endBlend: 0.49).expression, 'win');
      expect(mouse.frameAt(100, endBlend: 0.5).expression, 'atk');
      // The bear frustrates with no end, so a blend leaves its frame as it
      // is.
      final bear = _rig.characters['bear']!.frustrate;
      final plain = bear.frameAt(300);
      final blended = bear.frameAt(300, endBlend: 0.8);
      expect(blended.expression, plain.expression);
      expect(writtenPose(blended.pose), writtenPose(plain.pose));
    });

    test('a weakened landing squashes by the share left', () {
      // A made-up celebration that lands, to see the landing weakened.
      final rig = _parseChanged((json) {
        json['characters']['mouse']['celebrate']['motion']['global'] = [
          {'k': 'land', 'at': 0, 'ms': 200, 'sy': 0.1, 'sx': 0.05},
        ];
      });
      final motion = rig.characters['mouse']!.celebrate;
      final full = motion.frameAt(100).global;
      final half = motion.frameAt(100, endBlend: 0.5).global;
      expect(full.sy, closeTo(0.9, 1e-9));
      expect(full.sx, closeTo(1.05, 1e-9));
      expect(half.sy, closeTo(0.95, 1e-9));
      expect(half.sx, closeTo(1.025, 1e-9));
    });

    test('blending two tables keeps the letters and goes number by number', () {
      final poses = _rig.characters['mouse']!.frustrate.keyPoses;
      final a = poses['f0']!;
      final b = poses['f2']!;
      expect(blendPoseTables(a, b, 0), same(a));
      expect(blendPoseTables(a, b, -1), same(a));
      expect(blendPoseTables(a, b, 1), same(b));
      final half = writtenPose(blendPoseTables(a, b, 0.5));
      final wa = writtenPose(a);
      final wb = writtenPose(b);
      for (final key in wa.keys) {
        for (var i = 0; i < wa[key]!.length; i++) {
          expect(half[key]![i].first, wa[key]![i].first);
          for (var j = 1; j < wa[key]![i].length; j++) {
            final x = wa[key]![i][j] as double;
            final y = wb[key]![i][j] as double;
            expect(half[key]![i][j], closeTo((x + y) / 2, 1e-9));
          }
        }
      }
    });
  });

  group('the drawing (spec 9, "그리기 검사")', () {
    test('every W4 and W5 patch finds its W3 shape, W5\'s right after it '
        'and before W4\'s paddle fin', () {
      for (final id in victoryIds) {
        final character = _rig.characters[id]!;
        final art = _w3.art(id);
        expect(character.drawPatch, [
          ..._home.characters[id]!.drawPatch,
          ...character.ownPatch,
        ]);
        // Builds without a StateError: every target found.
        final list = characterDrawList(art, character.drawPatch, _rig.effects);
        for (final patch in character.drawPatch) {
          expect(
            art.ops.where((op) => sameRigOp(op, patch.target)),
            hasLength(1),
            reason: '$id ${patch.group}',
          );
        }
        for (final patch in character.ownPatch) {
          expect(patch.kind, CharacterPatchKind.insertAfter);
          final at = list.indexWhere(
            (item) => sameRigOp(item.op, patch.target),
          );
          for (final (i, op) in patch.ops.indexed) {
            expect(
              identical(list[at + 1 + i].op, op.op),
              isTrue,
              reason: '$id W5 shape $i',
            );
          }
        }
      }
      // The seal's fin p1 (W4, after the same shape) comes after the grin and
      // the tongue.
      final seal = _rig.characters['seal']!;
      final list = characterDrawList(
        _w3.art('seal'),
        seal.drawPatch,
        _rig.effects,
      );
      final lastFace = list.lastIndexWhere(
        (item) => item.op.show?.contains('tongue') ?? false,
      );
      final paddle = list.indexWhere(
        (item) => item.condition?.flag == 'pa' && item.condition!.on,
      );
      expect(lastFace, lessThan(paddle));
    });

    test('W5 adds the teeth to four characters and the grin and the tongue '
        'to 물렁범', () {
      List<String> tagsAdded(String id) => [
        for (final patch in _rig.characters[id]!.ownPatch)
          for (final op in patch.ops) ...?op.op.show,
      ];
      for (final id in ['mouse', 'kangaroo', 'bear', 'penguin']) {
        expect(tagsAdded(id), ['teeth', 'teeth'], reason: id);
      }
      expect(tagsAdded('seal'), [
        'grin',
        'grin',
        'grin',
        'tongue',
        'tongue',
        'tongue',
      ]);
    });

    test('every character paints every key pose of both motions with each '
        'of their expressions', () {
      var drawn = 0;
      for (final id in victoryIds) {
        final character = _rig.characters[id]!;
        for (final kind in VictoryMotionKind.values) {
          final motion = character.motionOf(kind);
          final expressions = {
            for (final e in motion.motion.expressions) e.expression,
            motion.motion.restExpression,
          };
          for (final pose in motion.keyPoses.values) {
            for (final expression in expressions) {
              final recorder = ui.PictureRecorder();
              _painter(
                character,
                kind,
                CharacterMotionFrame(
                  pose: pose,
                  expression: expression,
                  global: MotionGlobal.none,
                ),
              ).paint(Canvas(recorder), const Size(140, 160));
              recorder.endRecording().dispose();
              drawn++;
            }
          }
        }
      }
      // Key poses x expressions: celebrations 2/3/3/2/3 with one each;
      // frustrations 3 with three each.
      expect(drawn, (2 + 3 + 3 + 2 + 3) + 5 * 3 * 3);
    });

    test('the five stage effects are marked in every character\'s list', () {
      for (final id in victoryIds) {
        final list = characterDrawList(
          _w3.art(id),
          _rig.characters[id]!.drawPatch,
          _rig.effects,
        );
        expect(
          list.where((item) => item.effect).length,
          id == 'penguin' || id == 'seal' ? 6 : 4,
          reason: id,
        );
      }
    });

    for (final (id, kind, expression) in [
      ('mouse', VictoryMotionKind.celebrate, 'win'),
      ('seal', VictoryMotionKind.frustrate, 'hit'),
      ('penguin', VictoryMotionKind.celebrate, 'win'),
    ]) {
      test(
        '$id\'s $expression draws as if the effect shapes were not there',
        () async {
          final character = _rig.characters[id]!;
          final motion = character.motionOf(kind);
          final frame = CharacterMotionFrame(
            pose: motion.keyPoses.values.last,
            expression: expression,
            global: MotionGlobal.none,
          );
          final art = _w3.art(id);
          final source = jsonDecode(characterRigJson) as Map<String, dynamic>;
          final ops = source['characters'][id]['ops'] as List;
          final effectIndices = [
            for (final (i, op) in art.ops.indexed)
              if (_rig.effects.any((m) => m.matches(op))) i,
          ];
          expect(effectIndices, isNotEmpty);
          for (final i in effectIndices.reversed) {
            ops.removeAt(i);
          }
          final without = CharacterRig.parse(jsonEncode(source)).art(id);
          final skipped = await _render(_painter(character, kind, frame));
          final removed = await _render(
            _painter(character, kind, frame, art: without, effects: const []),
          );
          expect(_differentPixels(skipped, removed), 0);
          // And they would show without the rule.
          final kept = await _render(
            _painter(character, kind, frame, effects: const []),
          );
          expect(_differentPixels(skipped, kept), greaterThan(0));
        },
      );
    }

    test('the gritted teeth show with grit only, the seal\'s tongue with '
        'tongue only', () async {
      Future<int> difference(String id, String a, String b) async {
        final character = _rig.characters[id]!;
        final rest = character.frustrate.rest;
        Future<Uint8List> render(String expression) => _render(
          _painter(
            character,
            VictoryMotionKind.frustrate,
            CharacterMotionFrame(
              pose: rest.pose,
              expression: expression,
              global: MotionGlobal.none,
            ),
          ),
        );
        return _differentPixels(await render(a), await render(b));
      }

      // grit = atk + teeth: the teeth are the difference to atk.
      for (final id in ['mouse', 'kangaroo', 'bear', 'penguin']) {
        expect(await difference(id, 'grit', 'atk'), greaterThan(0), reason: id);
      }
      expect(await difference('seal', 'tongue', 'hit'), greaterThan(0));
      expect(await difference('seal', 'grin', 'win'), greaterThan(0));
      // Not on the others: tongue reads as hit, grin as win.
      expect(await difference('mouse', 'tongue', 'hit'), 0);
      expect(await difference('bear', 'grin', 'win'), 0);
    });
  });
}
