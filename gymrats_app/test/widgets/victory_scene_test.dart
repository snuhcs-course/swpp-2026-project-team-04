import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/victory_motion.dart';
import 'package:gymrats_app/widgets/victory_rig_data.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

import 'victory_test_support.dart';

final _rig = VictoryRig.standard;

/// Fails unless [frame] shows what the golden scene [sample] does.
void _expectScene(VictoryFrame frame, Map<String, dynamic> sample, String at) {
  final panel = sample['panel'] as Map<String, dynamic>?;
  if (panel == null) {
    expect(frame.panel, isNull, reason: '$at panel');
  } else {
    final actual = frame.panel!;
    expect(actual.opacity, near(panel['opacity']), reason: '$at panel');
    switch (panel['kind']) {
      case 'wipe':
        final wipe = actual as VictoryWipe;
        expect(wipe.x, near(panel['X']), reason: '$at panel X');
        final polygon = panel['polygon'] as List;
        expect(wipe.polygon, hasLength(polygon.length));
        for (final (i, point) in polygon.indexed) {
          expectPoint(wipe.polygon[i], point, '$at polygon $i');
        }
      case 'shrink':
        final shrink = actual as VictoryShrink;
        final inset = panel['inset'] as Map<String, dynamic>;
        expect(shrink.e, near(panel['e']), reason: '$at panel e');
        for (final (name, value) in [
          ('top', shrink.top),
          ('right', shrink.right),
          ('bottom', shrink.bottom),
          ('left', shrink.left),
          ('radius', shrink.radius),
        ]) {
          expect(value, near(inset[name]), reason: '$at inset $name');
        }
      default:
        fail('$at: panel ${panel['kind']}');
    }
  }

  final band = sample['band'] as Map<String, dynamic>?;
  if (band == null) {
    expect(frame.band, isNull, reason: '$at band');
  } else {
    expect(frame.band!.text, band['text'], reason: '$at band');
    expect(frame.band!.dx, near(band['dx']), reason: '$at band dx');
    expect(frame.band!.dy, near(band['dy']), reason: '$at band dy');
    expect(frame.band!.opacity, near(band['opacity']), reason: '$at band');
  }

  final stand = sample['platform'] as Map<String, dynamic>?;
  if (stand == null) {
    expect(frame.stand, isNull, reason: '$at stand');
  } else {
    expect(
      frame.stand!.color,
      parseVictoryColor(stand['color'] as String),
      reason: '$at stand color',
    );
    expect(frame.stand!.scaleX, near(stand['scaleX']), reason: '$at stand');
    expect(frame.stand!.opacity, near(stand['opacity']), reason: '$at stand');
    expect(frame.stand!.rect, const Rect.fromLTWH(244, 165, 84, 12));
  }

  final figure = sample['character'] as Map<String, dynamic>?;
  if (figure == null) {
    expect(frame.figure, isNull, reason: '$at character');
  } else {
    final actual = frame.figure!;
    expect(actual.opacity, near(figure['opacity']), reason: '$at opacity');
    expectPoint(actual.foot, figure['foot'], '$at foot');
    expect(actual.scale, near(figure['scale']), reason: '$at scale');
    expect(
      actual.motion,
      figure['motion'] == 'cel'
          ? VictoryMotionKind.celebrate
          : VictoryMotionKind.frustrate,
      reason: '$at motion',
    );
    if (figure['still'] == true) {
      expect(actual.still, isTrue, reason: '$at still');
    } else {
      expect(actual.timeMs, near(figure['t']), reason: '$at t');
      expect(actual.endBlend, near(figure['endBlend']), reason: '$at eb');
    }
    expectFrame(actual.frame, figure, '$at character');
  }

  final confetti = sample['confetti'] as List?;
  if (confetti != null) {
    expect(frame.confetti, hasLength(confetti.length), reason: at);
    for (final (i, piece) in confetti.cast<Map<String, dynamic>>().indexed) {
      final actual = frame.confetti[i];
      expectPoint(actual.topLeft, [piece['x'], piece['y']], '$at piece $i');
      expect(actual.rotDeg, near(piece['rotDeg']), reason: '$at piece $i');
      expect(actual.opacity, near(piece['opacity']), reason: '$at piece $i');
    }
  }
}

BattleResult _battle({
  required MatchOutcome outcome,
  GameEnd end = GameEnd.timeUp,
  BattleDeparture departure = BattleDeparture.none,
}) => BattleResult(
  matchup: const Matchup(
    exercise: ExerciseType.pushUp,
    playerName: '우현',
    opponent: Opponent(name: 'Mina', isBot: false),
  ),
  myReps: 10,
  myInvalidReps: 0,
  opponentReps: 8,
  endedAt: DateTime(2026, 11, 14),
  myScore: 100,
  opponentScore: 80,
  end: end,
  decidedOutcome: outcome,
  departure: departure,
);

void main() {
  final golden = victoryGolden['scene'] as Map<String, dynamic>;

  group('the scene (spec 9, "장면 대조")', () {
    for (final id in victoryIds) {
      test('$id: a KO win matches every golden time', () {
        final scene = designScene(id, VictoryResult.koWin);
        final samples = (golden[id]['ko'] as List).cast<Map<String, dynamic>>();
        var withConfetti = 0;
        for (final sample in samples) {
          final t = (sample['tMs'] as num).toDouble();
          _expectScene(scene.at(t), sample, '$id ko t=$t');
          if (sample['confetti'] != null) withConfetti++;
        }
        expect(samples, hasLength(17));
        expect(withConfetti, greaterThan(0));
        _expectScene(
          scene.end,
          golden[id]['koStill'] as Map<String, dynamic>,
          '$id koStill',
        );
      });

      // A7 replaced W5's loss and draw (their times are in
      // victory_defeat_scene_test.dart); a loss still ends where W5's did.
      test('$id: a loss ends on W5\'s end look (loseStill)', () {
        final lose = designScene(id, VictoryResult.lose);
        final still = golden[id]['loseStill'] as Map<String, dynamic>;
        _expectScene(lose.end, still, '$id loseStill');
        _expectScene(lose.at(lose.endMs), still, '$id lose at its end');
      });
    }

    test('a loss stops in its end look: at and after its end the frame is '
        'the still one', () {
      for (final id in victoryIds) {
        final scene = designScene(id, VictoryResult.lose);
        final end = scene.end.figure!.frame;
        for (final t in [scene.endMs, scene.endMs + 500]) {
          final frame = scene.at(t);
          expect(frame.figure!.opacity, 1);
          expect(frame.stand!.scaleX, 1);
          expect(frame.figure!.frame.expression, end.expression);
          expect(writtenPose(frame.figure!.frame.pose), writtenPose(end.pose));
          expect(frame.figure!.frame.global.sy, 1, reason: '$id t=$t');
          expect(frame.figure!.frame.global.sx, 1, reason: '$id t=$t');
        }
      }
    });

    test('a win ends at 2100 ms; a loss and a draw at 2000 ms whatever the '
        'character (A7)', () {
      expect(designScene('bear', VictoryResult.timeWin).endMs, 2100);
      expect(designScene('seal', VictoryResult.leftWin).endMs, 2100);
      for (final id in victoryIds) {
        expect(designScene(id, VictoryResult.lose).endMs, 2000, reason: id);
        expect(designScene(id, VictoryResult.draw).endMs, 2000, reason: id);
      }
    });

    test('the band reads the result (spec 4; A7 패배 and 무승부); only a win '
        'has confetti', () {
      for (final (result, words) in [
        (VictoryResult.koWin, 'KO 승리'),
        (VictoryResult.timeWin, '판정승'),
        (VictoryResult.leftWin, '기권승'),
        (VictoryResult.lose, '패배'),
        (VictoryResult.draw, '무승부'),
      ]) {
        expect(designScene('mouse', result).at(900).band!.text, words);
      }
      for (final result in [VictoryResult.lose, VictoryResult.draw]) {
        final scene = designScene('kangaroo', result);
        for (final t in [0.0, 300, 900, 1700]) {
          final frame = scene.at(t.toDouble());
          expect(frame.panel, isNotNull);
          expect(frame.confetti, isEmpty);
        }
      }
    });

    test('the layers come and go at the spec\'s times', () {
      final scene = designScene('penguin', VictoryResult.koWin);
      expect(scene.at(139).figure, isNull);
      expect(scene.at(140).figure, isNotNull);
      expect(scene.at(259).band, isNull);
      expect(scene.at(260).band, isNotNull);
      expect(scene.at(1779).band, isNotNull);
      expect(scene.at(1780).band, isNull);
      expect(scene.at(299).confetti, isEmpty);
      expect(scene.at(300).confetti, hasLength(22));
      expect(scene.at(1899).stand, isNull);
      expect(scene.at(1900).stand, isNotNull);
      expect(scene.at(1599).panel, isA<VictoryWipe>());
      expect(scene.at(1600).panel, isA<VictoryShrink>());
      final end = scene.at(2100);
      expect(end.panel, isNull);
      expect(end.band, isNull);
      expect(end.confetti, isEmpty);
      expect(end.figure!.still, isTrue);
      expect(end.stand!.opacity, 1);
    });
  });

  group('the scene\'s values', () {
    test('the seat, the stand and the panel\'s last box keep their place to '
        'the seat (spec 2 and 11.2)', () {
      final values = _rig.scene;
      expect(values.screen, designSize);
      expect(values.seatBox, const Rect.fromLTWH(200, 36, 144, 148));
      expect(values.seatFoot - values.seatBox.topLeft, const Offset(86, 132));
      expect(
        values.stand.rect.topLeft - values.seatBox.topLeft,
        const Offset(44, 129),
      );
      expect(values.seatScale, 0.66);
      expect(values.bigScale, 2.2);
      expect(values.bigFootY, 640);
      expect(values.panel.seatRect, const Rect.fromLTRB(240, 56, 338, 180));
      expect(values.confetti.pieces, hasLength(22));
    });

    test('every motion stays in the seat on the seat and on the screen '
        'below the band in the big scene (spec 2, `scene.fit`)', () {
      final fit =
          (jsonDecode(victoryRigJson) as Map<String, dynamic>)['scene']['fit']
              as Map<String, dynamic>;
      final values = _rig.scene;
      final bandBottom = values.band.top + values.band.height;
      Rect placed(Rect bounds, Offset foot, double scale) => Rect.fromLTRB(
        foot.dx + (bounds.left - 70) * scale,
        foot.dy + (bounds.top - 150) * scale,
        foot.dx + (bounds.right - 70) * scale,
        foot.dy + (bounds.bottom - 150) * scale,
      );
      void expectRect(Rect actual, Object? range, String where) {
        final r = range as Map<String, dynamic>;
        expectPoint(actual.topLeft, r['topLeft'], '$where top left');
        expectPoint(actual.bottomRight, r['bottomRight'], '$where bottom');
      }

      for (final id in victoryIds) {
        final character = _rig.characters[id]!;
        final want = fit[id] as Map<String, dynamic>;
        final celebrate = placed(
          character.celebrate.bounds,
          values.seatFoot,
          values.seatScale,
        );
        final frustrate = placed(
          character.frustrate.bounds,
          values.seatFoot,
          values.seatScale,
        );
        expectRect(celebrate, want['seatCelebrateRange'], '$id celebrate');
        expectRect(frustrate, want['seatFrustrateRange'], '$id frustrate');
        for (final rect in [celebrate, frustrate]) {
          expect(values.seatBox.contains(rect.topLeft), isTrue, reason: id);
          expect(values.seatBox.contains(rect.bottomRight), isTrue);
        }
        final big = placed(
          character.celebrate.bounds,
          Offset(character.bigFootX, values.bigFootY),
          values.bigScale,
        );
        final bigWant = want['bigScene'] as Map<String, dynamic>;
        expect(big.left, near(bigWant['left']), reason: id);
        expect(big.right, near(bigWant['right']), reason: id);
        expect(big.top, near(bigWant['top']), reason: id);
        expect(big.bottom, near(bigWant['bottom']), reason: id);
        expect(big.left, greaterThan(0), reason: id);
        expect(big.right, lessThan(values.screen.width), reason: id);
        expect(big.top, greaterThan(bandBottom), reason: id);
        // Centred across: the big scene's feet put the motion's middle at
        // the screen's.
        expect(big.center.dx, closeTo(values.screen.width / 2, 0.1));
      }
    });

    test('the colors are the palette\'s', () {
      final values = _rig.scene;
      expect(values.panel.fill, AppColors.accent);
      expect(values.stand.win, AppColors.accent);
      expect(values.stand.lose, AppColors.card);
      expect(values.band.fill, AppColors.card);
      expect(values.panel.stripeColor, AppColors.card.withValues(alpha: 0.4));
      expect(
        {for (final piece in values.confetti.pieces) piece.color},
        {
          AppColors.opponent,
          AppColors.warning,
          AppColors.fever,
          AppColors.card,
        },
      );
    });

    test('a color the rig cannot read is a FormatException', () {
      expect(parseVictoryColor('#C6FF3D'), AppColors.accent);
      expect(
        parseVictoryColor('rgba(20, 26, 38, 0.5)'),
        AppColors.ink.withValues(alpha: 0.5),
      );
      expect(() => parseVictoryColor('#FFF'), throwsFormatException);
      expect(() => parseVictoryColor('lime'), throwsFormatException);
    });

    test('on another screen the seat follows its input and the big scene '
        'is the design scaled to fit and centred', () {
      final rig = _rig;
      const size = Size(412, 915);
      const seat = Offset(240, 60);
      final scene = VictoryScene(
        rig: rig,
        character: rig.characterOf('bear'),
        result: VictoryResult.timeWin,
        layout: VictoryLayout(size: size, seat: seat, values: rig.scene),
      );
      final layout = scene.layout;
      // 412 / 360 = 1.144 is less than 915 / 780 = 1.173.
      expect(layout.designScale, closeTo(412 / 360, 1e-9));
      expect(layout.designOrigin.dx, closeTo(0, 1e-9));
      expect(
        layout.designOrigin.dy,
        closeTo((915 - 780 * 412 / 360) / 2, 1e-9),
      );
      final big = scene.at(900).figure!;
      expect(big.scale, closeTo(2.2 * 412 / 360, 1e-9));
      expect(big.foot, layout.fromDesign(const Offset(169.8, 640)));
      // The wipe reaches past the wider screen.
      final wipe = scene.at(300).panel! as VictoryWipe;
      expect(wipe.x, 412 + 200);
      expect(wipe.polygon[2], const Offset(412 + 100, 915));
      // The end: on the seat as given.
      final end = scene.end;
      expect(end.figure!.foot, seat + const Offset(86, 132));
      expect(end.figure!.scale, 0.66);
      expect(
        end.stand!.rect,
        Rect.fromLTWH(seat.dx + 44, seat.dy + 129, 84, 12),
      );
      // The panel's last box is around the seat.
      final shrunk = scene.at(2099).panel! as VictoryShrink;
      expect(
        shrunk.rectIn(size).outerRect,
        rectMoreOrLessEquals(
          Rect.fromLTRB(
            seat.dx + 40,
            seat.dy + 20,
            seat.dx + 138,
            seat.dy + 144,
          ),
          epsilon: 1e-6,
        ),
      );
    });

    test('a piece of confetti is gone from 20 below the screen, and not '
        'before it leaves', () {
      final scene = designScene('mouse', VictoryResult.koWin);
      // At 1900 ms some pieces have fallen past y 800, some not yet.
      final pieces = scene.at(1900).confetti;
      expect(pieces.where((p) => p.topLeft.dy >= 800), isNotEmpty);
      for (final piece in pieces) {
        expect(piece.opacity > 0, piece.topLeft.dy < 800);
      }
      // Before its delay a piece is not out yet.
      final first = scene.at(300).confetti;
      expect(first.every((p) => p.opacity == 0), isTrue);
    });
  });

  group('the result kinds', () {
    test('a win by KO, by time or by the opponent leaving; a loss; a draw', () {
      expect(
        VictoryResult.of(_battle(outcome: MatchOutcome.win, end: GameEnd.ko)),
        VictoryResult.koWin,
      );
      expect(
        VictoryResult.of(_battle(outcome: MatchOutcome.win)),
        VictoryResult.timeWin,
      );
      expect(
        VictoryResult.of(
          _battle(
            outcome: MatchOutcome.win,
            departure: BattleDeparture.opponentLeft,
          ),
        ),
        VictoryResult.leftWin,
      );
      expect(
        VictoryResult.of(_battle(outcome: MatchOutcome.lose, end: GameEnd.ko)),
        VictoryResult.lose,
      );
      expect(
        VictoryResult.of(
          _battle(
            outcome: MatchOutcome.lose,
            departure: BattleDeparture.myConnectionLost,
          ),
        ),
        VictoryResult.lose,
      );
      expect(
        VictoryResult.of(_battle(outcome: MatchOutcome.draw)),
        VictoryResult.draw,
      );
      expect(
        [for (final r in VictoryResult.values) r.isWin],
        [true, true, true, false, false],
      );
    });

    test('decide: leaving comes first for a win, then a KO, else time; a '
        'loss or a draw is one scene whatever ended it', () {
      for (final (outcome, byKo, opponentLeft, scene) in const [
        (MatchOutcome.win, true, false, VictoryResult.koWin),
        (MatchOutcome.win, false, false, VictoryResult.timeWin),
        (MatchOutcome.win, false, true, VictoryResult.leftWin),
        (MatchOutcome.win, true, true, VictoryResult.leftWin),
        (MatchOutcome.lose, true, false, VictoryResult.lose),
        (MatchOutcome.lose, false, false, VictoryResult.lose),
        (MatchOutcome.draw, false, false, VictoryResult.draw),
      ]) {
        expect(
          VictoryResult.decide(outcome, byKo: byKo, opponentLeft: opponentLeft),
          scene,
          reason: '$outcome ko $byKo left $opponentLeft',
        );
      }
    });
  });
}
