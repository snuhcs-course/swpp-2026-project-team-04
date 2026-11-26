// The A7 scenes of a loss and a draw against the design (LdA "거울 컷인").
//
// How victory_defeat_golden.json was made (the script and the design stay
// outside the repo): a node script read the design file LdA.dc.html, took
// its `class Component extends DCLogic` script and ran its own
// `renderVals()` with the props char = each of the five characters, op =
// penguin, result = lose or draw, live = false, still = false and t = each
// time, and once with still = true (the reduced-motion look, written as
// tMs "still"). Before that it made `Number.prototype.toFixed` return the
// number in full: the design rounds positions to 0.1 px for its CSS, which is
// coarser than the 0.01 tolerance here, so the golden holds the formulas'
// own values. It read the CSS strings back as numbers: a box placed by
// `translate(X, Y) scale(sx, sy)` with its feet at (70, 150) has its feet at
// (X + 70, Y + 150) and is sx by sy times its size (sx < 0: facing left);
// clip polygons and the inset rectangle are as written; the spark's middle
// is its SVG box's (left + 100, top + 100). The times are SPEC 6's (loss
// 0.15, 0.40, 0.64, 1.20, 1.75, 2.00 s; draw 0.20, 0.42, 0.56, 1.00, 1.70,
// 2.00 s) and times inside every stretch and next to every switch, so a
// wrong ease or a step one ms off shows. Only the big feet x of a loss
// depends on the character, so a draw is written once and the loss's rain
// (the same for all) once by time.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_idle_motion.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/victory_defeat.dart';
import 'package:gymrats_app/widgets/victory_motion.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

import 'victory_test_support.dart';

final _golden = jsonDecode(
  File('test/widgets/victory_defeat_golden.json').readAsStringSync(),
) as Map<String, dynamic>;

final _tolerance = (_golden['tolerance'] as num).toDouble();

Matcher _near(Object? value) => closeTo((value as num).toDouble(), _tolerance);

void _expectPoint(Offset actual, Object? golden, String where) {
  final xy = golden as List;
  expect(actual.dx, _near(xy[0]), reason: '$where x');
  expect(actual.dy, _near(xy[1]), reason: '$where y');
}

void _expectPolygon(List<Offset> actual, Object? golden, String where) {
  final points = golden as List;
  expect(actual, hasLength(points.length), reason: where);
  for (final (i, point) in points.indexed) {
    _expectPoint(actual[i], point, '$where $i');
  }
}

List<Map<String, dynamic>> _samples(Object? list) =>
    (list as List).cast<Map<String, dynamic>>();

VictoryScene _scene(
  String id,
  VictoryResult result, {
  Size size = designSize,
  Offset seat = designSeat,
  String opponentId = 'penguin',
}) {
  final rig = VictoryRig.standard;
  return VictoryScene(
    rig: rig,
    character: rig.characterOf(id),
    result: result,
    layout: VictoryLayout(size: size, seat: seat, values: rig.scene),
    opponentId: opponentId,
  );
}

/// The frame at the golden [sample]'s time (the end look for "still").
VictoryFrame _frameOf(VictoryScene scene, Map<String, dynamic> sample) =>
    switch (sample['tMs']) {
      'still' => scene.end,
      final num t => scene.at(t.toDouble()),
      final other => throw ArgumentError.value(other, 'tMs'),
    };

/// Fails unless [frame] shows what the golden [sample] does.
void _expectDefeat(
  VictoryScene scene,
  VictoryFrame frame,
  Map<String, dynamic> sample,
  String at,
) {
  final draw = scene.result == VictoryResult.draw;

  final stand = sample['stand'] as Map<String, dynamic>?;
  if (stand == null) {
    expect(frame.stand, isNull, reason: '$at stand');
  } else {
    final actual = frame.stand!;
    expect(actual.opacity, _near(stand['opacity']), reason: '$at stand');
    expect(actual.scaleX, _near(stand['scaleX']), reason: '$at stand');
    expect(actual.rect, const Rect.fromLTWH(244, 165, 84, 12));
    switch (stand['fill']) {
      case 'white':
        expect(actual.color, AppColors.card, reason: '$at stand');
        expect(actual.rightColor, isNull, reason: '$at stand');
      case 'limePink':
        expect(actual.color, AppColors.accent, reason: '$at stand');
        expect(actual.rightColor, AppColors.opponent, reason: '$at stand');
      default:
        fail('$at stand ${stand['fill']}');
    }
  }

  final panel = sample['panel'] as Map<String, dynamic>?;
  if (panel == null) {
    expect(frame.panel, isNull, reason: '$at panel');
    expect(frame.rain, isEmpty, reason: '$at rain');
  } else {
    var actual = frame.panel!;
    expect(actual.opacity, _near(panel['opacity']), reason: '$at panel');
    final inset = panel['inset'] as Map<String, dynamic>?;
    if (inset == null) {
      expect(actual, isNot(isA<VictoryShrink>()), reason: '$at panel');
    } else {
      final shrink = actual as VictoryShrink;
      for (final (name, value) in [
        ('top', shrink.top),
        ('right', shrink.right),
        ('bottom', shrink.bottom),
        ('left', shrink.left),
        ('radius', shrink.radius),
      ]) {
        expect(value, _near(inset[name]), reason: '$at inset $name');
      }
      actual = shrink.inner!;
    }
    if (draw) {
      expect(panel['lose'], isNull);
      final split = actual as VictorySplit;
      _expectPolygon(split.lime, panel['lime']['clip'], '$at lime');
      _expectPolygon(split.pink, panel['pink']['clip'], '$at pink');
      if (panel['seam'] == true) {
        // The design's ink line M216 0 L144 780.
        _expectPoint(split.seam!.top, [216, 0], '$at seam');
        _expectPoint(split.seam!.bottom, [144, 780], '$at seam');
      } else {
        expect(split.seam, isNull, reason: '$at seam');
      }
      expect(frame.rain, isEmpty, reason: '$at rain');
    } else {
      expect(panel['lime'], isNull);
      expect(panel['pink'], isNull);
      final shutter = actual as VictoryShutter;
      final clip = panel['lose']['clip'];
      if (clip == null) {
        expect(shutter.polygon, isNull, reason: '$at shutter');
      } else {
        _expectPolygon(shutter.polygon!, clip, '$at shutter');
      }
      final rain = _samples([
        for (final drop in _golden['rain']['${sample['tMs']}'] as List)
          {'x': (drop as List)[0], 'y': drop[1], 'deg': drop[2]},
      ]);
      expect(frame.rain, hasLength(rain.length), reason: '$at rain');
      for (final (i, drop) in rain.indexed) {
        _expectPoint(frame.rain[i].topLeft, [
          drop['x'],
          drop['y'],
        ], '$at rain $i');
        expect(VictoryDefeat.rainTurnDeg, _near(drop['deg']));
      }
    }
  }

  final me = sample['me'] as Map<String, dynamic>?;
  final opponent = sample['opponent'] as Map<String, dynamic>?;
  if (draw) {
    // Never the frustration in a draw.
    expect(frame.figure, isNull, reason: '$at figure');
    final fighters = frame.fighters;
    expect(
      fighters,
      hasLength((me == null ? 0 : 1) + (opponent == null ? 0 : 1)),
      reason: '$at fighters',
    );
    if (opponent != null) {
      _expectFighter(fighters.first, opponent, BattleSide.opponent, at);
      expect(fighters.first.characterId, scene.opponentId);
    }
    if (me != null) {
      _expectFighter(fighters.last, me, BattleSide.me, at);
      expect(fighters.last.characterId, scene.character.id);
    }
  } else {
    expect(frame.fighters, isEmpty, reason: '$at fighters');
    if (me == null) {
      expect(frame.figure, isNull, reason: '$at figure');
    } else {
      final figure = frame.figure!;
      expect(figure.opacity, _near(me['opacity']), reason: '$at me');
      _expectPoint(figure.foot, me['foot'], '$at me foot');
      expect(
        figure.scale * figure.stretchX,
        _near(me['scaleX']),
        reason: '$at me scaleX',
      );
      expect(
        figure.scale * figure.stretchY,
        _near(me['scaleY']),
        reason: '$at me scaleY',
      );
      expect(figure.motion, VictoryMotionKind.frustrate, reason: at);
      final frustrate = scene.character.frustrate;
      if (me['still'] == true) {
        expect(figure.still, isTrue, reason: '$at still');
        expect(identical(figure.frame, frustrate.rest), isTrue, reason: at);
      } else {
        expect(figure.timeMs, _near(me['t']), reason: '$at me t');
        final want = frustrate.frameAt(figure.timeMs!);
        expect(figure.frame.expression, want.expression, reason: at);
        expect(writtenPose(figure.frame.pose), writtenPose(want.pose));
      }
    }
  }

  final spark = sample['spark'] as Map<String, dynamic>?;
  if (spark == null) {
    expect(frame.spark, isNull, reason: '$at spark');
  } else {
    final actual = frame.spark!;
    _expectPoint(actual.center, spark['center'], '$at spark');
    expect(actual.rotDeg, _near(spark['rotDeg']), reason: '$at spark');
    expect(actual.scale, _near(spark['scale']), reason: '$at spark');
    expect(actual.opacity, _near(spark['opacity']), reason: '$at spark');
  }
  expect(frame.shake, _near(sample['shake']), reason: '$at shake');

  final band = sample['band'] as Map<String, dynamic>?;
  if (band == null) {
    expect(frame.band, isNull, reason: '$at band');
  } else {
    final actual = frame.band!;
    expect(actual.text, band['text'], reason: '$at band');
    expect(actual.opacity, _near(band['opacity']), reason: '$at band');
    expect(actual.dx, _near(band['dx']), reason: '$at band dx');
    expect(actual.dy, _near(band['dy']), reason: '$at band dy');
    expect(actual.rotDeg, _near(band['rotDeg']), reason: '$at band rot');
  }
  expect(frame.confetti, isEmpty, reason: '$at confetti');
}

void _expectFighter(
  VictoryFighter actual,
  Map<String, dynamic> golden,
  BattleSide side,
  String at,
) {
  final where = '$at ${side.name}';
  expect(actual.side, side, reason: where);
  expect(actual.opacity, _near(golden['opacity']), reason: where);
  _expectPoint(actual.foot, golden['foot'], '$where foot');
  expect(
    actual.mirrored ? -actual.scale : actual.scale,
    _near(golden['scaleX']),
    reason: '$where scaleX',
  );
  expect(actual.scale, _near(golden['scaleY']), reason: '$where scaleY');
  expect(actual.pose, switch (golden['pose']) {
    'idle' => BattlePose.idle,
    'atk' => BattlePose.attack,
    final other => fail('$where pose $other'),
  }, reason: '$where pose');
}

void main() {
  group('the golden (SPEC 6)', () {
    test('has SPEC 6\'s times and the times between, for every character', () {
      final draw = _samples(_golden['draw']).map((s) => s['tMs']).toList();
      expect(draw, containsAll([200, 420, 560, 1000, 1700, 2000, 'still']));
      expect(draw, hasLength(43));
      for (final id in victoryIds) {
        final lose = _samples(_golden['lose'][id]).map((s) => s['tMs']);
        expect(
          lose,
          containsAll([150, 400, 640, 1200, 1750, 2000, 'still']),
          reason: id,
        );
        expect(lose, hasLength(40), reason: id);
      }
      expect(_golden['screen'], [designSize.width, designSize.height]);
      expect(_golden['seat'], [designSeat.dx, designSeat.dy]);
    });

    for (final id in victoryIds) {
      test('$id: a loss matches the design at every golden time', () {
        final scene = _scene(id, VictoryResult.lose);
        for (final sample in _samples(_golden['lose'][id])) {
          _expectDefeat(
            scene,
            _frameOf(scene, sample),
            sample,
            '$id lose t=${sample['tMs']}',
          );
        }
      });

      test('$id: a draw matches the design at every golden time', () {
        final scene = _scene(id, VictoryResult.draw);
        for (final sample in _samples(_golden['draw'])) {
          _expectDefeat(
            scene,
            _frameOf(scene, sample),
            sample,
            '$id draw t=${sample['tMs']}',
          );
        }
      });
    }
  });

  group('the loss', () {
    test('its panel is AppColors.danger, the design\'s red; its stripes and '
        'rain white', () {
      expect(VictoryDefeat.loseFill, AppColors.danger);
      expect(
        VictoryDefeat.loseFill,
        parseVictoryColor(_golden['loseFill'] as String),
      );
      expect(
        VictoryDefeat.white(VictoryDefeat.loseStripeAlpha),
        AppColors.card.withValues(alpha: 0.16),
      );
      expect(VictoryDefeat.rainCount, 18);
      expect((VictoryDefeat.rainWidth, VictoryDefeat.rainHeight), (3.0, 34.0));
    });

    test('frustrates at 2.2 times on the big feet line, after landing', () {
      for (final id in victoryIds) {
        final scene = _scene(id, VictoryResult.lose);
        final rig = VictoryRig.standard;
        for (final t in <double>[700, 1000, 1400]) {
          final figure = scene.at(t).figure!;
          expect(figure.scale, closeTo(rig.scene.bigScale, 1e-9));
          expect(figure.scale, closeTo(2.2, 1e-9));
          expect(
            figure.foot,
            Offset(scene.character.bigFootX, rig.scene.bigFootY),
          );
          expect(figure.motion, VictoryMotionKind.frustrate);
          expect(figure.timeMs, (150 + t - 460).clamp(0, 760));
        }
      }
    });

    test('ends where W5\'s loss did: the frustration\'s end pose on the '
        'seat on the white stand, for 물렁범 too (its 820 ms motion stops at '
        '760 ms and then shows its end pose, as the design does)', () {
      final seal = _scene('seal', VictoryResult.lose);
      expect(seal.at(1999).figure!.timeMs, 760);
      expect(seal.character.frustrate.motion.durMs, 820);
      final end = seal.at(2000);
      expect(end.figure!.still, isTrue);
      expect(end.figure!.frame.expression, 'tongue');
      expect(end.figure!.foot, const Offset(286, 168));
      expect(end.stand!.color, AppColors.card);
    });

    test('its band is 패배 and comes from the left; a win\'s from the right', () {
      final lose = _scene('mouse', VictoryResult.lose).at(400).band!;
      expect(lose.text, '패배');
      expect(lose.dx, lessThan(0));
      final win = _scene('mouse', VictoryResult.koWin).at(400).band!;
      expect(win.dx, greaterThan(0));
      expect(win.rotDeg, VictoryRig.standard.scene.band.rotateDeg);
    });
  });

  group('the draw', () {
    test('never shows the frustration, 패배, a knocked-out or hit pose; the '
        'band says 무승부; the opponent is the one given', () {
      for (final id in victoryIds) {
        final scene = _scene(id, VictoryResult.draw, opponentId: 'seal');
        var opponentSeen = false;
        for (var t = 0.0; t <= 2100; t += 5) {
          final frame = scene.at(t);
          expect(frame.figure, isNull, reason: '$id t=$t');
          expect(frame.band?.text, anyOf(isNull, '무승부'), reason: '$id t=$t');
          for (final fighter in frame.fighters) {
            expect(
              fighter.pose,
              anyOf(BattlePose.idle, BattlePose.attack),
              reason: '$id t=$t',
            );
            if (fighter.side == BattleSide.opponent) {
              expect(fighter.characterId, 'seal');
              opponentSeen = true;
            } else {
              expect(fighter.characterId, id);
            }
          }
        }
        expect(opponentSeen, isTrue);
        expect(scene.at(900).band!.text, '무승부');
      }
    });

    test('the halves are lime (the win\'s) and pink with the design\'s '
        'stripes', () {
      final panel = VictoryRig.standard.scene.panel;
      expect(panel.fill, AppColors.accent);
      expect(panel.stripeAngleDeg, 115);
      expect(panel.stripeColor, AppColors.card.withValues(alpha: 0.4));
      expect(VictoryDefeat.pinkFill, AppColors.opponent);
      expect(VictoryDefeat.pinkStripeAngleDeg, 65);
      expect(
        VictoryDefeat.white(VictoryDefeat.pinkStripeAlpha),
        AppColors.card.withValues(alpha: 0.28),
      );
    });

    test('in guard from 880 to 1500 ms both move as the stage\'s idle, on '
        'one clock; not before, not on the way out', () {
      final scene = _scene('bear', VictoryResult.draw, opponentId: 'penguin');
      final rig = CharacterRig.standard;
      for (final t in <double>[900, 1100, 1499]) {
        final frame = scene.at(t);
        final opponent = frame.fighters.first;
        final mine = frame.fighters.last;
        expect(
          mine.idle.toString(),
          rig.art('bear').idleMotion.sampleAt(t - 880).toString(),
        );
        expect(
          opponent.idle.toString(),
          rig.art('penguin').idleMotion.sampleAt(t - 880).toString(),
        );
      }
      for (final t in <double>[300, 560, 879, 1500, 1700]) {
        for (final fighter in scene.at(t).fighters) {
          expect(
            fighter.idle.toString(),
            IdleSample.rest.toString(),
            reason: 't=$t',
          );
        }
      }
      // The end look stands still.
      expect(
        scene.end.fighters.single.idle.toString(),
        IdleSample.rest.toString(),
      );
    });
  });

  group('on another screen (the win\'s rule)', () {
    const size = Size(412, 915);
    const seat = Offset(236, 40);

    test('the panels fill the screen, the big scene is the design\'s scaled '
        'to fit, the end follows the seat', () {
      final rig = VictoryRig.standard;
      final layout = VictoryLayout(size: size, seat: seat, values: rig.scene);
      final draw = _scene('mouse', VictoryResult.draw, size: size, seat: seat);
      final split = draw.at(1000).panel! as VictorySplit;
      expect(split.lime[1], Offset(size.width / 2 + 36, 0));
      expect(split.pink.last, Offset(size.width / 2 - 36, size.height));
      final fighters = draw.at(1000).fighters;
      expect(fighters.last.foot, layout.fromDesign(const Offset(58, 610)));
      expect(fighters.first.foot, layout.fromDesign(const Offset(302, 610)));
      expect(fighters.last.scale, closeTo(1.3 * layout.designScale, 1e-9));
      final end = draw.end;
      expect(end.fighters.single.foot, seat + const Offset(86, 132));
      expect(end.stand!.rect.topLeft, seat + const Offset(44, 129));

      final lose = _scene('mouse', VictoryResult.lose, size: size, seat: seat);
      final shutter = lose.at(150).panel! as VictoryShutter;
      expect(shutter.polygon![1], Offset(size.width, 0));
      expect(
        shutter.polygon![3].dy,
        // eo(0.5) = 1 - 0.5^3.
        closeTo((size.height + 80) * 0.875 + 60, 1e-9),
      );
      expect(
        lose.at(1000).figure!.foot,
        layout.fromDesign(const Offset(173.6, 640)),
      );
      final shrink = lose.at(1920).panel! as VictoryShrink;
      expect(
        shrink.rectIn(size),
        RRect.fromLTRBR(
          seat.dx + 40,
          seat.dy + 20,
          seat.dx + 138,
          seat.dy + 144,
          const Radius.circular(18),
        ),
      );
    });
  });
}
