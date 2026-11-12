import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';

/// Tests otherwise draw every letter as the same square, so only here does
/// the text of the rules and the result have its real width. In its own
/// file, as the fonts stay loaded for the rest of the run.
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

void main() {
  bool truncated(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  for (final scale in const [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('at 360 wide and text scale $scale the rules page keeps each '
        'of the four score tiles on one line', (tester) async {
      await _loadAppFonts(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HelpScreen(onStart: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      final lineHeight = tester.getSize(find.text('콤보')).height;
      for (final label in const ['Average', 'Good', 'Excellent']) {
        expect(
          tester.getSize(find.text(label)).height,
          lineHeight,
          reason: label,
        );
        expect(truncated(tester, label), isFalse, reason: label);
      }
      // +5 is short enough never to break: the others must match it.
      final pointsHeight = tester.getSize(find.text('+5').first).height;
      expect(tester.getSize(find.text('+10')).height, pointsHeight);
      expect(tester.getSize(find.text('+15')).height, pointsHeight);
      expect(truncated(tester, '+10'), isFalse);
      expect(truncated(tester, '+15'), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  group('the result with the grades', () {
    final result = BattleResult(
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'RepBot', isBot: true),
      ),
      myReps: 12,
      myInvalidReps: 3,
      opponentReps: 11,
      myScore: 180,
      opponentScore: 150,
      decidedOutcome: MatchOutcome.win,
      endedAt: DateTime(2026, 10, 4, 14, 32),
      form: FormReport(
        endedAt: DateTime(2026, 10, 4, 14, 32),
        opponentName: 'RepBot',
        roundLength: battleDuration,
        reps: [
          for (var i = 0; i < 10; i++)
            RepRecord(
              index: i + 1,
              valid: true,
              at: Duration(seconds: i + 1),
              maxDepth: i == 0 ? 1.9 : 1.4,
            ),
          RepRecord(
            index: 11,
            valid: false,
            at: const Duration(seconds: 15),
            reason: RejectReason.insufficientDepth,
            minElbowAngle: 90,
          ),
        ],
        samples: const [],
      ),
    );

    for (final size in const [Size(360, 640), Size(360, 780)]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        final name = '${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('on $name at text scale $scale all three stay on the '
            'card', (tester) async {
          await _loadAppFonts(tester);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: ResultScreen(result: result),
            ),
          );
          final first = tester.getRect(find.text('Excellent 1'));
          final last = tester.getRect(find.text('Average 1'));
          expect(find.text('Good 9'), findsOneWidget);
          // One line, though each shrinks by its own width.
          expect(first.center.dy, closeTo(last.center.dy, 1));
          expect(first.left, greaterThanOrEqualTo(0));
          expect(last.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
