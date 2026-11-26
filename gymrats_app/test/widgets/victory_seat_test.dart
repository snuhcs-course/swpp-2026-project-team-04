import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/result_report.dart';
import 'package:gymrats_app/widgets/victory_overlay.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

import 'battle_test_support.dart';
import 'victory_test_support.dart';

// The victory scene's seat in the result report (W5 part 2, spec 2 and
// 11.2): where ResultSeatRows puts the cell, that the headline's rows keep
// left of it, and VictorySeat's end look in it. The report itself is
// tested in result_report_test.dart; the scene over the screen in
// test/screens/result_screen_test.dart.

const _bot = Opponent(
  name: 'RepBot',
  isBot: true,
  difficulty: BotDifficulty.expert,
);
const _person = Opponent(name: '아주아주긴닉네임을가진상대선수', isBot: false);

/// The design's battle (a KO win, 240 : 125 in 25 s), or as changed.
ResultReportData _data({
  MatchOutcome outcome = MatchOutcome.win,
  bool byKo = true,
  Opponent opponent = _bot,
  Duration? played = const Duration(seconds: 25),
  int myScore = 240,
  int opponentScore = 125,
  int opponentValidReps = 6,
  BattleDeparture departure = BattleDeparture.none,
}) => ResultReportData(
  outcome: outcome,
  byKo: byKo,
  exercise: ExerciseType.pushUp,
  opponent: opponent,
  played: played,
  myScore: myScore,
  opponentScore: opponentScore,
  myValidReps: 12,
  myInvalidReps: 0,
  opponentValidReps: opponentValidReps,
  endedAt: DateTime(2026, 11, 4, 14, 30),
  departure: departure,
);

/// Every way the headline's rows read differently: the design's line, a
/// long nickname, the tie-break reasons, the departures, a draw.
final _rowsCases = {
  'the design\'s KO win': _data(),
  'a long nickname': _data(opponent: _person),
  'a tie-break win': _data(byKo: false, opponentScore: 240),
  'a tie-break loss': _data(
    outcome: MatchOutcome.lose,
    byKo: false,
    opponentScore: 240,
    opponentValidReps: 14,
  ),
  'the opponent left': _data(
    byKo: false,
    opponent: _person,
    played: null,
    departure: BattleDeparture.opponentLeft,
  ),
  'my connection dropped': _data(
    outcome: MatchOutcome.lose,
    byKo: false,
    opponent: _person,
    played: null,
    departure: BattleDeparture.myConnectionLost,
  ),
  'a draw': _data(
    outcome: MatchOutcome.draw,
    byKo: false,
    opponentScore: 240,
    opponentValidReps: 12,
  ),
};

const _seatKey = Key('seat');

/// The report with a plain seat on a phone of [size] whose status bar is
/// [top] high.
Future<void> _showReport(
  WidgetTester tester,
  ResultReportData data, {
  Size size = designSize,
  double top = 24,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: top);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ResultReport(
        data: data,
        onGoHome: () {},
        onRematch: () {},
        onOpenFeedback: () {},
        seat: const ColoredBox(key: _seatKey, color: AppColors.accent),
      ),
    ),
  );
}

Rect _seat(WidgetTester tester) => tester.getRect(find.byKey(_seatKey));

/// The headline's words box and every line of the sub line and the reason.
List<Rect> _rowRects(WidgetTester tester) => [
  tester.getRect(
    find.descendant(
      of: find.byType(ResultHeadline),
      matching: find.byType(FittedBox),
    ),
  ),
  for (final element
      in find
          .descendant(
            of: find.byType(ResultSubLine),
            matching: find.byType(RichText),
          )
          .evaluate())
    tester.getRect(find.byElementPredicate((e) => e == element)),
];

void main() {
  setUpAll(loadBattleFonts);

  group('the seat in the report (ResultSeatRows)', () {
    testWidgets('on a 360 x 780 phone the seat is x 200-344, 144 x 148, and '
        'ends on the score row\'s top: the design\'s place, a status bar '
        'lower', (tester) async {
      await _showReport(tester, _data());
      final seat = _seat(tester);
      expect(seat.size, VictoryOverlay.seatSize);
      expect(ResultSeatRows.seatSize, VictoryOverlay.seatSize);
      expect(seat.left, 200);
      expect(seat.right, 344);
      expect(seat.bottom, tester.getRect(find.byType(ResultScoreRow)).top);
      // The design's seat is at (200, 36) under its 28 top; the phone's
      // status bar (24) and the page's top (8) put it 3 lower.
      expect(seat.top, closeTo(designSeat.dy, 4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the seat keeps to the column\'s right end on a wider phone', (
      tester,
    ) async {
      await _showReport(tester, _data(), size: const Size(412, 915));
      final seat = _seat(tester);
      expect(seat.right, 412 - 20 + ResultSeatRows.overhang);
      expect(seat.bottom, tester.getRect(find.byType(ResultScoreRow)).top);
    });

    for (final textScale in const [1.0, 1.3, 1.5]) {
      testWidgets('at ${textScale}x the headline\'s rows keep left of the '
          'seat, whatever they say', (tester) async {
        for (final MapEntry(key: name, value: data) in _rowsCases.entries) {
          await _showReport(tester, data, textScale: textScale);
          final seat = _seat(tester);
          // Beside the rows, not on a row of its own above them.
          expect(
            seat.bottom,
            greaterThan(tester.getRect(find.byType(ResultHeadline)).bottom),
            reason: name,
          );
          for (final rect in _rowRects(tester)) {
            expect(rect.right, lessThanOrEqualTo(seat.left), reason: name);
          }
          expect(seat.bottom, tester.getRect(find.byType(ResultScoreRow)).top);
          expect(tester.takeException(), isNull, reason: name);
        }
      });
    }

    testWidgets('a long nickname is cut before the seat; the seconds stay '
        'whole', (tester) async {
      await _showReport(tester, _data(opponent: _person));
      final name = tester.getRect(find.text(_person.name));
      final seconds = tester.getRect(find.text(' · 25초'));
      expect(seconds.left, greaterThanOrEqualTo(name.right));
      expect(seconds.right, lessThanOrEqualTo(_seat(tester).left));
    });

    testWidgets('at 2.0x the words and seconds do not fit beside the seat: '
        'the seat gets a row of its own above the headline and the rows the '
        'whole width; a line without seconds still fits beside it; nothing '
        'overflows', (tester) async {
      for (final MapEntry(key: name, value: data) in _rowsCases.entries) {
        await _showReport(tester, data, textScale: 2);
        final seat = _seat(tester);
        final headline = tester.getRect(find.byType(ResultHeadline));
        expect(seat.right, 344, reason: name);
        if (data.played == null) {
          expect(seat.bottom, greaterThan(headline.bottom), reason: name);
          for (final rect in _rowRects(tester)) {
            expect(rect.right, lessThanOrEqualTo(seat.left), reason: name);
          }
        } else {
          expect(seat.bottom, lessThanOrEqualTo(headline.top), reason: name);
          expect(
            seat.top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(ResultHeader)).bottom,
            ),
            reason: name,
          );
          expect(
            tester.getRect(find.byType(ResultSubLine)).width,
            320,
            reason: name,
          );
        }
        expect(tester.takeException(), isNull, reason: name);
      }
    });

    for (final (delta, beside) in const [(0.5, true), (-0.5, false)]) {
      testWidgets('with room ${delta > 0 ? 'just above' : 'just below'} the '
          'sub line\'s least width the seat goes '
          '${beside ? 'beside the rows' : 'above them'}', (tester) async {
        tester.view
          ..physicalSize = designSize
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const played = Duration(seconds: 25);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final least = ResultSubLine.leastWidthIn(
                    context,
                    exercise: ExerciseType.pushUp,
                    played: played,
                  );
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 200),
                      child: SizedBox(
                        width: ResultSeatRows.reserved + least + delta,
                        child: ResultSeatRows(
                          seat: const SizedBox.expand(key: _seatKey),
                          leastWidth: least,
                          rows: const ResultSubLine(
                            exercise: ExerciseType.pushUp,
                            opponent: _bot,
                            played: played,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        final seat = _seat(tester);
        final line = tester.getRect(find.byType(ResultSubLine));
        if (beside) {
          expect(seat.left, greaterThanOrEqualTo(line.right));
          // The name shrinks to "…" at the least; the line does not
          // overflow.
          expect(tester.getSize(find.text('RepBot 고수')).width, greaterThan(0));
        } else {
          expect(seat.bottom, lessThanOrEqualTo(line.top));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the least width is the line\'s words but the name, and '
        'the "…" a cut name shrinks to; less without seconds', (tester) async {
      await _showReport(tester, _data());
      final context = tester.element(find.byType(ResultSubLine));
      double width(String text) => tester.getSize(find.text(text)).width;
      final ellipsis = TextPainter(
        text: TextSpan(
          text: '…',
          style: tester.widget<Text>(find.text('푸쉬업 · vs ')).style,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(ellipsis.dispose);
      expect(
        ResultSubLine.leastWidthIn(
          context,
          exercise: ExerciseType.pushUp,
          played: const Duration(seconds: 25),
        ),
        closeTo(width('푸쉬업 · vs ') + width(' · 25초') + ellipsis.width, 0.01),
      );
      expect(
        ResultSubLine.leastWidthIn(
          context,
          exercise: ExerciseType.pushUp,
          played: null,
        ),
        closeTo(width('푸쉬업 · vs ') + ellipsis.width, 0.01),
      );
    });

    testWidgets('without a seat the report has no cell (as W6 drew it)', (
      tester,
    ) async {
      tester.view
        ..physicalSize = designSize
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ResultReport(
            data: _data(),
            onGoHome: () {},
            onRematch: () {},
            onOpenFeedback: () {},
          ),
        ),
      );
      expect(find.byType(ResultSeatRows), findsNothing);
      expect(find.byType(ResultSubLine), findsOneWidget);
    });
  });

  group('VictorySeat: the end look alone', () {
    VictoryPainter painterIn(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(VictorySeat),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as VictoryPainter;

    for (final result in VictoryResult.values) {
      final draw = result == VictoryResult.draw;
      final stand = result.isWin
          ? 'lime'
          : draw
          ? 'lime and pink, my character in guard'
          : 'white';
      testWidgets('${result.name}: the stand and the end pose in a 144 x 148 '
          'box, the stand $stand; no button, nothing for screen readers', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          battleTestApp(
            Align(
              alignment: Alignment.topLeft,
              child: VictorySeat(result: result, characterId: 'bear'),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(
          tester.getSize(find.byType(VictorySeat)),
          VictoryOverlay.seatSize,
        );
        final painter = painterIn(tester);
        expect(painter.over, isTrue);
        expect(painter.character.id, 'bear');
        final frame = painter.frameIn(VictoryOverlay.seatSize);
        expect(frame.panel, isNull);
        expect(frame.band, isNull);
        expect(frame.confetti, isEmpty);
        // Spec 11.2: the stand at the cell's left + 44, top + 129; the feet
        // at its left + 86, top + 132.
        expect(frame.stand!.rect.topLeft, const Offset(44, 129));
        expect(
          frame.stand!.color,
          result.isWin || draw ? AppColors.accent : AppColors.card,
        );
        // A draw's stand is half lime and half pink (A7).
        expect(frame.stand!.rightColor, draw ? AppColors.opponent : isNull);
        if (draw) {
          // No frustration: my character alone, in the stage's guard pose.
          expect(frame.figure, isNull);
          final mine = frame.fighters.single;
          expect(mine.characterId, 'bear');
          expect(mine.pose, BattlePose.idle);
          expect(mine.foot, const Offset(86, 132));
        } else {
          expect(frame.figure!.foot, const Offset(86, 132));
          expect(frame.figure!.still, isTrue);
        }
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(find.bySemanticsLabel(RegExp('연출 건너뛰기')), findsNothing);
        semantics.dispose();
      });
    }

    testWidgets('it takes no taps: a button under it still works', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        battleTestApp(
          Stack(
            children: [
              SizedBox.fromSize(
                size: VictoryOverlay.seatSize,
                child: TextButton(
                  onPressed: () => pressed++,
                  child: const SizedBox.expand(),
                ),
              ),
              const VictorySeat(
                result: VictoryResult.koWin,
                characterId: 'mouse',
              ),
            ],
          ),
        ),
      );
      await tester.tapAt(const Offset(72, 74));
      expect(pressed, 1);
    });
  });
}
