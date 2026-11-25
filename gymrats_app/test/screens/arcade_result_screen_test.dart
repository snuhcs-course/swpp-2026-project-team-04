import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/arcade_result_screen.dart';
import 'package:gymrats_app/screens/hold_stage_result.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/arcade_viewmodel.dart';
import 'package:provider/provider.dart';

BattleResult _battle(Matchup matchup, {required bool won}) => BattleResult(
  matchup: matchup,
  myReps: 12,
  myInvalidReps: 1,
  opponentReps: 8,
  myScore: won ? 1600 : 900,
  opponentScore: won ? 900 : 1600,
  decidedOutcome: won ? MatchOutcome.win : MatchOutcome.lose,
  end: GameEnd.timeUp,
  endedAt: DateTime(2026, 11, 24, 20),
);

Matchup _fight(int number) => ArcadeMatchups.fight(
  ArcadeCatalog.stage(number) as ArcadeFightStage,
  playerName: '우현',
);

Matchup _boss(int number, int round) => ArcadeMatchups.boss(
  ArcadeCatalog.stage(number) as ArcadeBossStage,
  round,
  playerName: '우현',
);

void main() {
  /// Every result the arcade shows, with the words of its buttons.
  final results =
      <(String, ArcadeStage, List<BattleResult>, ArcadeStars, List<String>)>[
        (
          'a fight cleared',
          ArcadeCatalog.stage(8),
          [_battle(_fight(8), won: true)],
          const ArcadeStars(true, true, true),
          ['다음 스테이지', '리포트 보기'],
        ),
        (
          'a fight failed',
          ArcadeCatalog.stage(8),
          [_battle(_fight(8), won: false)],
          ArcadeStars.none,
          ['다시 도전', '리포트 보기', '아케이드로'],
        ),
        (
          'a boss match failed in R2',
          ArcadeCatalog.stage(6),
          [_battle(_boss(6, 1), won: true), _battle(_boss(6, 2), won: false)],
          ArcadeStars.none,
          ['R1부터 다시', '리포트 보기', '아케이드로'],
        ),
        (
          'a floor cleared',
          ArcadeCatalog.stage(6),
          [_battle(_boss(6, 1), won: true), _battle(_boss(6, 2), won: true)],
          const ArcadeStars(true, false, false),
          ['2층으로', '리포트 보기'],
        ),
        (
          '4F cleared',
          ArcadeCatalog.stage(24),
          [_battle(_boss(24, 1), won: true), _battle(_boss(24, 2), won: true)],
          const ArcadeStars(true, true, false),
          ['아케이드로', '리포트 보기'],
        ),
      ];

  // The sizes the hold step's frame was fixed for: a 320-wide phone, and
  // large text on the design's phone.
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(360, 780), 1.3),
  ]) {
    for (final (name, stage, rounds, stars, buttons) in results) {
      testWidgets('$name fits ${size.width.toInt()} x ${size.height.toInt()} '
          'with ${scale}x text, every button reachable', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final arcade = ArcadeViewModel(store: MemoryArcadeProgressStore());
        addTearDown(arcade.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<ArcadeViewModel>.value(
            value: arcade,
            child: MaterialApp(
              theme: AppTheme.light,
              home: ArcadeResultScreen(
                stage: stage,
                rounds: rounds,
                stars: stars,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ArcadeResultFrame), findsOneWidget);
        for (final button in buttons) {
          final target = find.text(button);
          expect(target, findsOneWidget, reason: button);
          await tester.ensureVisible(target);
          await tester.pump();
          expect(target.hitTestable(), findsOneWidget, reason: button);
        }
      });
    }
  }
}
