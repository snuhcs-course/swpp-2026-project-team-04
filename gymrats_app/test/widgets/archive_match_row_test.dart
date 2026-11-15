import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/archive_chart.dart';
import 'package:gymrats_app/widgets/archive_match_row.dart';

import 'battle_test_support.dart';

/// Saturday 2026-11-14, 15:00.
final _now = DateTime(2026, 11, 14, 15);

MatchRecord _match({
  ExerciseType exercise = ExerciseType.pushUp,
  String opponentName = 'RepBot 고수',
  int myReps = 24,
  int opponentReps = 12,
  int? myScore = 240,
  int? opponentScore = 125,
  DateTime? playedAt,
  MatchOutcome? decidedOutcome,
  GameEnd? gameEnd = GameEnd.ko,
  bool? isOnline = false,
  bool opponentLeft = false,
}) => MatchRecord(
  id: 5,
  exercise: exercise,
  opponentName: opponentName,
  myReps: myReps,
  opponentReps: opponentReps,
  myScore: myScore,
  opponentScore: opponentScore,
  playedAt: playedAt ?? DateTime(2026, 11, 14, 14, 30),
  decidedOutcome: decidedOutcome,
  gameEnd: gameEnd,
  isOnline: isOnline,
  opponentLeft: opponentLeft,
);

void main() {
  // The app's fonts, so the rows measure as they do on a phone.
  setUpAll(loadBattleFonts);

  group('resultLine', () {
    test('a KO says KO; time up says 승리, 패배 or 무승부', () {
      expect(ArchiveMatchRow.resultLine(_match()), '푸쉬업 · KO 승');
      expect(
        ArchiveMatchRow.resultLine(_match(myReps: 5, gameEnd: GameEnd.ko)),
        '푸쉬업 · KO 패',
      );
      expect(
        ArchiveMatchRow.resultLine(
          _match(exercise: ExerciseType.squat, gameEnd: GameEnd.timeUp),
        ),
        '스쿼트 · 승리',
      );
      expect(
        ArchiveMatchRow.resultLine(_match(myReps: 5, gameEnd: GameEnd.timeUp)),
        '푸쉬업 · 패배',
      );
      expect(
        ArchiveMatchRow.resultLine(_match(myReps: 12, gameEnd: GameEnd.timeUp)),
        '푸쉬업 · 무승부',
      );
    });

    test('the stored outcome wins over the reps', () {
      expect(
        ArchiveMatchRow.resultLine(
          _match(decidedOutcome: MatchOutcome.lose, gameEnd: null),
        ),
        '푸쉬업 · 패배',
      );
    });

    test('a battle the opponent left says so after the result', () {
      expect(
        ArchiveMatchRow.resultLine(
          _match(
            myReps: 3,
            decidedOutcome: MatchOutcome.win,
            gameEnd: null,
            isOnline: true,
            opponentLeft: true,
          ),
        ),
        '푸쉬업 · 승리 · 상대 나감',
      );
    });
  });

  group('whenLine', () {
    test('today and yesterday by name, older days by date', () {
      expect(
        ArchiveMatchRow.whenLine(DateTime(2026, 11, 14, 14, 30), _now),
        '오늘 14:30',
      );
      expect(
        ArchiveMatchRow.whenLine(DateTime(2026, 11, 14, 0, 5), _now),
        '오늘 00:05',
      );
      expect(
        ArchiveMatchRow.whenLine(DateTime(2026, 11, 13, 21, 5), _now),
        '어제 21:05',
      );
      expect(
        ArchiveMatchRow.whenLine(DateTime(2026, 11, 12, 23, 59), _now),
        '11월 12일 23:59',
      );
    });

    test('yesterday across a month and a year', () {
      expect(
        ArchiveMatchRow.whenLine(
          DateTime(2026, 10, 31, 22),
          DateTime(2026, 11, 1, 9),
        ),
        '어제 22:00',
      );
      expect(
        ArchiveMatchRow.whenLine(
          DateTime(2026, 12, 31, 23, 10),
          DateTime(2027, 1, 1, 1),
        ),
        '어제 23:10',
      );
    });

    test('a battle stamped after now (a clock ahead) shows its date', () {
      expect(
        ArchiveMatchRow.whenLine(DateTime(2026, 11, 15, 9), _now),
        '11월 15일 09:00',
      );
    });
  });

  group('opponentLine', () {
    test('온라인 for an online battle; as before otherwise', () {
      expect(
        ArchiveMatchRow.opponentLine(
          _match(opponentName: 'test111', isOnline: true),
        ),
        '온라인 vs test111',
      );
      expect(ArchiveMatchRow.opponentLine(_match()), 'vs RepBot 고수');
      expect(
        ArchiveMatchRow.opponentLine(
          _match(opponentName: 'RepBot', isOnline: null),
        ),
        'vs RepBot',
      );
    });
  });

  group('ArchiveMatchRow', () {
    Future<void> show(
      WidgetTester tester,
      MatchRecord match, {
      int? bestGain,
      VoidCallback? onTap,
      Size size = const Size(412, 915),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: ArchiveMatchRow(
                  match: match,
                  now: _now,
                  bestGain: bestGain,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the icon, the result, when and whom, and the score', (
      tester,
    ) async {
      await show(tester, _match());
      expect(find.byType(ArchiveExerciseIcon), findsOneWidget);
      expect(
        tester
            .widget<ArchiveExerciseIcon>(find.byType(ArchiveExerciseIcon))
            .exercise,
        ExerciseType.pushUp,
      );
      expect(find.text('푸쉬업 · KO 승'), findsOneWidget);
      expect(find.text('오늘 14:30'), findsOneWidget);
      expect(find.text(' · '), findsOneWidget);
      expect(find.text('vs RepBot 고수'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ArchiveMatchRow)).height,
        ArchiveMatchRow.minHeight,
      );
      // The opponent's score is not in the row (BArchive).
      expect(find.text('125'), findsNothing);
    });

    testWidgets('a squat row draws the squat', (tester) async {
      await show(tester, _match(exercise: ExerciseType.squat));
      expect(
        tester
            .widget<ArchiveExerciseIcon>(find.byType(ArchiveExerciseIcon))
            .exercise,
        ExerciseType.squat,
      );
      expect(find.text('스쿼트 · KO 승'), findsOneWidget);
    });

    testWidgets('a battle saved before scores shows its reps with 회', (
      tester,
    ) async {
      await show(tester, _match(myScore: null, opponentScore: null));
      expect(find.text('24회'), findsOneWidget);
      expect(find.text('240'), findsNothing);
    });

    testWidgets('a battle without a time shows only the opponent', (
      tester,
    ) async {
      await show(
        tester,
        MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 3,
          opponentReps: 1,
        ),
      );
      expect(find.text('vs RepBot'), findsOneWidget);
      expect(find.text(' · '), findsNothing);
      expect(find.byType(ArchiveWhenAndOpponent), findsNothing);
      expect(find.textContaining('오늘'), findsNothing);
    });

    testWidgets('a new best shows the lime ↑ chip with the gain', (
      tester,
    ) async {
      await show(tester, _match(), bestGain: 55);
      final chip = find.byKey(const ValueKey('archive-gain-chip'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text('55')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: chip,
          matching: find.byIcon(Icons.arrow_upward_rounded),
        ),
        findsOneWidget,
      );
      final fill =
          (tester.widget<DecoratedBox>(chip).decoration as BoxDecoration).color;
      expect(fill, AppColors.accent.withValues(alpha: 0.6));
      // Under the score.
      expect(
        tester.getTopLeft(chip).dy,
        greaterThan(tester.getBottomLeft(find.text('240')).dy),
      );
    });

    testWidgets('no new best, no chip', (tester) async {
      await show(tester, _match());
      expect(find.byKey(const ValueKey('archive-gain-chip')), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    });

    testWidgets('one node for a screen reader, with the chip in words', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await show(tester, _match(), bestGain: 55, onTap: () {});
      final node = tester.getSemantics(find.byType(ArchiveMatchRow));
      expect(node.label, contains('푸쉬업 · KO 승'));
      expect(node.label, contains('vs RepBot 고수'));
      expect(node.label, contains('240점'));
      expect(node.label, contains('최고 기록 55점 경신'));
      expect(node, isSemantics(hasTapAction: true));
      semantics.dispose();
    });

    testWidgets('a tap calls onTap; without it the row does nothing', (
      tester,
    ) async {
      var taps = 0;
      await show(tester, _match(), onTap: () => taps++);
      await tester.tap(find.byType(ArchiveMatchRow));
      expect(taps, 1);

      final semantics = tester.ensureSemantics();
      await show(tester, _match());
      await tester.tap(find.byType(ArchiveMatchRow));
      expect(
        tester.getSemantics(find.byType(ArchiveMatchRow)),
        isSemantics(hasTapAction: false),
      );
      semantics.dispose();
    });

    RenderArchiveWhenAndOpponent line(WidgetTester tester) =>
        tester.renderObject<RenderArchiveWhenAndOpponent>(
          find.byType(ArchiveWhenAndOpponent),
        );

    testWidgets('time, dot and opponent share a line when they fit', (
      tester,
    ) async {
      await show(tester, _match(opponentName: '온라인닉네임', isOnline: true));
      expect(line(tester).split, isFalse);
      final time = tester.getRect(find.text('오늘 14:30'));
      final dot = tester.getRect(find.text(' · '));
      final who = tester.getRect(find.text('온라인 vs 온라인닉네임'));
      expect([dot.top, who.top], [time.top, time.top]);
      expect(dot.left, time.right);
      expect(who.left, dot.right);
      expect(
        find.byType(ArchiveWhenAndOpponent),
        paintsExactlyCountTimes(#drawParagraph, 3),
      );
    });

    testWidgets('on one line the dot is read too', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, _match());
      final label = tester.getSemantics(find.byType(ArchiveMatchRow)).label;
      expect(label.split('\n').map((part) => part.trim()), contains('·'));
      semantics.dispose();
    });

    testWidgets('a long online nickname goes under the time, whole, and no '
        'line ends in the dot', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        _match(opponentName: '가나다라마바사아자차카타', isOnline: true),
        bestGain: 55,
        size: const Size(360, 780),
      );
      expect(line(tester).split, isTrue);
      final time = find.text('오늘 14:30');
      final who = find.text('온라인 vs 가나다라마바사아자차카타');
      expect(tester.getTopLeft(who).dy, tester.getBottomLeft(time).dy);
      expect(tester.getTopLeft(who).dx, tester.getTopLeft(time).dx);
      expect(
        tester.renderObject<RenderParagraph>(who).didExceedMaxLines,
        isFalse,
      );
      // The dot is neither drawn nor read.
      expect(
        find.byType(ArchiveWhenAndOpponent),
        paintsExactlyCountTimes(#drawParagraph, 2),
      );
      final label = tester.getSemantics(find.byType(ArchiveMatchRow)).label;
      expect(label, contains('오늘 14:30'));
      expect(label, contains('온라인 vs 가나다라마바사아자차카타'));
      // The merged label puts each text on its own line.
      expect(
        label.split('\n').map((part) => part.trim()),
        isNot(contains('·')),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('a time wider than the line alone is cut, the opponent too', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          // Material: the theme's text, not the debug fallback.
          home: Material(
            child: Center(
              child: SizedBox(
                width: 40,
                child: ArchiveWhenAndOpponent(
                  time: const Text(
                    '10월 15일 21:30',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dot: const Text(' · '),
                  opponent: const Text(
                    'vs RepBot 고수',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final box = line(tester);
      expect(box.split, isTrue);
      expect(box.size.width, lessThanOrEqualTo(40));
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('10월 15일 21:30'))
            .didExceedMaxLines,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('its height is known before layout, for the archive page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 120,
                child: IntrinsicHeight(
                  child: ArchiveWhenAndOpponent(
                    time: const Text('오늘 14:30'),
                    dot: const Text(' · '),
                    opponent: const Text('온라인 vs 가나다라마바사'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final box = line(tester);
      expect(box.split, isTrue);
      expect(box.getMaxIntrinsicHeight(120), box.size.height);
      expect(box.getMinIntrinsicHeight(120), box.size.height);
      expect(box.getDryLayout(const BoxConstraints(maxWidth: 120)), box.size);
      expect(box.getMaxIntrinsicWidth(double.infinity), greaterThan(120));
      expect(
        box.getMinIntrinsicWidth(double.infinity),
        lessThan(box.getMaxIntrinsicWidth(double.infinity)),
      );
      final wide = box.getDryLayout(const BoxConstraints(maxWidth: 1000));
      expect(wide.width, box.getMaxIntrinsicWidth(double.infinity));
      expect(wide.height, lessThan(box.size.height));
      expect(box.getMaxIntrinsicHeight(1000), wide.height);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('no overflow on a 360 wide phone at ${scale}x text', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await show(
          tester,
          _match(
            opponentName: '가나다라마바사아자차카타',
            isOnline: true,
            playedAt: DateTime(2026, 10, 15, 21, 30),
            myScore: 1240,
            opponentLeft: true,
            decidedOutcome: MatchOutcome.win,
            gameEnd: null,
          ),
          bestGain: 155,
          size: const Size(360, 780),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('1240'), findsOneWidget);
        expect(
          tester.getSize(find.byType(ArchiveMatchRow)).height,
          greaterThanOrEqualTo(ArchiveMatchRow.minHeight),
        );
      });
    }
  });
}
