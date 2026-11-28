// The PM's acceptance criteria for A7, followed through every screen:
// a battle with a winner shows the winner the win (verdict and pose) and the
// loser the loss; a draw shows both players a draw, and no screen shows
// LOSE or the frustration: not the battle stage's verdict, not the report's
// scene or title, not the 기록보관소 row nor the report opened from it.
// Also the scene's fit on small screens and large text (SPEC 7.8).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/game/online_battle_result.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/widgets/archive_match_row.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_online_events.dart';
import 'package:gymrats_app/widgets/victory_motion.dart';
import 'package:gymrats_app/widgets/victory_overlay.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';
import 'package:provider/provider.dart';

/// An online battle the server has finished at time-up with [outcome] for
/// me: I play 곰탱이, the opponent 물렁범.
OnlineBattleSession _finished(String outcome) {
  final session = OnlineBattleSession(
    endpoint: Uri.parse('wss://example.com/ws/v1/battle'),
    accessToken: 'test-only',
    character: 'bear',
    exercise: ExerciseType.pushUp,
  );
  addTearDown(session.dispose);
  final (mine, theirs) = switch (outcome) {
    'win' => (180, 120),
    'loss' => (120, 180),
    _ => (150, 150),
  };
  session
    ..playerId = 'me'
    ..opponent = const OnlinePlayer('them', '진영', 'seal')
    ..rules = battleRules
    ..durationMs = 30000
    ..startAtMs = 1792400000000
    ..endAtMs = 1792400030000
    ..myReps = 6
    ..opponentReps = 6
    ..myScore = mine
    ..opponentScore = theirs
    ..phase = OnlinePhase.finished
    ..result = {
      'reason': 'time_up',
      'ended_at_ms': 1792400030000,
      'players': [
        {'player_id': 'me', 'outcome': outcome},
        {'player_id': 'them', 'outcome': 'other'},
      ],
    };
  return session;
}

/// [home] as the app's first page, with my character 곰탱이.
Future<void> _open(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(360, 780),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 24);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final characters = CharacterViewModel(store: MemoryCharacterStore());
  addTearDown(characters.dispose);
  await characters.choose('bear');
  await tester.pumpWidget(
    ChangeNotifierProvider<CharacterViewModel>.value(
      value: characters,
      child: MaterialApp(theme: AppTheme.light, home: home),
    ),
  );
  // The seat is found after the first layout, then the clock ticks.
  await tester.pump();
  await tester.pump();
}

final _playing = find.byWidgetPredicate(
  (widget) => widget is VictoryOverlay && widget.play,
);

VictoryFrame _frameNow(WidgetTester tester) {
  final painter =
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: _playing,
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as VictoryPainter;
  return painter.frameIn(tester.getSize(_playing));
}

VictoryFrame _seatFrame(WidgetTester tester) {
  final painter =
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(VictorySeat),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as VictoryPainter;
  return painter.frameIn(VictoryOverlay.seatSize);
}

void main() {
  group('PM acceptance (A7): an online battle the server ended', () {
    for (final (outcome, verdict, scene, title, row) in const [
      ('draw', 'DRAW', VictoryResult.draw, '무승부', '무'),
      ('win', 'WIN!', VictoryResult.timeWin, '승리', '승'),
      ('loss', 'LOSE', VictoryResult.lose, '패배', '패'),
    ]) {
      final others = {'DRAW', 'WIN!', 'LOSE'}..remove(verdict);

      test('$outcome: the battle stage shows $verdict and never '
          '${others.join(' or ')}; the poses follow', () {
        final end = OnlineStageEvents.endOf(_finished(outcome))!;
        final fx = BattleFxTimeline()..finish(end, 0);
        final texts = <String>{};
        final mine = <BattlePose>{};
        final theirs = <BattlePose>{};
        for (var t = 0.0; t <= 6000; t += 20) {
          final frame = fx.frame(t);
          texts.addAll([for (final banner in frame.banners) banner.text]);
          mine.add(frame.me.pose);
          theirs.add(frame.opponent.pose);
        }
        expect(texts, contains(verdict));
        for (final other in others) {
          expect(texts, isNot(contains(other)));
        }
        switch (outcome) {
          case 'draw':
            // Neither falls or loses: both stay in guard.
            expect(mine, {BattlePose.idle});
            expect(theirs, {BattlePose.idle});
          case 'win':
            expect(mine, contains(BattlePose.win));
            expect(mine, isNot(contains(BattlePose.hit)));
          default:
            expect(mine, contains(BattlePose.hit));
            expect(mine, isNot(contains(BattlePose.win)));
            expect(theirs, contains(BattlePose.win));
        }
      });

      testWidgets('$outcome: the report plays the ${scene.name} scene with '
          'the opponent, titled $title; then the seat', (tester) async {
        final result = onlineBattleResult(
          _finished(outcome),
          playerName: '우현',
        )!;
        expect(VictoryResult.of(result), scene);
        await _open(tester, ResultScreen(result: result));
        final overlay = tester.widget<VictoryOverlay>(_playing);
        expect(overlay.result, scene);
        expect(overlay.opponent?.characterId, 'seal');
        expect(find.text(title), findsWidgets);

        final bands = <String>{};
        for (var t = 0; t < 2000; t += 50) {
          final frame = _frameNow(tester);
          if (frame.band case final band?) bands.add(band.text);
          switch (outcome) {
            case 'draw':
              // Never the frustration.
              expect(frame.figure, isNull, reason: 't=$t');
            case 'win':
              expect(
                frame.figure?.motion,
                anyOf(isNull, VictoryMotionKind.celebrate),
                reason: 't=$t',
              );
            default:
              expect(
                frame.figure?.motion,
                anyOf(isNull, VictoryMotionKind.frustrate),
                reason: 't=$t',
              );
          }
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(bands, {
          switch (outcome) {
            'draw' => '무승부',
            'win' => '판정승',
            _ => '패배',
          },
        });
        if (outcome == 'draw') {
          expect(find.text('패배'), findsNothing);
          expect(find.textContaining('LOSE'), findsNothing);
        }

        await tester.pump(const Duration(milliseconds: 200));
        expect(_playing, findsNothing);
        expect(
          tester.widget<VictorySeat>(find.byType(VictorySeat)).result,
          scene,
        );
        final seat = _seatFrame(tester);
        expect(seat.figure?.motion, switch (outcome) {
          'draw' => isNull,
          'win' => VictoryMotionKind.celebrate,
          _ => VictoryMotionKind.frustrate,
        });
        expect(seat.fighters, hasLength(outcome == 'draw' ? 1 : 0));
      });

      testWidgets('$outcome: 운동일지 reads "$row"; the report opened from '
          'it shows only the end look, titled $title', (tester) async {
        final record = onlineBattleResult(
          _finished(outcome),
          playerName: '우현',
        )!.record;
        expect(record.outcome, switch (outcome) {
          'draw' => MatchOutcome.draw,
          'win' => MatchOutcome.win,
          _ => MatchOutcome.lose,
        });
        expect(ArchiveMatchRow.chipLabel(record), row);
        await _open(tester, Scaffold(body: ArchiveMatchRow(match: record)));
        expect(find.text(row), findsOneWidget);
        if (outcome == 'draw') {
          expect(find.textContaining('패'), findsNothing);
        }

        await _open(tester, ResultScreen.record(record: record));
        await tester.pumpAndSettle();
        expect(_playing, findsNothing);
        expect(find.text(title), findsWidgets);
        expect(
          tester.widget<VictorySeat>(find.byType(VictorySeat)).result,
          scene,
        );
        final seat = _seatFrame(tester);
        if (outcome == 'draw') {
          expect(find.text('패배'), findsNothing);
          expect(seat.figure, isNull);
          expect(seat.fighters.single.characterId, 'bear');
          expect(seat.fighters.single.pose, BattlePose.idle);
        } else {
          expect(seat.figure, isNotNull);
        }
      });
    }
  });

  group('the scene fits (SPEC 7.8)', () {
    for (final (size, textScale) in const [
      (Size(360, 780), 1.3),
      (Size(320, 640), 1.0),
      (Size(320, 640), 1.3),
    ]) {
      for (final outcome in ['loss', 'draw']) {
        testWidgets('$outcome on ${size.width.toInt()} x '
            '${size.height.toInt()}, text x$textScale: no overflow while it '
            'plays or after; it ends on the seat inside the screen', (
          tester,
        ) async {
          final result = onlineBattleResult(
            _finished(outcome),
            playerName: '우현',
          )!;
          await _open(
            tester,
            ResultScreen(result: result),
            size: size,
            textScale: textScale,
          );
          expect(tester.getSize(_playing), size);
          for (final ms in [100, 300, 260, 300, 440, 560, 500, 300]) {
            await tester.pump(Duration(milliseconds: ms));
            expect(tester.takeException(), isNull, reason: '+$ms ms');
          }
          expect(_playing, findsNothing);
          final seat = tester.getRect(find.byType(VictorySeat));
          expect((Offset.zero & size).contains(seat.topLeft), isTrue);
          expect(seat.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
