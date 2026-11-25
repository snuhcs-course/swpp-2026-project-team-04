import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/hold_record.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/archive_match_row.dart';

import 'battle_test_support.dart';

MatchRecord _battle({
  int mine = 18,
  int theirs = 12,
  int? score = 185,
  GameEnd? end = GameEnd.timeUp,
  bool? online = false,
  bool left = false,
  ExerciseType exercise = ExerciseType.pushUp,
  DateTime? at,
}) => MatchRecord(
  exercise: exercise,
  opponentName: '러너',
  myReps: mine,
  opponentReps: theirs,
  myScore: score,
  opponentScore: score == null ? null : 100,
  playedAt: at ?? DateTime(2026, 11, 24, 16, 4),
  gameEnd: end,
  isOnline: online,
  opponentLeft: left,
);

Future<void> _show(WidgetTester tester, Widget child, {double width = 412}) {
  tester.view.physicalSize = Size(width, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ListView(children: [child])),
    ),
  );
}

void main() {
  setUpAll(loadBattleFonts);

  group('the words (P13, draft C)', () {
    test('the chip: 승, KO승, 패, KO패, 무', () {
      expect(ArchiveMatchRow.chipLabel(_battle()), '승');
      expect(ArchiveMatchRow.chipLabel(_battle(end: GameEnd.ko)), 'KO승');
      expect(ArchiveMatchRow.chipLabel(_battle(mine: 3)), '패');
      expect(
        ArchiveMatchRow.chipLabel(_battle(mine: 3, end: GameEnd.ko)),
        'KO패',
      );
      expect(ArchiveMatchRow.chipLabel(_battle(mine: 12)), '무');
    });

    test('the title names the exercise and the opponent', () {
      expect(ArchiveMatchRow.titleLine(_battle()), '푸쉬업 · vs 러너');
      expect(
        ArchiveMatchRow.titleLine(_battle(exercise: ExerciseType.squat)),
        '스쿼트 · vs 러너',
      );
    });

    test('the detail: the time, the kind when known, the opponent leaving', () {
      expect(ArchiveMatchRow.detailLine(_battle()), '16:04 · 아케이드');
      expect(
        ArchiveMatchRow.detailLine(_battle(online: true, left: true)),
        '16:04 · 온라인 · 상대 나감',
      );
      expect(ArchiveMatchRow.detailLine(_battle(online: null)), '16:04');
      expect(
        ArchiveMatchRow.detailLine(
          const MatchRecord(
            exercise: ExerciseType.pushUp,
            opponentName: 'RepBot',
            myReps: 1,
            opponentReps: 0,
          ),
        ),
        '',
      );
    });

    test('the score in points, or the reps for a battle without one', () {
      expect(ArchiveMatchRow.scoreWords(_battle()), '185점');
      expect(ArchiveMatchRow.scoreWords(_battle(score: null)), '18회');
    });

    test('the day: 오늘 and 어제 with the date and weekday, else the date', () {
      final now = DateTime(2026, 11, 24, 21);
      expect(
        ArchiveDayHeader.dayLine(DateTime(2026, 11, 24), now),
        '오늘 · 11.24 (화)',
      );
      expect(
        ArchiveDayHeader.dayLine(DateTime(2026, 11, 23), now),
        '어제 · 11.23 (월)',
      );
      expect(
        ArchiveDayHeader.dayLine(DateTime(2026, 11, 21), now),
        '11.21 (토)',
      );
      // Across a month's turn.
      expect(
        ArchiveDayHeader.dayLine(DateTime(2026, 11, 30), DateTime(2026, 12, 1)),
        '어제 · 11.30 (월)',
      );
    });
  });

  group('the row', () {
    testWidgets('shows the chip, title, detail, score with its unit and the '
        'reps; one tappable node for a screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await _show(
        tester,
        ArchiveMatchRow(match: _battle(), onTap: () => taps++),
      );
      expect(find.text('승'), findsOneWidget);
      expect(find.text('푸쉬업 · vs 러너'), findsOneWidget);
      expect(find.text('16:04 · 아케이드'), findsOneWidget);
      expect(find.text('185 점', findRichText: true), findsOneWidget);
      expect(find.text('인정 18회'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ArchiveMatchRow)),
        isSemantics(
          label: '승\n푸쉬업 · vs 러너\n16:04 · 아케이드\n185점\n인정 18회',
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(ArchiveMatchRow));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(ArchiveMatchRow)).height,
        greaterThanOrEqualTo(ArchiveMatchRow.minHeight),
      );
      semantics.dispose();
    });

    testWidgets('a battle without a score shows its reps with 회 and no '
        'reps line', (tester) async {
      await _show(tester, ArchiveMatchRow(match: _battle(score: null)));
      expect(find.text('18 회', findRichText: true), findsOneWidget);
      expect(find.textContaining('인정'), findsNothing);
    });

    testWidgets('the gain chip only with a gain', (tester) async {
      await _show(tester, ArchiveMatchRow(match: _battle(), bestGain: 55));
      expect(find.byKey(const ValueKey('archive-gain-chip')), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('최고 기록 55점 경신')), findsOneWidget);
      await _show(tester, ArchiveMatchRow(match: _battle()));
      expect(find.byKey(const ValueKey('archive-gain-chip')), findsNothing);
    });

    testWidgets('a loss and a draw get their own chip colors', (tester) async {
      Color chipColor() =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .ancestor(
                              of: find.byWidgetPredicate(
                                (w) =>
                                    w is Text &&
                                    const ['승', '패', '무'].contains(w.data),
                              ),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      await _show(tester, ArchiveMatchRow(match: _battle()));
      final win = chipColor();
      await _show(tester, ArchiveMatchRow(match: _battle(mine: 3)));
      final lose = chipColor();
      await _show(tester, ArchiveMatchRow(match: _battle(mine: 12)));
      final draw = chipColor();
      expect(win, AppColors.accent);
      expect({win, lose, draw}, hasLength(3));
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('a long opponent name fits a 360 wide phone at ${scale}x '
          'text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _show(
          tester,
          ArchiveMatchRow(
            match: MatchRecord(
              exercise: ExerciseType.squat,
              opponentName: '아주아주긴닉네임을가진상대선수',
              myReps: 18,
              opponentReps: 12,
              myScore: 1850,
              opponentScore: 100,
              playedAt: DateTime(2026, 11, 24, 16, 4),
              gameEnd: GameEnd.ko,
              isOnline: true,
              opponentLeft: true,
            ),
            bestGain: 120,
          ),
          width: 360,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the day header', () {
    testWidgets('the day and its count, as a header', (tester) async {
      final semantics = tester.ensureSemantics();
      await _show(
        tester,
        ArchiveDayHeader(
          date: DateTime(2026, 11, 24),
          count: 2,
          now: DateTime(2026, 11, 24, 21),
        ),
      );
      expect(find.text('오늘 · 11.24 (화)'), findsOneWidget);
      expect(find.text('2경기'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ArchiveDayHeader)),
        isSemantics(label: '오늘 · 11.24 (화)\n2경기', isHeader: true),
      );
      semantics.dispose();
    });
  });
  group('a hold row (P13)', () {
    HoldRecord hold({int stars = 2, int warnings = 2}) => HoldRecord(
      endedAt: DateTime(2026, 11, 26, 21, 10),
      pose: HoldPose.plank,
      stage: 3,
      held: const Duration(milliseconds: 24600),
      elapsed: const Duration(milliseconds: 26700),
      stars: stars,
      starSeconds: const [15, 20, 30],
      warnings: [
        for (var i = 0; i < warnings; i++)
          HoldRecordWarning(
            at: Duration(seconds: 3 + i),
            faultId: 'plank.kneeDown',
            words: '무릎 떼요',
          ),
      ],
    );

    test('the words', () {
      expect(ArchiveHoldRow.titleLine(hold()), '하이 플랭크 · 3스테이지');
      expect(ArchiveHoldRow.detailLine(hold()), '21:10 · 버티기 · 경고 2');
      expect(ArchiveHoldRow.detailLine(hold(warnings: 0)), '21:10 · 버티기');
      expect(ArchiveHoldRow.heldWords(hold()), '24.6');
    });

    testWidgets('the star chip, the title, the time held and the stars; one '
        'tappable node', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await _show(tester, ArchiveHoldRow(hold: hold(), onTap: () => taps++));
      expect(find.text('★2'), findsOneWidget);
      expect(find.text('하이 플랭크 · 3스테이지'), findsOneWidget);
      expect(find.text('24.6 초', findRichText: true), findsOneWidget);
      expect(find.text('별 2/3'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ArchiveHoldRow)),
        isSemantics(
          label: '별 2개\n하이 플랭크 · 3스테이지\n21:10 · 버티기 · 경고 2\n24.6초 버팀\n별 2/3',
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(ArchiveHoldRow));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('a fail gets the pink chip', (tester) async {
      await _show(tester, ArchiveHoldRow(hold: hold(stars: 0)));
      final chip = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text('★0'), matching: find.byType(DecoratedBox))
            .first,
      );
      expect((chip.decoration as BoxDecoration).color, isNot(AppColors.accent));
    });
  });
}
