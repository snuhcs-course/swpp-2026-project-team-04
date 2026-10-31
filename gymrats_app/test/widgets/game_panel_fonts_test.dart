import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
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
}
