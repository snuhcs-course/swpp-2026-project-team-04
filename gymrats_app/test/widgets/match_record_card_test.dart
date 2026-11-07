// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/match_record_card.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

/// Tests otherwise draw every letter as the same square.
Future<void> _loadAppFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final entry in const {
    AppFonts.number: ['assets/fonts/Oxanium-Bold.ttf'],
    AppFonts.headline: ['assets/fonts/BlackHanSans-Regular.ttf'],
    AppFonts.body: [
      'assets/fonts/IBMPlexSansKR-Regular.ttf',
      'assets/fonts/IBMPlexSansKR-Medium.ttf',
      'assets/fonts/IBMPlexSansKR-Bold.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
});

MatchRecord _match({FeedbackSummary? summary, MatchOutcome? outcome}) =>
    MatchRecord(
      id: 1,
      exercise: ExerciseType.pushUp,
      opponentName: '진영',
      myReps: 20,
      opponentReps: 3,
      playedAt: DateTime(2026, 10, 21, 9, 5),
      decidedOutcome: outcome,
      feedbackSummary: summary,
    );

const _issue = FeedbackSummary(
  validReps: 20,
  invalidReps: 2,
  issueCount: 2,
  topIssue: '팔꿈치가 벌어져요',
);
const _clean = FeedbackSummary(validReps: 20, invalidReps: 0, issueCount: 0);

void main() {
  Future<void> show(WidgetTester tester, Widget card) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: card),
      ),
    );
  }

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('the outcome reads in its dark color on a light tint', (
    tester,
  ) async {
    for (final (outcome, tint, text) in [
      (MatchOutcome.win, AppColors.accent, AppColors.accentText),
      (MatchOutcome.lose, AppColors.opponent, AppColors.opponentText),
      (MatchOutcome.draw, AppColors.textSecondary, AppColors.textSecondary),
    ]) {
      await show(tester, MatchOutcomeBadge(outcome: outcome));
      expect(colorOf(tester, outcome.label), text);
      final box = tester.widget<Container>(find.byType(Container));
      expect(
        (box.decoration! as BoxDecoration).color,
        tint.withValues(alpha: 0.14),
      );
    }
  });

  testWidgets('a top issue reads in dark amber', (tester) async {
    await show(
      tester,
      MatchRecordCard(match: _match(summary: _issue), showFeedback: true),
    );
    expect(find.text('팔꿈치가 벌어져요'), findsOneWidget);
    expect(colorOf(tester, '팔꿈치가 벌어져요'), AppColors.warningText);
  });

  testWidgets('nothing to fix reads 좋은 자세 in dark lime', (tester) async {
    await show(
      tester,
      MatchRecordCard(match: _match(summary: _clean), showFeedback: true),
    );
    expect(colorOf(tester, '좋은 자세'), AppColors.accentText);
  });

  testWidgets('a battle without feedback reads 피드백 없음', (tester) async {
    await show(tester, MatchRecordCard(match: _match(), showFeedback: true));
    expect(colorOf(tester, '피드백 없음'), AppColors.textMuted);
  });

  testWidgets('the feedback line shows only when asked', (tester) async {
    await show(tester, MatchRecordCard(match: _match(summary: _issue)));
    expect(find.text('팔꿈치가 벌어져요'), findsNothing);
  });

  testWidgets('a forfeit shows 패 whatever the reps', (tester) async {
    await show(
      tester,
      MatchRecordCard(
        match: _match(outcome: MatchOutcome.lose),
        showDate: true,
        showFeedback: true,
      ),
    );
    expect(find.text('패'), findsOneWidget);
    expect(find.text('푸쉬업 · 10월 21일 09:05'), findsOneWidget);
  });

  testWidgets('the opponent stands over the exercise and the date', (
    tester,
  ) async {
    await show(tester, MatchRecordCard(match: _match(), showDate: true));
    final opponent = tester.getRect(find.text('vs 진영'));
    final played = tester.getRect(find.text('푸쉬업 · 10월 21일 09:05'));
    expect(opponent.bottom, lessThanOrEqualTo(played.top));
    expect(opponent.left, played.left);
    expect(
      tester.widget<Text>(find.text('푸쉬업 · 10월 21일 09:05')).style?.color,
      AppColors.textSecondary,
    );
  });

  testWidgets('a name takes up to three lines, then ends in an ellipsis', (
    tester,
  ) async {
    final name = 'r' * 60;
    await show(
      tester,
      MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: name,
          myReps: 20,
          opponentReps: 3,
        ),
      ),
    );
    final line = find.text('vs $name');
    final style = tester.widget<Text>(line).style;
    expect(
      tester.getSize(line).height,
      moreOrLessEquals(3 * style!.fontSize! * style.height!, epsilon: 1),
    );
    expect(
      tester.renderObject<RenderParagraph>(line).didExceedMaxLines,
      isTrue,
    );
    expect(tester.widget<Text>(line).overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the exercise shows alone without the date', (tester) async {
    await show(tester, MatchRecordCard(match: _match()));
    expect(find.text('푸쉬업'), findsOneWidget);
    expect(find.textContaining('10월'), findsNothing);
  });

  testWidgets('a battle with no time shows the exercise alone', (tester) async {
    await show(
      tester,
      const MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.squat,
          opponentName: '진영',
          myReps: 20,
          opponentReps: 3,
        ),
        showDate: true,
      ),
    );
    expect(find.text('스쿼트'), findsOneWidget);
  });

  testWidgets('a battle with game scores shows them, not its reps', (
    tester,
  ) async {
    await show(
      tester,
      const MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 7,
          opponentReps: 9,
          myScore: 150,
          opponentScore: 90,
          decidedOutcome: MatchOutcome.win,
        ),
      ),
    );
    expect(find.text('승'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.textContaining('7'), findsNothing);
    expect(find.textContaining('회'), findsNothing);
    // "나" sits on a lime pill: ink, readable in the light theme.
    expect(colorOf(tester, '나'), AppColors.ink);
  });

  testWidgets('a battle with no game scores shows its reps with a unit', (
    tester,
  ) async {
    await show(
      tester,
      const MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 3,
          opponentReps: 5,
          decidedOutcome: MatchOutcome.win,
        ),
      ),
    );
    expect(find.text('승'), findsOneWidget);
    expect(find.text('3회'), findsOneWidget);
    expect(find.text('5회'), findsOneWidget);
  });

  testWidgets('one score alone shows the reps', (tester) async {
    await show(
      tester,
      const MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 3,
          opponentReps: 5,
          myScore: 150,
        ),
      ),
    );
    expect(find.text('3회'), findsOneWidget);
    expect(find.text('5회'), findsOneWidget);
    expect(find.textContaining('150'), findsNothing);
  });

  testWidgets('the unit is small and takes each number\'s color', (
    tester,
  ) async {
    await show(tester, MatchRecordCard(match: _match()));
    final theme = Theme.of(tester.element(find.text('20회'))).textTheme;
    final mine = tester.widget<Text>(find.text('20회'));
    final theirs = tester.widget<Text>(find.text('3회'));
    expect(mine.style!.fontSize, theme.titleLarge!.fontSize);
    expect(mine.style!.color, AppColors.textPrimary);
    expect(theirs.style!.color, AppColors.textSecondary);
    final myUnit = mine.textSpan! as TextSpan;
    final theirUnit = theirs.textSpan! as TextSpan;
    final mineSpan = myUnit.children!.single as TextSpan;
    final theirSpan = theirUnit.children!.single as TextSpan;
    expect(mineSpan.style!.fontSize, theme.bodySmall!.fontSize);
    expect(mineSpan.style!.color, AppColors.textPrimary);
    expect(theirSpan.style!.color, AppColors.textSecondary);
  });

  testWidgets('a long feedback line stays on one line without overflow', (
    tester,
  ) async {
    await show(
      tester,
      MatchRecordCard(
        match: _match(
          summary: const FeedbackSummary(
            validReps: 1,
            invalidReps: 0,
            issueCount: 1,
            topIssue: '아주 긴 자세 피드백 문장이 한 줄을 넘어가도 잘려서 보여요',
          ),
        ),
        showDate: true,
        showFeedback: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // Last in the file: the fonts stay loaded for the rest of the run.
  group('the game scores with the real fonts, on the real screens at 360', () {
    /// The levels, then 12 letters: ordinary, the widest ASCII, and Hangul.
    const names = [
      'AI 봇 · 초보',
      'AI 봇 · 고수',
      'NightRunner7',
      'WWWWWWWWWWWW',
      '힣힣힣힣힣힣힣힣힣힣힣힣',
    ];

    MatchRecord battle(String name, {int? mine, int? theirs, String? issue}) =>
        MatchRecord(
          id: 1,
          exercise: ExerciseType.pushUp,
          opponentName: name,
          myReps: 12,
          opponentReps: 18,
          myScore: mine,
          opponentScore: theirs,
          // The reps alone would read 패.
          decidedOutcome: MatchOutcome.win,
          playedAt: DateTime(2026, 12, 31, 23, 59),
          feedbackSummary: FeedbackSummary(
            validReps: 12,
            invalidReps: 1,
            issueCount: issue == null ? 0 : 1,
            topIssue: issue,
          ),
        );

    /// The real screen that lists battles (home no longer does), as a card
    /// alone on a page would have its side margins as well.
    final screens = <String, Future<void> Function(WidgetTester, MatchRecord)>{
      'the history tab': (tester, match) async {
        await tester.pumpWidget(
          Provider<UserRepository>.value(
            value: FakeUserRepository()
              ..historyPages = [
                [match],
              ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const HistoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
    };

    Future<void> open(
      WidgetTester tester,
      String screen,
      MatchRecord match,
    ) async {
      await _loadAppFonts(tester);
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await screens[screen]!(tester, match);
    }

    bool cut(WidgetTester tester, Finder text) =>
        tester.renderObject<RenderParagraph>(text).didExceedMaxLines;

    double linesOf(WidgetTester tester, Finder text) {
      final style = tester.renderObject<RenderParagraph>(text).text.style!;
      return tester.getSize(text).height / (style.fontSize! * style.height!);
    }

    for (final screen in screens.keys) {
      for (final name in names) {
        testWidgets('$name stays whole beside 135 : 220 on $screen', (
          tester,
        ) async {
          await open(tester, screen, battle(name, mine: 135, theirs: 220));
          expect(find.text('135'), findsOneWidget);
          expect(find.text('220'), findsOneWidget);
          expect(find.text('승'), findsOneWidget);
          expect(cut(tester, find.text('vs $name')), isFalse);
          if (name.startsWith('AI 봇')) {
            expect(linesOf(tester, find.text('vs $name')), lessThan(1.2));
          }
          expect(tester.takeException(), isNull);
        });

        testWidgets('$name stays whole beside 12회 : 18회 on $screen', (
          tester,
        ) async {
          await open(tester, screen, battle(name));
          expect(find.text('12회'), findsOneWidget);
          expect(find.text('18회'), findsOneWidget);
          expect(cut(tester, find.text('vs $name')), isFalse);
          expect(tester.takeException(), isNull);
        });
      }

      // The most on the card: three digits each, and a KO, which needs a lead
      // of 100. Reps have no speed cap, and the judge's own limit of 400 ms a
      // rep gives 2000 at most: 50 reps × 20, then 25 in fever × 40.
      for (final (mine, theirs) in const [
        (999, 999),
        (999, 899),
        (2000, 2000),
      ]) {
        for (final name in names) {
          testWidgets('$mine : $theirs and $name stay whole on $screen', (
            tester,
          ) async {
            await open(
              tester,
              screen,
              battle(name, mine: mine, theirs: theirs),
            );
            final card = tester.getRect(find.byType(MatchRecordCard));
            for (final number in [
              find.text('$mine').first,
              find.text('$theirs').last,
            ]) {
              expect(linesOf(tester, number), lessThan(1.2));
              expect(cut(tester, number), isFalse);
              expect(tester.getRect(number).right, lessThan(card.right));
            }
            expect(cut(tester, find.text('vs $name')), isFalse);
            expect(tester.takeException(), isNull);
          });
        }
      }

      // Every title `FormAnalyzer` writes, with counts a 30 s round can reach.
      // Only 바닥 푸시업 아님 ends in "…" from 10회: the user accepted that, as
      // the line is one line by design (Requirements 5.7).
      for (final issue in const [
        '깊이 부족 12회',
        '팔 덜 폄 12회',
        '어깨 기울어짐 12회',
        '너무 빠름 12회',
        '무릎 대고 함 12회',
        '팔 안 굽힘 12회',
        '배 대고 함 12회',
        '바닥 푸시업 아님 9회',
        '폰이 움직임 12회',
        '좌우 불균형',
        '후반 깊이 감소',
        '내려가는 속도',
        '팔꿈치 벌어짐',
        '손 간격',
        '고개가 먼저 내려감',
      ]) {
        testWidgets('"$issue" stays whole beside 135 : 220 on $screen', (
          tester,
        ) async {
          await open(
            tester,
            screen,
            battle('AI 봇 · 고수', mine: 135, theirs: 220, issue: issue),
          );
          expect(cut(tester, find.text(issue)), isFalse);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
