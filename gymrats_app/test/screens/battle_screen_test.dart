import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/game_danger_edge.dart';
import 'package:gymrats_app/widgets/game_fever_chip.dart';
import 'package:gymrats_app/widgets/game_health_bar.dart';
import 'package:gymrats_app/widgets/landmark_overlay.dart';
import 'package:gymrats_app/widgets/opponent_mannequin.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../support/fakes.dart';
import '../support/game_fakes.dart';
import '../support/pose_fixtures.dart';
import '../support/flow_snapshot.dart';
import '../support/placed_phone.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

void main() {
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late FakeRepJudge judge;
  late FakeOpponentSource opponent;
  late Duration now;
  late BattleViewModel viewModel;

  /// Opens BattleScreen from a home page. The result route is a stub that
  /// shows the score it received.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    CameraPermission permission = CameraPermission.granted,
    RepJudge? repJudge,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Created here, inside the test's fake async zone.
    camera = FakeCameraService()..permission = permission;
    estimator = FakePoseEstimator();
    judge = FakeRepJudge();
    opponent = FakeOpponentSource();
    now = Duration.zero;
    viewModel = BattleViewModel(
      matchup: _matchup,
      counter: RepCounterViewModel(
        camera: camera,
        estimator: estimator,
        judge: repJudge ?? judge,
        phoneTilt: placedPhone(),
        clock: () => now,
        roundLength: battleDuration,
      ),
      opponent: opponent,
      repository: FakeUserRepository(),
      sound: FakeRepSound(),
      now: () => DateTime(2026, 10, 4, 14, 32),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BattleScreen(
                    matchup: _matchup,
                    createViewModel: () => viewModel,
                  ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.resultRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) {
              final result = settings.arguments! as BattleResult;
              return Scaffold(
                body: Text('result ${result.myReps}:${result.opponentReps}'),
              );
            },
          ),
          _ => null,
        },
      ),
    );
    await tester.tap(find.text('home'));
    await transition(tester);
  }

  /// One camera frame [seconds] into the round. It closes the rep queued
  /// on the judge, if any.
  Future<void> frame(
    WidgetTester tester,
    double seconds, {
    PoseFrame? pose,
  }) async {
    now = Duration(milliseconds: (seconds * 1000).round());
    estimator.frames.add(pose ?? emptyFrame());
    camera.emit();
    // One pump runs the frame's async work, the next renders the result.
    await tester.pump();
    await tester.pump();
  }

  /// System back. One frame later the dialog it opens takes taps.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
  }

  /// The dialog's 게임 나가기.
  final dialogExit = find.descendant(
    of: find.byType(ExitDialog),
    matching: find.text('게임 나가기'),
  );

  testWidgets('live indicators fit a small phone', (tester) async {
    await prepareFlowSnapshotFonts(tester);
    await open(tester, size: const Size(360, 640));
    judge.snapshot = const JudgeSnapshot(
      phase: RepPhase.descending,
      shoulderDrop: .5,
      topShoulderY: 200,
    );
    judge.closeRep();
    await frame(tester, 1, pose: standingFrame());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChestHeightOverlay), findsOneWidget);
    expect(find.text('하강 50% · 어깨 너비 기준'), findsOneWidget);
    expect(
      tester.widget<GameHealthBar>(find.byType(GameHealthBar)).myShare,
      closeTo(0.55, 1e-9),
    );
    expect(tester.takeException(), isNull);
    await captureFlowSnapshot('ai-battle-live-indicators');
  });

  testWidgets('shows the camera, my chip, the opponent window, and the '
      'scores', (tester) async {
    await open(tester);
    expect(find.byType(PoseCameraView), findsOneWidget);
    expect(find.text('나 · 우현'), findsOneWidget);
    expect(find.byType(OpponentMannequin), findsOneWidget);
    // In the window and over the score.
    expect(find.text('RepBot'), findsNWidgets(2));
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('남은 시간'), findsOneWidget);
    expect(find.text('동점'), findsOneWidget);
    expect(
      tester.widgetList<Text>(find.text('0')).map((text) => text.style!.color),
      [AppColors.accent, AppColors.opponent],
    );
    // No verdict before the first rep, and no demo button.
    expect(find.text('+10 GOOD'), findsNothing);
    expect(find.text('다시 시뮬레이션'), findsNothing);
    expect(opponent.running, isTrue);
  });

  for (final (size, camera) in [
    (const Size(390, 844), const Rect.fromLTWH(0, 0, 390, 520)),
    (const Size(412, 915), const Rect.fromLTWH(0, 0, 412, 412 * 4 / 3)),
    // Short: the panel keeps its room and the camera narrows.
    (const Size(360, 640), const Rect.fromLTWH(45, 0, 270, 360)),
  ]) {
    testWidgets('a ${size.width.toInt()}x${size.height.toInt()} phone shows '
        'the whole 3:4 camera, without overflow', (tester) async {
      await open(tester, size: size);
      expect(tester.getRect(find.byType(PoseCameraView)), camera);

      judge.closeRep(reason: RejectReason.shouldersNotLevel);
      await frame(tester, 2);
      opponent.emit();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await frame(tester, 60);
      await tester.pumpAndSettle();
      expect(find.text('결과 보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('landmarks are drawn over the camera while the round runs', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(LandmarkOverlay), findsNothing);
    await frame(tester, 1, pose: pushUpFrontFrame());
    expect(find.byType(LandmarkOverlay), findsOneWidget);
    expect(
      tester.getRect(find.byType(LandmarkOverlay)),
      tester.getRect(find.byType(PoseCameraView)),
    );
  });

  testWidgets('a counted rep shows +10 GOOD; a rejected one says why, on '
      'amber', (tester) async {
    await open(tester);
    judge.closeRep();
    await frame(tester, 2);
    expect(find.text('+10 GOOD'), findsOneWidget);
    expect(find.text('좋아요, 그 깊이 그대로!'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('유효 1회'), findsOneWidget);

    judge.closeRep(reason: RejectReason.shouldersNotLevel);
    await frame(tester, 4);
    expect(find.text('+10 GOOD'), findsNothing);
    expect(find.text('카운트 안 됨'), findsOneWidget);
    expect(find.text('어깨를 수평으로 맞춰요'), findsOneWidget);
    final banner = tester.widget<Container>(
      find
          .ancestor(of: find.text('카운트 안 됨'), matching: find.byType(Container))
          .first,
    );
    expect((banner.decoration! as BoxDecoration).color, AppColors.warning);
  });

  testWidgets('the lead pill follows the score', (tester) async {
    await open(tester);
    opponent.emit();
    await tester.pump();
    expect(find.text('−10 추격 중'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('−10 추격 중')).style!.color,
      AppColors.opponent,
    );
    expect(
      tester.widget<OpponentMannequin>(find.byType(OpponentMannequin)).moves,
      1,
    );

    judge.closeRep();
    await frame(tester, 2);
    judge.closeRep();
    await frame(tester, 4);
    expect(find.text('+10 리드'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('+10 리드')).style!.color,
      AppColors.accent,
    );
  });

  testWidgets('the clock is lime, cyan in fever, and amber for the last 5 '
      'seconds', (tester) async {
    await open(tester);
    await frame(tester, 19.5);
    expect(
      tester.widget<Text>(find.text('0:11')).style!.color,
      AppColors.accent,
    );
    await frame(tester, 24.5);
    expect(
      tester.widget<Text>(find.text('0:06')).style!.color,
      AppColors.fever,
    );
    await frame(tester, 25);
    expect(
      tester.widget<Text>(find.text('0:05')).style!.color,
      AppColors.warning,
    );
  });

  testWidgets('fever swaps "남은 시간" for the fever chip', (tester) async {
    await open(tester);
    await frame(tester, 19.9);
    expect(find.byType(GameFeverChip), findsNothing);
    expect(find.text('남은 시간'), findsOneWidget);

    await frame(tester, 20);
    expect(find.text('FEVER ×2'), findsOneWidget);
    expect(find.text('남은 시간'), findsNothing);
  });

  testWidgets('each side\'s valid rep moves the bar and pops its +N', (
    tester,
  ) async {
    await open(tester);
    expect(
      tester.widget<GameHealthBar>(find.byType(GameHealthBar)).myShare,
      0.5,
    );

    judge.closeRep();
    await frame(tester, 2);
    var bar = tester.widget<GameHealthBar>(find.byType(GameHealthBar));
    expect(bar.myShare, closeTo(0.55, 1e-9));
    expect(bar.myLastScore!.points, 10);
    expect(bar.opponentLastScore, isNull);
    expect(find.text('+10'), findsOneWidget);

    opponent.emit();
    await tester.pump();
    bar = tester.widget<GameHealthBar>(find.byType(GameHealthBar));
    expect(bar.myShare, 0.5);
    expect(bar.opponentLastScore!.points, 10);
    expect(find.text('+10'), findsNWidgets(2));
  });

  testWidgets('a deep rep says EXCELLENT, and the banner names a combo and '
      'fever', (tester) async {
    final deep = DepthRepJudge();
    await open(tester, repJudge: deep);
    deep.closeRep(maxDepth: 1.8);
    await frame(tester, 3);
    expect(find.text('+15 EXCELLENT'), findsOneWidget);
    expect(find.text('깊게 잘 내려갔어요!'), findsOneWidget);

    deep.closeRep();
    await frame(tester, 4);
    expect(find.text('+15 GOOD'), findsOneWidget);
    expect(find.text('콤보 2'), findsOneWidget);

    deep.closeRep();
    await frame(tester, 21);
    expect(find.text('+20 GOOD'), findsOneWidget);
    expect(find.text('점수 2배'), findsOneWidget);

    deep.closeRep(maxDepth: 1.8);
    await frame(tester, 22);
    expect(find.text('+40 EXCELLENT'), findsOneWidget);
    expect(find.text('콤보 2 · 점수 2배'), findsOneWidget);
  });

  testWidgets('the fullest panel fits a 360x640 phone', (tester) async {
    await open(tester, size: const Size(360, 640));
    for (var i = 0; i < 7; i++) {
      judge.closeRep();
      await frame(tester, 21.0 + i);
      opponent
        ..emit()
        ..emit();
      await tester.pump();
    }
    expect(viewModel.state.phase, BattlePhase.playing);
    expect(viewModel.state.myScore, greaterThan(100));
    expect(viewModel.state.opponentScore, greaterThan(100));
    expect(find.text('FEVER ×2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the screen edge flashes while 60 points behind, and takes no '
      'taps', (tester) async {
    await open(tester);
    GameDangerEdge edge() =>
        tester.widget<GameDangerEdge>(find.byType(GameDangerEdge));
    expect(edge().active, isFalse);

    // Sent at once, so each after the first is a combo: 10, 25, 40, 55, 70.
    for (var i = 0; i < 5; i++) {
      opponent.emit();
    }
    await tester.pump();
    expect(viewModel.state.danger, isTrue);
    expect(edge().active, isTrue);
    expect(
      find.descendant(
        of: find.byType(GameDangerEdge),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );

    judge.closeRep();
    await frame(tester, 5);
    judge.closeRep();
    await frame(tester, 10);
    expect(viewModel.state.danger, isFalse);
    expect(edge().active, isFalse);
  });

  testWidgets('a camera failure stops the edge while the round is held', (
    tester,
  ) async {
    await open(tester);
    for (var i = 0; i < 5; i++) {
      opponent.emit();
    }
    await tester.pump();
    expect(
      tester.widget<GameDangerEdge>(find.byType(GameDangerEdge)).active,
      isTrue,
    );

    // Pose detection keeps failing for 3 seconds.
    for (final seconds in const [1, 5]) {
      now = Duration(seconds: seconds);
      estimator.frames.add(null);
      camera.emit();
      await tester.pump();
      await tester.pump();
    }
    expect(viewModel.state.phase, BattlePhase.failed);
    expect(viewModel.state.danger, isTrue);
    expect(
      tester.widget<GameDangerEdge>(find.byType(GameDangerEdge)).active,
      isFalse,
    );
  });

  testWidgets('a KO shows K.O. with the game scores, stops the edge, and '
      'leads to the result', (tester) async {
    await open(tester);
    judge.closeRep();
    await frame(tester, 2);
    // 10, 25, 40, 55, 70, 85, 100, 115: a 105-point lead.
    for (var i = 0; i < 8; i++) {
      opponent.emit();
    }
    await tester.pumpAndSettle();
    expect(find.text('K.O.'), findsOneWidget);
    expect(find.text('TIME UP'), findsNothing);
    expect(find.text('아쉽게 졌어요'), findsOneWidget);
    expect(find.text('115'), findsWidgets);
    expect(
      tester.widget<GameDangerEdge>(find.byType(GameDangerEdge)).active,
      isFalse,
    );

    await tester.tap(find.text('결과 보기'));
    await transition(tester);
    expect(find.text('result 1:8'), findsOneWidget);
  });

  for (final (mine, theirs, verdict) in const [
    (2, 1, '승리!'),
    (1, 2, '아쉽게 졌어요'),
    (1, 1, '무승부'),
  ]) {
    testWidgets('time up at $mine:$theirs says "$verdict"', (tester) async {
      await open(tester);
      for (var i = 0; i < mine; i++) {
        judge.closeRep();
        await frame(tester, 2.0 + i);
      }
      for (var i = 0; i < theirs; i++) {
        opponent.emit();
      }
      await tester.pump();
      await frame(tester, 60);
      expect(find.text('TIME UP'), findsOneWidget);
      expect(find.text(verdict), findsOneWidget);
      expect(find.text('결과 보기'), findsOneWidget);
      expect(find.text('다시 시뮬레이션'), findsNothing);
    });
  }

  testWidgets('결과 보기 replaces the battle with the result', (tester) async {
    await open(tester);
    judge.closeRep();
    await frame(tester, 3);
    opponent.emit();
    await tester.pump();
    await frame(tester, 60);
    await tester.tap(find.text('결과 보기'));
    await tester.pumpAndSettle();
    expect(find.text('result 1:1'), findsOneWidget);
    expect(find.byType(BattleScreen), findsNothing);

    // Replaced, not pushed: back from the result goes home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('back asks; 게임 나가기 goes home and keeps nothing', (tester) async {
    await open(tester);
    await back(tester);
    expect(find.text('게임에서 나갈까요?'), findsOneWidget);
    expect(find.text('RepBot과의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
    expect(find.byType(BattleScreen), findsOneWidget);

    await tester.tap(dialogExit);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(BattleScreen), findsNothing);
    expect(opponent.stopped, isTrue);
    expect(opponent.disposed, isTrue);
    expect(camera.isStreaming, isFalse);
  });

  testWidgets('계속하기 keeps the battle going', (tester) async {
    await open(tester);
    await back(tester);
    await tester.tap(find.text('계속하기'));
    await transition(tester);
    expect(find.byType(ExitDialog), findsNothing);
    expect(viewModel.state.phase, BattlePhase.playing);
    expect(opponent.running, isTrue);
  });

  testWidgets('time running out while asking closes the question', (
    tester,
  ) async {
    await open(tester);
    await back(tester);
    expect(find.byType(ExitDialog), findsOneWidget);
    await frame(tester, 60);
    await tester.pumpAndSettle();
    expect(find.byType(ExitDialog), findsNothing);
    expect(find.text('TIME UP'), findsOneWidget);
    expect(find.byType(BattleScreen), findsOneWidget);
  });

  testWidgets('after time up, back goes home without asking', (tester) async {
    await open(tester);
    await frame(tester, 60);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ExitDialog), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the app in the background holds the round', (tester) async {
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(viewModel.state.phase, BattlePhase.paused);
    expect(opponent.running, isFalse);
    expect(camera.isStreaming, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(viewModel.state.phase, BattlePhase.playing);
    expect(opponent.running, isTrue);
    expect(camera.isStreaming, isTrue);
  });

  testWidgets('keeps the screen on and portrait while open', (tester) async {
    final device = <(String, Object?)>[];
    final orientations = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    const deviceChannel = MethodChannel('gymrats/device');
    messenger.setMockMethodCallHandler(deviceChannel, (call) async {
      device.add((call.method, call.arguments));
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(call.arguments);
      }
      return null;
    });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(deviceChannel, null)
        ..setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await open(tester);
    expect(device, [('keepScreenOn', true)]);
    expect(orientations, [
      ['DeviceOrientation.portraitUp'],
    ]);

    await back(tester);
    await tester.tap(dialogExit);
    await tester.pumpAndSettle();
    expect(device, [('keepScreenOn', true), ('keepScreenOn', false)]);
  });

  testWidgets('the round waits for portrait', (tester) async {
    await open(tester, size: const Size(915, 412));
    expect(camera.startCount, 0);
    expect(viewModel.state.phase, BattlePhase.starting);

    tester.view.physicalSize = const Size(412, 915);
    await tester.pump();
    await tester.pump();
    expect(camera.startCount, 1);
    expect(viewModel.state.phase, BattlePhase.playing);
  });

  testWidgets('a camera problem offers a retry that restarts the round', (
    tester,
  ) async {
    await open(tester, permission: CameraPermission.denied);
    expect(find.text('카메라 권한이 필요해요'), findsOneWidget);
    expect(opponent.startCount, 0);

    camera.permission = CameraPermission.granted;
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump();
    expect(find.text('카메라 권한이 필요해요'), findsNothing);
    expect(viewModel.state.phase, BattlePhase.playing);
    expect(opponent.startCount, 1);
  });

  testWidgets('a camera turned off in settings offers the settings', (
    tester,
  ) async {
    await open(tester, permission: CameraPermission.permanentlyDenied);
    expect(find.text('카메라 권한이 꺼져 있어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    await tester.tap(find.text('설정 열기'));
    await tester.pump();
    expect(camera.settingsCount, 1);
  });
}

/// Pumps a page transition to its end. The LIVE light blinks while the
/// round runs, so pumpAndSettle would not return.
Future<void> transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
