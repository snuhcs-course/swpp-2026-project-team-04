import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_arena.dart';
import 'package:gymrats_app/widgets/battle_banner.dart';
import 'package:gymrats_app/widgets/battle_camera_area.dart';
import 'package:gymrats_app/widgets/battle_fighter.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_reject_sign.dart';
import 'package:gymrats_app/widgets/battle_stage.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

import 'battle_test_support.dart';

BattleStageState _state({
  BattleStagePhase phase = BattleStagePhase.playing,
  int me = 0,
  int op = 0,
  int myReps = 0,
  int opReps = 0,
  bool fever = false,
  bool danger = false,
  bool meReady = false,
  bool opReady = false,
  Duration? countdown,
  bool reconnecting = false,
  bool opponentDisconnected = false,
  BattleStageEnd? end,
}) => BattleStageState(
  phase: phase,
  myName: 'hellohello',
  opponentName: 'AI 봇 · 고수',
  remaining: const Duration(seconds: 18),
  roundLength: const Duration(seconds: 30),
  myScore: me,
  opponentScore: op,
  myReps: myReps,
  opponentReps: opReps,
  barShare: (0.5 + (me - op) / 200).clamp(0.0, 1.0),
  fever: fever,
  danger: danger,
  meReady: meReady,
  opponentReady: opReady,
  countdown: countdown,
  reconnecting: reconnecting,
  opponentDisconnected: opponentDisconnected,
  end: end,
);

const _myGood = BattleStageEvent(
  side: BattleSide.me,
  grade: GameGrade.good,
  points: 10,
  combo: 1,
);

const _koEnd = BattleStageEnd(
  kind: BattleEndKind.knockout,
  winner: BattleSide.me,
);

const _camera = Key('camera');

/// How often the camera picture was tapped.
int _cameraTaps = 0;

/// Builds the arena as a whole screen of [size] with a status bar [top]
/// tall. Pump it again with another state to change the battle.
Future<void> _pump(
  WidgetTester tester,
  BattleStageController controller,
  BattleStageState state, {
  Size size = const Size(360, 780),
  double top = 26,
  bool reducedMotion = false,
  ValueChanged<BattleStageCue>? onCue,
  VoidCallback? onLeave,
  VoidCallback? onShowResult,
  String? hint,
  String? readyLabel,
  VoidCallback? onReady,
}) async {
  // The test's screen is the phone's.
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    battleTestApp(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: EdgeInsets.only(top: top),
          disableAnimations: reducedMotion,
        ),
        child: Material(
          child: BattleArena(
            controller: controller,
            state: state,
            camera: AspectRatio(
              aspectRatio: 3 / 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _cameraTaps++,
                child: const ColoredBox(
                  key: _camera,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            onCue: onCue,
            onLeave: onLeave,
            onShowResult: onShowResult,
            hint: hint,
            readyLabel: readyLabel,
            onReady: onReady,
          ),
        ),
      ),
      size: size,
    ),
  );
}

Future<void> _wait(WidgetTester tester, int milliseconds) =>
    tester.pump(Duration(milliseconds: milliseconds));

BattleFxFrame _frame(WidgetTester tester) =>
    tester.widget<BattleStage>(find.byType(BattleStage)).frame;

/// The pose [side] is drawn in. A flashing fighter is in the tree more than
/// once (the white shape and its edge); all of them are the same picture.
BattlePose _pose(WidgetTester tester, BattleSide side) => tester
    .widget<BattleFighter>(
      find.byWidgetPredicate((w) => w is BattleFighter && w.side == side).first,
    )
    .pose;

Finder _dangerEdge() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).border is Border &&
      ((w.decoration as BoxDecoration).border! as Border).top.width == 10,
);

void main() {
  setUpAll(loadBattleFonts);

  /// What a screen reader was told, in order.
  late List<String> said;

  setUp(() {
    said = [];
    _cameraTaps = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
          message,
        ) async {
          final event = message as Map<dynamic, dynamic>;
          if (event['type'] == 'announce') {
            said.add(
              (event['data'] as Map<dynamic, dynamic>)['message'] as String,
            );
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        );
  });

  group('BattleArena, laid out', () {
    testWidgets('on the design\'s 360 x 780 phone the stage fills the upper '
        'half and the camera the lower', (tester) async {
      await _pump(tester, BattleStageController(), _state());
      expect(
        tester.getRect(find.byType(BattleStage)),
        const Rect.fromLTWH(0, 0, 360, 390),
      );
      expect(
        tester.getRect(find.byType(BattleCameraArea)),
        const Rect.fromLTWH(0, 390, 360, 390),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a taller phone the stage is sized as a whole to the room '
        'under the status bar, standing on the line', (tester) async {
      await _pump(
        tester,
        BattleStageController(),
        _state(),
        size: const Size(393, 852),
        top: 30,
      );
      // The line is half way down; 364 design points must fit above it and
      // below the status bar.
      const scale = (426 - 30) / 364;
      final stage = tester.getRect(find.byType(BattleStage));
      expect(stage.width, closeTo(360 * scale, 0.01));
      expect(stage.height, closeTo(390 * scale, 0.01));
      expect(stage.bottom, closeTo(426, 0.01));
      expect(stage.center.dx, closeTo(393 / 2, 0.01));
      // The HUD starts below the status bar.
      expect(
        tester.getRect(find.text('hellohello')).top,
        greaterThanOrEqualTo(30),
      );
      expect(tester.getRect(find.byType(BattleCameraArea)).top, 426);
    });

    testWidgets('on a narrow phone the width decides', (tester) async {
      await _pump(
        tester,
        BattleStageController(),
        _state(),
        size: const Size(320, 800),
        top: 24,
      );
      final stage = tester.getRect(find.byType(BattleStage));
      expect(stage.width, closeTo(320, 0.01));
      expect(stage.bottom, closeTo(400, 0.01));
      expect(stage.left, closeTo(0, 0.01));
    });

    testWidgets('the ground fills the whole upper half, behind the status '
        'bar and beside a narrower stage', (tester) async {
      await _pump(
        tester,
        BattleStageController(),
        _state(),
        size: const Size(800, 600),
        top: 0,
      );
      expect(
        tester.getRect(find.byType(BattleStageBackdrop)),
        const Rect.fromLTWH(0, 0, 800, 300),
      );
      final stage = tester.getRect(find.byType(BattleStage));
      expect(stage.width, lessThan(800));
      expect(stage.center.dx, closeTo(400, 0.01));
      final backdrop = tester.widget<BattleStageBackdrop>(
        find.byType(BattleStageBackdrop),
      );
      expect(backdrop.scale, closeTo(300 / 364, 1e-9));
      expect(backdrop.origin.dx, closeTo(stage.left, 0.01));
      expect(backdrop.origin.dy, closeTo(stage.top, 0.01));
    });

    testWidgets('the stage is clipped to the upper half: a fighter knocked '
        'out of the ring is never drawn over the camera', (tester) async {
      await _pump(tester, BattleStageController(), _state());
      final clip = find.ancestor(
        of: find.byType(BattleStage),
        matching: find.byType(ClipRect),
      );
      expect(clip, findsOneWidget);
      expect(tester.getRect(clip), const Rect.fromLTWH(0, 0, 360, 390));
    });

    testWidgets('the camera is shown in the lower half', (tester) async {
      await _pump(tester, BattleStageController(), _state());
      final camera = tester.getRect(find.byKey(_camera));
      expect(camera.top, greaterThanOrEqualTo(390));
      expect(camera.bottom, lessThanOrEqualTo(780));
    });
  });

  group('BattleArena, playing', () {
    testWidgets('stands where the score is from the first frame, then glides '
        'when the score changes', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state(me: 60));
      expect(_frame(tester).meetX, 240);
      await _wait(tester, 500);
      expect(_frame(tester).meetX, 240);
      await _pump(tester, controller, _state(me: 100));
      await _wait(tester, 110);
      expect(_frame(tester).meetX, greaterThan(250));
      expect(_frame(tester).meetX, lessThan(275));
      await _wait(tester, 2000);
      expect(_frame(tester).meetX, closeTo(280, 0.01));
    });

    testWidgets('a rep given to the controller plays on the stage: the lunge, '
        'then the blow 80 ms later', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _wait(tester, 1000);
      controller.rep(_myGood);
      await _wait(tester, 40);
      expect(_pose(tester, BattleSide.me), BattlePose.attack);
      expect(_pose(tester, BattleSide.opponent), BattlePose.idle);
      await _wait(tester, 60);
      expect(_pose(tester, BattleSide.opponent), BattlePose.hit);
      expect(_frame(tester).star, isNotNull);
      await _wait(tester, 1500);
      expect(_pose(tester, BattleSide.me), BattlePose.idle);
      expect(_pose(tester, BattleSide.opponent), BattlePose.idle);
    });

    testWidgets('gives each cue once, when it shows', (tester) async {
      final cues = <String>[];
      final controller = BattleStageController();
      await _pump(tester, controller, _state(), onCue: (c) => cues.add('$c'));
      await _wait(tester, 500);
      controller.rep(_myGood);
      await _wait(tester, 70);
      expect(cues, isEmpty);
      await _wait(tester, 20);
      expect(cues, ['hit me good']);
      controller.rep(
        const BattleStageEvent(side: BattleSide.opponent, grade: null),
      );
      await _wait(tester, 16);
      await _wait(tester, 3000);
      expect(cues, ['hit me good', 'miss opponent']);
    });

    testWidgets('a combo shows "2 HIT" over the camera, 14 under the line on '
        'the left, and under the reconnect band while it is up', (
      tester,
    ) async {
      Future<double> markTop(bool reconnecting) async {
        final controller = BattleStageController();
        final state = _state(reconnecting: reconnecting);
        await _pump(tester, controller, state);
        await _wait(tester, 500);
        controller.rep(_myGood);
        await _wait(tester, 500);
        controller.rep(
          const BattleStageEvent(
            side: BattleSide.me,
            grade: GameGrade.good,
            points: 15,
            combo: 2,
          ),
        );
        await _wait(tester, 400);
        final mark = find.descendant(
          of: find.byType(BattleCameraArea),
          matching: find.text('2 HIT'),
        );
        expect(mark, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BattleStage),
            matching: find.text('2 HIT'),
          ),
          findsNothing,
        );
        // Turned around its outer end, 6 from the left: the band's middle
        // there stays at 14 + half its height under the line.
        final band = find.ancestor(of: mark, matching: find.byType(BattleBand));
        final outer = Offset.lerp(
          tester.getTopLeft(band),
          tester.getBottomLeft(band),
          0.5,
        )!;
        expect(outer.dx, closeTo(6, 0.01));
        return outer.dy - BattleFx.bandBox(44).height / 2;
      }

      // On the design's phone the line is at 390 and the stage at scale 1.
      expect(await markTop(false), closeTo(390 + 14, 0.01));
      expect(await markTop(true), closeTo(390 + 14 + 34, 0.5));
    });

    testWidgets('a blow shows its grade word as it lands, then its points '
        '(UAT-5 "the label appears at once")', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _wait(tester, 500);
      controller.rep(_myGood);
      await _pump(tester, controller, _state(me: 10, myReps: 1));
      await _wait(tester, 60);
      expect(find.text('GOOD'), findsNothing);
      await _wait(tester, 40);
      expect(find.text('GOOD'), findsOneWidget);
      expect(find.text('+10'), findsNothing);
      // The score is already up; the band repeats it.
      expect(find.text('10'), findsOneWidget);
      await _wait(tester, 400);
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('GOOD'), findsNothing);
      await _wait(tester, 1000);
      expect(find.text('+10'), findsNothing);
    });

    testWidgets('on a larger phone the combo mark is sized with the stage', (
      tester,
    ) async {
      const size = Size(393, 852);
      final controller = BattleStageController();
      await _pump(tester, controller, _state(), size: size);
      await _wait(tester, 500);
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: GameGrade.good,
          points: 15,
          combo: 2,
        ),
      );
      await _wait(tester, 400);
      // The line is half way down; the stage is as large as the width lets
      // it be here (393 / 360 < (426 - 26) / 364).
      const line = 852 / 2;
      const scale = 393 / 360;
      final band = find.ancestor(
        of: find.text('2 HIT'),
        matching: find.byType(BattleBand),
      );
      final outer = Offset.lerp(
        tester.getTopLeft(band),
        tester.getBottomLeft(band),
        0.5,
      )!;
      final height = BattleFx.bandBox(44).height * scale;
      expect(outer.dx, closeTo(6 * scale, 0.01));
      expect(outer.dy - height / 2, closeTo(line + 14 * scale, 0.01));
      expect(
        (tester.getBottomLeft(band) - tester.getTopLeft(band)).distance,
        closeTo(height, 0.01),
      );
    });

    testWidgets('a three-digit score shrinks when it bumps; a two-digit one '
        'grows', (tester) async {
      for (final (score, bump) in [(120, 0.9), (60, 1.2)]) {
        final controller = BattleStageController();
        await _pump(tester, controller, _state(me: score, op: 30));
        await _wait(tester, 500);
        controller.rep(_myGood);
        await _wait(tester, 80 + 140);
        expect(_frame(tester).myScoreBump, closeTo(bump, 0.01));
      }
    });

    testWidgets('fever turns the ground cyan and puts an aura on both', (
      tester,
    ) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _wait(tester, 100);
      expect(
        tester
            .widget<BattleStageBackdrop>(find.byType(BattleStageBackdrop))
            .feverOpacity,
        0,
      );
      await _pump(tester, controller, _state(fever: true));
      await _wait(tester, 300);
      expect(
        tester
            .widget<BattleStageBackdrop>(find.byType(BattleStageBackdrop))
            .feverOpacity,
        1,
      );
      expect(_frame(tester).me.glow, isTrue);
      expect(find.text('FEVER ×2'), findsNWidgets(2));
    });

    testWidgets('while I am about to lose a 10 wide red edge blinks around '
        'the whole screen', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state(op: 65, danger: true));
      await _wait(tester, 16);
      expect(
        tester.getRect(_dangerEdge()),
        const Rect.fromLTWH(0, 0, 360, 780),
      );
      Color edge() =>
          ((tester.widget<DecoratedBox>(_dangerEdge()).decoration
                          as BoxDecoration)
                      .border!
                  as Border)
              .top
              .color;
      expect(edge(), AppColors.danger.withValues(alpha: 0.3));
      await _wait(tester, 240);
      expect(edge(), AppColors.danger.withValues(alpha: 0.95));
      // It takes no taps.
      await _pump(tester, controller, _state());
      await _wait(tester, 16);
      expect(_dangerEdge(), findsNothing);
    });

    testWidgets('no red edge before the start, whatever the state says', (
      tester,
    ) async {
      await _pump(
        tester,
        BattleStageController(),
        _state(phase: BattleStagePhase.setup, danger: true),
      );
      await _wait(tester, 16);
      expect(_dangerEdge(), findsNothing);
    });

    testWidgets('my rejected rep raises the sign across the line, in the '
        'middle, and it takes no taps', (tester) async {
      var left = 0;
      final controller = BattleStageController();
      await _pump(
        tester,
        controller,
        _state(),
        size: const Size(393, 852),
        top: 30,
        onLeave: () => left++,
      );
      await _wait(tester, 100);
      expect(find.byType(BattleRejectSignView), findsNothing);
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: null,
          reason: RejectReason.kneesDown,
        ),
      );
      await _wait(tester, 400);
      const scale = (426 - 30) / 364;
      final sign = find.byType(BattleRejectSignView);
      expect(tester.getTopLeft(sign).dy, closeTo(426 - 50 * scale, 0.5));
      expect(
        (tester.getTopLeft(sign).dx + tester.getTopRight(sign).dx) / 2,
        closeTo(393 / 2, 0.5),
      );
      expect(
        (tester.getTopRight(sign) - tester.getTopLeft(sign)).distance,
        closeTo(176 * scale, 0.5),
      );
      expect(find.text('무릎 떼기'), findsOneWidget);
      await _wait(tester, 1000);
      expect(find.byType(BattleRejectSignView), findsNothing);
      expect(left, 0);
    });

    testWidgets('the opponent\'s lost connection shows as a tag over a faded '
        'fighter', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _wait(tester, 16);
      expect(find.text('연결 끊김'), findsNothing);
      await _pump(tester, controller, _state(opponentDisconnected: true));
      await _wait(tester, 16);
      expect(find.text('연결 끊김'), findsOneWidget);
      expect(_frame(tester).opponent.opacity, 0.45);
    });

    testWidgets('the reconnect band shows only while the round is on', (
      tester,
    ) async {
      final controller = BattleStageController();
      const band = '재연결 중 · 경기 시간은 계속 진행됩니다.';
      await _pump(
        tester,
        controller,
        _state(phase: BattleStagePhase.setup, reconnecting: true),
      );
      await _wait(tester, 16);
      expect(find.text(band), findsNothing);
      await _pump(tester, controller, _state(reconnecting: true));
      await _wait(tester, 500);
      expect(find.text(band), findsOneWidget);
      expect(
        tester.widget<BattleCameraArea>(find.byType(BattleCameraArea)).spin,
        isNot(0),
      );
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.ended,
          reconnecting: true,
          end: const BattleStageEnd(kind: BattleEndKind.timeUp),
        ),
      );
      await _wait(tester, 16);
      expect(find.text(band), findsNothing);
    });

    testWidgets('the leave button asks to leave', (tester) async {
      var asked = 0;
      await _pump(
        tester,
        BattleStageController(),
        _state(),
        onLeave: () => asked++,
      );
      await tester.tap(find.byIcon(Icons.logout_rounded));
      expect(asked, 1);
    });
  });

  group('BattleArena, before the start', () {
    testWidgets('setting up: tags over both, the band, and the camera '
        'area\'s hint and ready button', (tester) async {
      var ready = 0;
      await _pump(
        tester,
        BattleStageController(),
        _state(phase: BattleStagePhase.setup, opReady: true),
        hint: '폰을 더 세워 주세요.',
        readyLabel: '준비',
        onReady: () => ready++,
      );
      await _wait(tester, 16);
      expect(find.text('자세 세팅 중'), findsOneWidget);
      expect(find.text('세팅 중'), findsOneWidget);
      expect(find.text('준비 완료'), findsOneWidget);
      expect(find.text('폰을 더 세워 주세요.'), findsOneWidget);
      // No chip before the start.
      expect(find.text('동점'), findsNothing);
      await tester.tap(find.text('준비'));
      expect(ready, 1);
    });

    testWidgets('waiting for the opponent says so', (tester) async {
      await _pump(
        tester,
        BattleStageController(),
        _state(phase: BattleStagePhase.setup, meReady: true),
      );
      await _wait(tester, 16);
      expect(find.text('상대를 기다리는 중'), findsOneWidget);
    });

    testWidgets('the countdown shows 3, 2, 1 and GO!, gives their cues, and '
        'the chip appears at the start', (tester) async {
      final cues = <String>[];
      final controller = BattleStageController();
      await _pump(
        tester,
        controller,
        _state(phase: BattleStagePhase.setup, meReady: true, opReady: true),
        onCue: (c) => cues.add('$c'),
      );
      await _wait(tester, 500);
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.countdown,
          countdown: const Duration(seconds: 3),
        ),
        onCue: (c) => cues.add('$c'),
      );
      await _wait(tester, 16);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('준비 완료'), findsNothing);
      await _wait(tester, 1000);
      expect(find.text('2'), findsOneWidget);
      await _wait(tester, 1000);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('동점'), findsNothing);
      await _wait(tester, 1000);
      await _pump(tester, controller, _state(), onCue: (c) => cues.add('$c'));
      await _wait(tester, 16);
      expect(find.text('GO!'), findsOneWidget);
      expect(find.text('동점'), findsOneWidget);
      expect(cues, ['countdown 3', 'countdown 2', 'countdown 1', 'go']);
      await _wait(tester, 800);
      expect(find.text('GO!'), findsNothing);
    });

    testWidgets('losing the pose during the countdown stops it', (
      tester,
    ) async {
      final controller = BattleStageController();
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.countdown,
          countdown: const Duration(seconds: 3),
        ),
      );
      await _wait(tester, 500);
      expect(find.text('3'), findsOneWidget);
      await _pump(
        tester,
        controller,
        _state(phase: BattleStagePhase.setup, opReady: true),
      );
      await _wait(tester, 3000);
      expect(find.text('GO!'), findsNothing);
      expect(find.text('자세 세팅 중'), findsOneWidget);
    });
  });

  group('BattleArena, at the end', () {
    testWidgets('the controller says when 결과 보기 is up, for the system\'s '
        'back gesture', (tester) async {
      final controller = BattleStageController();
      expect(controller.resultReady, isFalse);
      await _pump(tester, controller, _state());
      await _wait(tester, 500);
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.ended,
          end: const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.me,
          ),
        ),
      );
      await _wait(tester, 1700);
      expect(controller.resultReady, isFalse);
      expect(find.text('결과 보기'), findsNothing);
      await _wait(tester, 150);
      expect(controller.resultReady, isTrue);
      expect(find.text('결과 보기'), findsOneWidget);
    });

    testWidgets('a knockout: the loser flies off, K.O., then 결과 보기, which '
        'cannot be pressed before it is up', (tester) async {
      var opened = 0;
      var asked = 0;
      final controller = BattleStageController();
      Future<void> pump(BattleStageState state) => _pump(
        tester,
        controller,
        state,
        onLeave: () => asked++,
        onShowResult: () => opened++,
      );
      await pump(_state(me: 85));
      await _wait(tester, 1000);
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: GameGrade.excellent,
          points: 15,
          combo: 1,
          knockout: true,
        ),
      );
      await pump(_state(phase: BattleStagePhase.ended, me: 100, end: _koEnd));
      await _wait(tester, 16);
      // The leave button goes at once.
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
      await _wait(tester, 1000);
      expect(find.text('K.O.'), findsNothing);
      await _wait(tester, 400);
      expect(find.text('K.O.'), findsOneWidget);
      expect(_pose(tester, BattleSide.me), BattlePose.win);
      expect(find.text('결과 보기'), findsNothing);
      // Where the button will be: nothing to press yet.
      await tester.tapAt(const Offset(180, 390 + 195));
      expect(opened, 0);
      await _wait(tester, 1000);
      expect(find.text('결과 보기'), findsOneWidget);
      await tester.tap(find.text('결과 보기'));
      expect(opened, 1);
      // The ending stays on the stage until the button is pressed.
      await _wait(tester, 5000);
      expect(find.text('K.O.'), findsOneWidget);
      expect(asked, 0);
    });

    testWidgets('time-up waiting for the server: TIME!, then nothing until '
        'the result comes, then WIN! and 결과 보기', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state(me: 30, op: 20));
      await _wait(tester, 500);
      const waiting = BattleStageEnd(
        kind: BattleEndKind.timeUp,
        decided: false,
      );
      await _pump(
        tester,
        controller,
        _state(phase: BattleStagePhase.ended, me: 30, op: 20, end: waiting),
      );
      await _wait(tester, 300);
      expect(find.text('TIME!'), findsOneWidget);
      await _wait(tester, 4000);
      expect(find.text('TIME!'), findsNothing);
      expect(find.text('WIN!'), findsNothing);
      expect(find.text('결과 보기'), findsNothing);
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.ended,
          me: 30,
          op: 20,
          end: const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.me,
          ),
        ),
      );
      await _wait(tester, 100);
      expect(find.text('WIN!'), findsOneWidget);
      expect(find.text('결과 보기'), findsNothing);
      await _wait(tester, 800);
      expect(find.text('결과 보기'), findsOneWidget);
    });

    testWidgets('the opponent leaving: they vanish, the band says so, I '
        'celebrate', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state(me: 60, op: 45));
      await _wait(tester, 500);
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.ended,
          me: 60,
          op: 45,
          end: const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
        ),
      );
      await _wait(tester, 600);
      expect(find.text('상대가 나가서 이겼어요'), findsOneWidget);
      expect(_pose(tester, BattleSide.me), BattlePose.win);
      expect(
        find.byWidgetPredicate(
          (w) => w is BattleFighter && w.side == BattleSide.opponent,
        ),
        findsNothing,
      );
    });
  });

  group('BattleArena, for a screen reader', () {
    testWidgets('a blow says the new score and valid count; my rejected rep '
        'its reason; an average rep its reason and points', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _wait(tester, 500);
      controller.rep(_myGood);
      await _pump(tester, controller, _state(me: 10, myReps: 1));
      await _wait(tester, 100);
      expect(said, ['내 점수 10점, 유효 1회']);

      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: null,
          reason: RejectReason.kneesDown,
        ),
      );
      await _wait(tester, 16);
      expect(said.last, '무릎을 바닥에서 떼요');

      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: GameGrade.average,
          points: 5,
          reason: RejectReason.insufficientDepth,
        ),
      );
      await _pump(tester, controller, _state(me: 15, myReps: 1));
      await _wait(tester, 100);
      expect(said.sublist(2), ['가슴을 더 내려요 · +5점', '내 점수 15점, 유효 1회']);

      controller.rep(
        const BattleStageEvent(
          side: BattleSide.opponent,
          grade: GameGrade.good,
          points: 10,
          combo: 1,
        ),
      );
      await _pump(
        tester,
        controller,
        _state(me: 15, myReps: 1, op: 10, opReps: 1),
      );
      await _wait(tester, 100);
      expect(said.last, '상대 점수 10점, 유효 1회');
    });

    testWidgets('the opponent\'s miss is not read out', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _wait(tester, 100);
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.opponent,
          grade: null,
          reason: RejectReason.tooFast,
        ),
      );
      await _wait(tester, 1000);
      expect(said, isEmpty);
    });

    testWidgets('the countdown and the start are read out', (tester) async {
      final controller = BattleStageController();
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.countdown,
          countdown: const Duration(seconds: 3),
        ),
      );
      await _wait(tester, 16);
      await _wait(tester, 1000);
      await _wait(tester, 1000);
      await _wait(tester, 1000);
      expect(said, ['3', '2', '1', '시작']);
    });

    testWidgets('fever, my reconnecting and the opponent\'s lost connection '
        'are read out when they begin', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _pump(tester, controller, _state(fever: true));
      await _pump(tester, controller, _state(fever: true, reconnecting: true));
      await _pump(tester, controller, _state(fever: true));
      await _pump(
        tester,
        controller,
        _state(fever: true, opponentDisconnected: true),
      );
      await _pump(
        tester,
        controller,
        _state(fever: true, opponentDisconnected: true),
      );
      expect(said, ['피버, 점수 2배', '재연결 중', '다시 연결됐어요', '상대 연결이 끊겼어요']);
    });

    testWidgets('the ending is read out: K.O., time-up and its verdict, a '
        'player leaving', (tester) async {
      final ko = BattleStageController();
      await _pump(tester, ko, _state());
      await _pump(
        tester,
        ko,
        _state(phase: BattleStagePhase.ended, me: 100, end: _koEnd),
      );
      await _wait(tester, 16);
      // The score that brought it is said once, as it changes.
      expect(said, ['내 점수 100점, 유효 0회', 'K.O. 이겼어요']);

      final time = BattleStageController();
      await _pump(tester, time, _state(op: 10));
      // A new battle on the same arena: only its ending counts here.
      said.clear();
      await _pump(
        tester,
        time,
        _state(
          phase: BattleStagePhase.ended,
          op: 10,
          end: const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.opponent,
          ),
        ),
      );
      await _wait(tester, 16);
      await _wait(tester, 1100);
      expect(said, ['시간 종료', '졌어요']);

      final left = BattleStageController();
      await _pump(tester, left, _state());
      said.clear();
      await _pump(
        tester,
        left,
        _state(
          phase: BattleStagePhase.ended,
          end: const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.opponent,
          ),
        ),
      );
      await _wait(tester, 16);
      expect(said, ['연결이 끊겨서 졌어요']);
    });
  });

  group('BattleArena, with reduced motion', () {
    testWidgets('a blow still changes the poses, but nothing shakes, flashes '
        'or breathes, and the reconnect arc holds still', (tester) async {
      final controller = BattleStageController();
      await _pump(
        tester,
        controller,
        _state(reconnecting: true),
        reducedMotion: true,
      );
      await _wait(tester, 1000);
      expect(_frame(tester).me.scaleY, 1);
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.opponent,
          grade: GameGrade.excellent,
          points: 15,
          combo: 1,
        ),
      );
      await _wait(tester, 100);
      final frame = _frame(tester);
      expect(frame.me.pose, BattlePose.hit);
      expect(frame.opponent.pose, BattlePose.attack);
      expect(frame.shakeX, 0);
      expect(frame.shakeY, 0);
      expect(frame.me.flash, isFalse);
      expect(
        tester.widget<BattleCameraArea>(find.byType(BattleCameraArea)).spin,
        0,
      );
    });
  });

  group('battleAnnouncement', () {
    final state = _state(me: 40, op: 25, myReps: 3, opReps: 2);

    test('a blow says nothing itself: the score is said as it changes', () {
      for (final side in BattleSide.values) {
        expect(
          battleAnnouncement(
            BattleStageCue(BattleCueKind.hit, side: side),
            state,
          ),
          isNull,
        );
      }
    });

    test('a change of the standing says the score and valid reps of each '
        'player once, the user first', () {
      expect(battleStandingAnnouncements(state, state), isEmpty);
      expect(
        battleStandingAnnouncements(
          state,
          _state(me: 50, op: 25, myReps: 4, opReps: 2),
        ),
        ['내 점수 50점, 유효 4회'],
      );
      // An average rep: points without a valid rep.
      expect(
        battleStandingAnnouncements(
          state,
          _state(me: 45, op: 25, myReps: 3, opReps: 2),
        ),
        ['내 점수 45점, 유효 3회'],
      );
      // A valid rep without points: an older server, or a snapshot.
      expect(
        battleStandingAnnouncements(
          state,
          _state(me: 40, op: 25, myReps: 3, opReps: 3),
        ),
        ['상대 점수 25점, 유효 3회'],
      );
      expect(
        battleStandingAnnouncements(
          state,
          _state(me: 41, op: 26, myReps: 3, opReps: 2),
        ),
        ['내 점수 41점, 유효 3회', '상대 점수 26점, 유효 2회'],
      );
    });

    test('says nothing for a miss', () {
      expect(
        battleAnnouncement(
          const BattleStageCue(BattleCueKind.miss, side: BattleSide.me),
          state,
        ),
        isNull,
      );
    });

    test('says every way a battle ends, from the user\'s side', () {
      String? say(BattleCueKind kind, BattleSide? side) =>
          battleAnnouncement(BattleStageCue(kind, side: side), state);
      expect(say(BattleCueKind.knockout, BattleSide.me), 'K.O. 이겼어요');
      expect(say(BattleCueKind.knockout, BattleSide.opponent), 'K.O. 졌어요');
      expect(say(BattleCueKind.timeUp, null), '시간 종료');
      expect(say(BattleCueKind.verdict, BattleSide.me), '이겼어요');
      expect(say(BattleCueKind.verdict, BattleSide.opponent), '졌어요');
      expect(say(BattleCueKind.verdict, null), '비겼어요');
      expect(say(BattleCueKind.playerLeft, BattleSide.me), '상대가 나가서 이겼어요');
      expect(say(BattleCueKind.playerLeft, BattleSide.opponent), '연결이 끊겨서 졌어요');
    });

    test('says the countdown and the start', () {
      expect(
        battleAnnouncement(
          const BattleStageCue(BattleCueKind.countdown, number: 2),
          state,
        ),
        '2',
      );
      expect(
        battleAnnouncement(const BattleStageCue(BattleCueKind.go), state),
        '시작',
      );
    });
  });

  group('BattleArena, things a mistake would break', () {
    testWidgets('the red edge takes no taps: I can still leave while I am '
        'about to lose', (tester) async {
      var asked = 0;
      await _pump(
        tester,
        BattleStageController(),
        _state(op: 65, danger: true),
        onLeave: () => asked++,
      );
      await _wait(tester, 16);
      expect(_dangerEdge(), findsOneWidget);
      await tester.tap(find.byIcon(Icons.logout_rounded));
      expect(asked, 1);
      await tester.tapAt(tester.getCenter(find.byKey(_camera)));
      expect(_cameraTaps, 1);
    });

    testWidgets('the reject sign takes no taps: what is under it still does', (
      tester,
    ) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _wait(tester, 100);
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: null,
          reason: RejectReason.kneesDown,
        ),
      );
      await _wait(tester, 400);
      // The label of the sign lies over the camera.
      final label = tester.getCenter(find.text('무릎 떼기'));
      expect(label.dy, greaterThan(390));
      await tester.tapAt(label);
      expect(_cameraTaps, 1);
    });

    testWidgets('the clock goes on when another arena takes the controller: '
        'an ending that has played stays played', (tester) async {
      final controller = BattleStageController();
      final ended = _state(phase: BattleStagePhase.ended, me: 100, end: _koEnd);
      await _pump(tester, controller, _state(me: 85));
      await _wait(tester, 5000);
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: GameGrade.excellent,
          points: 15,
          combo: 1,
          knockout: true,
        ),
      );
      await _pump(tester, controller, ended, onShowResult: () {});
      await _wait(tester, 3000);
      expect(find.text('결과 보기'), findsOneWidget);
      // The screen shows something else for a moment, then the arena again.
      await tester.pumpWidget(battleTestApp(const SizedBox()));
      await _wait(tester, 500);
      await _pump(tester, controller, ended, onShowResult: () {});
      await _wait(tester, 16);
      expect(find.text('결과 보기'), findsOneWidget);
      expect(find.text('K.O.'), findsOneWidget);
      expect(_pose(tester, BattleSide.me), BattlePose.win);
      expect(
        find.byWidgetPredicate(
          (w) => w is BattleFighter && w.side == BattleSide.opponent,
        ),
        findsNothing,
      );
    });

    testWidgets('fever, and the opponent\'s lost connection, are said when '
        'they begin, not when they end', (tester) async {
      final controller = BattleStageController();
      await _pump(
        tester,
        controller,
        _state(fever: true, opponentDisconnected: true),
      );
      said.clear();
      await _pump(tester, controller, _state(fever: true));
      await _pump(tester, controller, _state());
      expect(said, isEmpty);
    });

    testWidgets('the fever band and chip take the multiplier of the '
        'battle\'s rules', (tester) async {
      final controller = BattleStageController();
      BattleStageState triple({required bool fever}) => BattleStageState(
        phase: BattleStagePhase.playing,
        myName: 'A',
        opponentName: 'B',
        remaining: const Duration(seconds: 9),
        roundLength: const Duration(seconds: 30),
        fever: fever,
        feverMultiplier: 3,
      );
      await _pump(tester, controller, triple(fever: false));
      await _wait(tester, 100);
      await _pump(tester, controller, triple(fever: true));
      await _wait(tester, 400);
      // The band crossing the stage, and the chip beside the clock.
      expect(find.text('FEVER ×3'), findsNWidgets(2));
      expect(said, ['피버, 점수 3배']);
    });

    testWidgets('a round that starts without a countdown takes the setup\'s '
        'tags and band away', (tester) async {
      final controller = BattleStageController();
      await _pump(
        tester,
        controller,
        _state(phase: BattleStagePhase.setup, opReady: true),
      );
      await _wait(tester, 16);
      expect(find.text('자세 세팅 중'), findsOneWidget);
      await _pump(tester, controller, _state());
      await _wait(tester, 16);
      expect(find.text('자세 세팅 중'), findsNothing);
      expect(find.text('준비 완료'), findsNothing);
      expect(find.text('동점'), findsOneWidget);
    });

    testWidgets('while a time-up waits for its result I can still leave; '
        'once it is decided the button goes', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state(), onLeave: () {});
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.ended,
          end: const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false),
        ),
        onLeave: () {},
      );
      await _wait(tester, 16);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      await _pump(
        tester,
        controller,
        _state(
          phase: BattleStagePhase.ended,
          end: const BattleStageEnd(kind: BattleEndKind.timeUp),
        ),
        onLeave: () {},
      );
      await _wait(tester, 16);
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
    });

    testWidgets('a rejected rep that comes after the end is neither played '
        'nor read out', (tester) async {
      final controller = BattleStageController();
      await _pump(tester, controller, _state());
      await _pump(
        tester,
        controller,
        _state(phase: BattleStagePhase.ended, me: 100, end: _koEnd),
      );
      await _wait(tester, 16);
      said.clear();
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: null,
          reason: RejectReason.kneesDown,
        ),
      );
      await _wait(tester, 400);
      expect(said, isEmpty);
      expect(find.byType(BattleRejectSignView), findsNothing);
    });

    testWidgets('a knockout the screen reports just before its blow still '
        'shows the blow, and is read out once', (tester) async {
      final cues = <String>[];
      final controller = BattleStageController();
      await _pump(
        tester,
        controller,
        _state(me: 85),
        onCue: (c) => cues.add('$c'),
      );
      await _wait(tester, 1000);
      // The game's order: the result first, the rep a moment later.
      await _pump(
        tester,
        controller,
        _state(phase: BattleStagePhase.ended, me: 100, end: _koEnd),
        onCue: (c) => cues.add('$c'),
      );
      controller.rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: GameGrade.excellent,
          points: 15,
          combo: 1,
          knockout: true,
        ),
      );
      await _wait(tester, 40);
      expect(_pose(tester, BattleSide.me), BattlePose.attack);
      await _wait(tester, 100);
      expect(cues, ['knockout me excellent']);
      expect(said, ['내 점수 100점, 유효 0회', 'K.O. 이겼어요']);
    });
  });
}
