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
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';

import '../support/fakes.dart';
import '../support/game_fakes.dart';
import '../support/placed_phone.dart';
import '../support/pose_fixtures.dart';

/// Tests otherwise draw every letter as the same square, so only here does
/// the panel's text have its real width. In its own file, as the fonts stay
/// loaded for the rest of the run.
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
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late DepthRepJudge judge;
  late TimedOpponentSource opponent;
  late Duration now;

  Future<void> open(WidgetTester tester, Size size) async {
    await _loadAppFonts(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    judge = DepthRepJudge();
    opponent = TimedOpponentSource();
    now = Duration.zero;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BattleScreen(
          matchup: const Matchup(
            exercise: ExerciseType.pushUp,
            playerName: '우현',
            opponent: Opponent(name: 'RepBot', isBot: true),
          ),
          createViewModel: () => BattleViewModel(
            matchup: const Matchup(
              exercise: ExerciseType.pushUp,
              playerName: '우현',
              opponent: Opponent(name: 'RepBot', isBot: true),
            ),
            counter: RepCounterViewModel(
              camera: camera,
              estimator: estimator,
              judge: judge,
              phoneTilt: placedPhone(),
              clock: () => now,
              roundLength: battleDuration,
            ),
            opponent: opponent,
            repository: FakeUserRepository(),
            sound: FakeRepSound(),
            now: () => DateTime(2026, 10, 4, 14, 32),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> myRep(WidgetTester tester, double seconds) async {
    judge.closeRep(maxDepth: 1.8);
    now = Duration(milliseconds: (seconds * 1000).round());
    estimator.frames.add(emptyFrame());
    camera.emit();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  bool truncated(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  for (final size in const [Size(360, 780), Size(360, 640), Size(412, 915)]) {
    final name = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('on $name the banner never cuts its words', (tester) async {
      await open(tester, size);
      await myRep(tester, 3);
      expect(find.text('+15 EXCELLENT'), findsOneWidget);
      expect(truncated(tester, '깊게 잘 내려갔어요!'), isFalse);

      await myRep(tester, 21);
      await myRep(tester, 22);
      expect(find.text('+40 EXCELLENT'), findsOneWidget);
      expect(truncated(tester, '콤보 2 · 점수 2배'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on $name the average banner keeps the reason and the points '
        'whole', (tester) async {
      await open(tester, size);
      judge.closeRep(reason: RejectReason.insufficientDepth, minElbowAngle: 90);
      now = const Duration(seconds: 21);
      estimator.frames.add(emptyFrame());
      camera.emit();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('카운트 안 됨'), findsOneWidget);
      expect(truncated(tester, '가슴을 더 내려요'), isFalse);
      // Inside the banner, and at full size: nothing cut, nothing shrunk.
      final banner = tester.getRect(
        find
            .ancestor(
              of: find.text('+10 AVERAGE'),
              matching: find.byType(Container),
            )
            .first,
      );
      for (final words in const ['가슴을 더 내려요', '+10 AVERAGE']) {
        final rect = tester.getRect(find.text(words));
        expect(rect.right, lessThanOrEqualTo(banner.right), reason: words);
        expect(rect.bottom, lessThanOrEqualTo(banner.bottom), reason: words);
        expect(
          rect.height,
          closeTo(tester.getSize(find.text(words)).height, 0.5),
          reason: words,
        );
      }
      expect(banner.height, 60);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on $name three digits stay the same size as two', (
      tester,
    ) async {
      await open(tester, size);
      opponent.emitAt(5);
      opponent.emitAt(10);
      opponent.emitAt(15);
      await tester.pump();
      await myRep(tester, 21);
      await myRep(tester, 22);
      await myRep(tester, 23);
      expect(find.text('FEVER ×2'), findsOneWidget);
      expect(
        tester.getRect(find.text('110')).height,
        closeTo(tester.getRect(find.text('30')).height, 0.5),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in const [1.3, 1.5]) {
    testWidgets('on 360x780 at text scale $scale the average banner stays the '
        'size of the others', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, const Size(360, 780));
      judge.closeRep(reason: RejectReason.insufficientDepth, minElbowAngle: 90);
      now = const Duration(seconds: 3);
      estimator.frames.add(emptyFrame());
      camera.emit();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('+5 AVERAGE'), findsOneWidget);
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('+5 AVERAGE'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        60,
      );
      expect(tester.takeException(), isNull);
    });
  }

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
