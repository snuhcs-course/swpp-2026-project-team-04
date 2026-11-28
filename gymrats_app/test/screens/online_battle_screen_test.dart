import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/models/setup_hint_short.dart';
import 'package:gymrats_app/screens/online_battle_screen.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/telemetry/telemetry_service.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/shared/battle_protocol.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/battle_arena.dart';
import 'package:gymrats_app/widgets/battle_camera_area.dart';
import 'package:gymrats_app/widgets/battle_camera_view.dart';

import '../services/pose/person_behind_test_support.dart';
import '../support/fakes.dart';
import '../support/placed_phone.dart';
import '../support/pose_fixtures.dart';

/// A session in preparation that records what the screen asks of it.
class _Session extends OnlineBattleSession {
  _Session({required this.now})
    : super(
        endpoint: Uri.parse('wss://example.com/ws/v1/battle'),
        accessToken: 'test-only',
        character: 'bear',
      ) {
    playerId = 'me';
    connected = true;
    phase = OnlinePhase.preparing;
    opponent = const OnlinePlayer('opponent', '상대사용자', 'seal');
  }
  final int Function() now;

  @override
  int get serverNow => now();

  var setupsOpened = 0;
  @override
  void setupOpened() {
    if (canReady) setupsOpened++;
    super.setupOpened();
  }

  final readyRequests = <bool>[];
  @override
  void ready(bool value) {
    if (!canReady) return;
    readyRequests.add(value);
    if (value) {
      readyPlayers.add(playerId!);
    } else {
      readyPlayers.remove(playerId);
    }
    notifyListeners();
  }

  @override
  Future<void> leave() async {}

  /// The server set the setup deadline [inMs] from now: both setups open.
  void setupCounts(int inMs) {
    setupPlayers = {'me', 'opponent'};
    setupDeadlineMs = serverNow + inMs;
    notifyListeners();
  }

  /// The server cancelled the match for [reason].
  void cancel(String reason) {
    phase = OnlinePhase.cancelled;
    result = {'reason': reason, 'ended_at_ms': serverNow};
    notifyListeners();
  }
}

void main() {
  late _Session session;
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late FakeRepJudge judge;
  late RepCounterViewModel counter;
  PoseFrame? streamPose;

  /// What the battle route closed with; unset while it is open.
  Object? closedWith;
  late bool closed;

  PoseFrame setupPose() {
    final overlays = find.byType(BattleGuideOverlay).evaluate();
    final share = overlays.isEmpty
        ? null
        : (overlays.single.widget as BattleGuideOverlay).share;
    return alignedPushUpSetupFrame(
      crop: share == null ? const Size(1, 1) : Size(share.width, share.height),
    );
  }

  Future<void> open(
    WidgetTester tester, {
    bool offerRematch = false,
    Telemetry? telemetry,
    String? friendId,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    session = _Session(
      now: () => tester.binding.clock.now().millisecondsSinceEpoch,
    )..friendId = friendId;
    addTearDown(session.dispose);
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    streamPose = null;
    closed = false;
    closedWith = null;
    final clockStart = tester.binding.clock.now();
    judge = FakeRepJudge();
    counter = RepCounterViewModel(
      camera: camera,
      estimator: estimator,
      judge: judge,
      phoneTilt: placedPhone(),
      enablePersonGuard: false,
      clock: () => tester.binding.clock.now().difference(clockStart),
      roundLength: const Duration(days: 1),
    );
    final navigator = GlobalKey<NavigatorState>();
    final app = MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.light,
      home: const Scaffold(body: Text('로비')),
    );
    await tester.pumpWidget(
      telemetry == null
          ? app
          : Provider<Telemetry>.value(value: telemetry, child: app),
    );
    unawaited(
      navigator.currentState!
          .push(
            MaterialPageRoute<Object?>(
              builder: (_) => OnlineBattleScreen(
                session: session,
                createCounter: () => counter,
                setupClock: () =>
                    tester.binding.clock.now().difference(clockStart),
                setupConfig: const SetupConfig(
                  readyDelay: Duration.zero,
                  dropDelay: Duration.zero,
                ),
                offerRematch: offerRematch,
              ),
            ),
          )
          .then((value) {
            closed = true;
            closedWith = value;
          }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Lets [ms] pass, a frame at a time, the camera still seeing the pose.
  Future<void> wait(WidgetTester tester, int ms) async {
    for (var left = ms; left > 0; left -= 50) {
      if (streamPose case final current? when camera.isStreaming) {
        estimator.frames.add(freshPose(current));
        camera.emit();
        await tester.pump();
      }
      await tester.pump(Duration(milliseconds: left < 50 ? left : 50));
    }
  }

  Future<void> pose(WidgetTester tester, {bool found = true}) async {
    streamPose = found ? setupPose() : emptyFrame();
    estimator.frames.add(streamPose);
    camera.emit();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  SetupHintShort? cueOf(WidgetTester tester) =>
      tester.widget<BattleCameraArea>(find.byType(BattleCameraArea)).setupCue;

  testWidgets(
    'a knee push-up shows MISS +0 and the correction in the online arena',
    (tester) async {
      await open(tester);
      session
        ..rules = battleRules
        ..phase = OnlinePhase.playing
        ..startAtMs = session.serverNow
        ..endAtMs = session.serverNow + 30000
        ..notifyListeners();
      await tester.pump();
      judge.closeRep(reason: RejectReason.kneesDown);
      await pose(tester);
      for (final ms in [150, 200, 200]) {
        await wait(tester, ms);
        expect(find.text('무릎을\n바닥에서\n떼요'), findsOneWidget);
        final label = tester.getRect(find.text('무릎을\n바닥에서\n떼요'));
        final screen = tester.getRect(find.byType(BattleArena));
        expect(label.left, greaterThanOrEqualTo(screen.left));
        expect(label.right, lessThanOrEqualTo(screen.right));
        expect(label.bottom, lessThanOrEqualTo(screen.bottom));
        expect(find.text('AVERAGE'), findsNothing);
        expect(find.text('MISS +0'), findsOneWidget);
        final banner = tester.getRect(find.text('MISS +0'));
        expect(screen.contains(banner.topLeft), isTrue);
        expect(screen.contains(banner.bottomRight), isTrue);
      }
      final arena = tester.widget<BattleArena>(find.byType(BattleArena));
      expect(arena.state.myScore, 0);
      expect(arena.state.myReps, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  group('the setup time (P12)', () {
    testWidgets(
      'the running setup camera tells the session its setup is open',
      (tester) async {
        await open(tester);
        await pose(tester, found: false);
        expect(session.setupsOpened, greaterThan(0));
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('no setup time, or more than 5 seconds of it: the cue says '
        'only what the pose needs', (tester) async {
      await open(tester);
      await pose(tester, found: false);
      final before = cueOf(tester)!;
      expect(before.first, isNot(contains('초 후')));
      session.setupCounts(8000);
      await pose(tester, found: false);
      expect(cueOf(tester)!.first, before.first);
      expect(cueOf(tester)!.message, isNot(contains('취소')));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the last 5 seconds count in an amber cue that still says '
        'what to fix', (tester) async {
      await open(tester);
      await pose(tester, found: false);
      final fix = cueOf(tester)!;
      session.setupCounts(4500);
      await pose(tester, found: false);
      final cue = cueOf(tester)!;
      expect(cue.first, '5초 후');
      expect(cue.second, '취소돼요');
      expect(cue.state, SetupCueState.notice);
      expect(cue.icon, fix.icon);
      expect(cue.message, '5초 안에 준비하지 않으면 경기가 취소돼요. ${fix.message}');
      // The band shows a new cue once the one shown has been held
      // (BattleCameraArea.cueHold), so each count shows up to that late.
      final hold = BattleCameraArea.cueHold.inMilliseconds;
      await wait(tester, hold + 100);
      expect(find.text('5초 후'), findsOneWidget);
      expect(find.text('취소돼요'), findsOneWidget);
      await wait(tester, hold);
      expect(cueOf(tester)!.first, '4초 후');
      expect(find.text('4초 후'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a held pose counts its own auto ready over the setup time', (
      tester,
    ) async {
      await open(tester);
      session.setupCounts(4500);
      await pose(tester);
      expect(cueOf(tester)!.message, contains('초 후 자동으로 준비해요'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an auto ready that would end after the setup time gives way '
        'to the cancel warning', (tester) async {
      await open(tester);
      session.setupCounts(2000);
      await pose(tester);
      final cue = cueOf(tester)!;
      expect(cue.first, '2초 후');
      expect(cue.second, '취소돼요');
      expect(cue.message, startsWith('2초 안에 준비하지 않으면 경기가 취소돼요.'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ready and waiting: the cue waits, and its sentence says the '
        'match ends unless the opponent gets ready', (tester) async {
      await open(tester);
      session.setupCounts(9000);
      await pose(tester);
      await wait(tester, 3100);
      expect(session.readyRequests, [true]);
      await wait(tester, 1500);
      final cue = cueOf(tester)!;
      expect(cue.first, '상대를');
      expect(cue.second, '기다려요');
      expect(cue.state, SetupCueState.match);
      expect(cue.message, '상대 준비를 기다리는 중… 5초 안에 상대가 준비하지 않으면 경기가 취소돼요.');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('once both setups are open the seconds left show over the '
        'camera, on amber in the last 5', (tester) async {
      await open(tester);
      await pose(tester, found: false);
      expect(find.bySemanticsLabel(RegExp('남은 시간')), findsNothing);
      session.setupCounts(8000);
      await pose(tester, found: false);
      expect(find.bySemanticsLabel('자세 세팅 남은 시간 8초'), findsOneWidget);
      expect(find.text('남은 시간: 8초'), findsOneWidget);
      Color fill() =>
          ((tester
                      .widget<DecoratedBox>(
                        find
                            .ancestor(
                              of: find.text(
                                '남은 시간: ${session.setupSecondsLeft}초',
                              ),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration)
                  as BoxDecoration)
              .color!;
      expect(fill(), AppColors.card);
      await wait(tester, 3100);
      expect(find.bySemanticsLabel('자세 세팅 남은 시간 5초'), findsOneWidget);
      expect(fill(), AppColors.warning);
      session.cancel(battleSetupTimeoutReason);
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('남은 시간')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (who, ready, message) in [
      ('only the user', {'me'}, '상대가 제한 시간 안에 준비하지 못해 경기가 취소됐어요.'),
      ('only the opponent', {'opponent'}, '내가 제한 시간 안에 준비하지 못해 경기가 취소됐어요.'),
      ('neither', <String>{}, '두 사람 모두 제한 시간 안에 준비하지 못해 경기가 취소됐어요.'),
      // Both ready as the deadline passed: the server cancelled first.
      ('both', {'me', 'opponent'}, '준비 시간이 지나 경기가 취소됐어요.'),
    ]) {
      for (final reason in [battleSetupTimeoutReason, 'ready_timeout']) {
        testWidgets('$reason with $who ready says who was not ready in time', (
          tester,
        ) async {
          await open(tester, offerRematch: true);
          session.readyPlayers = {...ready};
          session.cancel(reason);
          await tester.pump();
          expect(find.text('경기 취소'), findsOneWidget);
          expect(find.text(message), findsOneWidget);
          expect(find.textContaining(reason), findsNothing);
          expect(find.textContaining('승패'), findsNothing);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('the setup time ran out: the match is cancelled, and 다시 매칭 '
        'closes the screen to search again', (tester) async {
      await open(tester, offerRematch: true);
      await pose(tester);
      session.cancel(battleSetupTimeoutReason);
      await tester.pump();
      expect(find.byType(BattleArena), findsNothing);
      expect(find.text('경기 취소'), findsOneWidget);
      expect(find.text('두 사람 모두 제한 시간 안에 준비하지 못해 경기가 취소됐어요.'), findsOneWidget);
      expect(find.byType(AccentButton), findsOneWidget);
      expect(find.widgetWithText(AccentButton, '다시 매칭'), findsOneWidget);
      await tester.tap(find.text('다시 매칭'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(closedWith, true);
      expect(find.text('로비'), findsOneWidget);
    });

    testWidgets('홈으로 돌아가기 under 다시 매칭 closes without a search', (tester) async {
      await open(tester, offerRematch: true);
      session.cancel(battleSetupTimeoutReason);
      await tester.pump();
      await tester.tap(find.text('홈으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(closedWith, isNull);
    });

    for (final (reason, message) in [
      ('disconnected_before_start', '시작 전에 연결이 끊겨 경기가 취소됐어요.'),
      ('user_exit', '상대가 경기에서 나가 취소됐어요.'),
      ('player_left_before_start', '상대가 경기에서 나가 취소됐어요.'),
      ('a_reason_this_app_does_not_know', '경기가 시작되기 전에 취소됐어요.'),
    ]) {
      testWidgets('a cancel for $reason offers 다시 매칭 too and says why in '
          'words, not the code', (tester) async {
        await open(tester, offerRematch: true);
        session.cancel(reason);
        await tester.pump();
        expect(find.text(message), findsOneWidget);
        expect(find.textContaining(reason), findsNothing);
        expect(find.text('다시 매칭'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('an error shown earlier in the match is not given as the '
        'reason a cancel or void ended it', (tester) async {
      await open(tester, offerRematch: true);
      session.error = '온라인 요청 오류: RATE_LIMITED';
      session.cancel('a_reason_this_app_does_not_know');
      await tester.pump();
      expect(find.text('경기가 시작되기 전에 취소됐어요.'), findsOneWidget);
      expect(find.textContaining('RATE_LIMITED'), findsNothing);
      await tester.pumpWidget(const SizedBox());

      await open(tester);
      session
        ..error = '온라인 요청 오류: RATE_LIMITED'
        ..phase = OnlinePhase.voided
        ..result = {'reason': 'a_reason_this_app_does_not_know'}
        ..notifyListeners();
      await tester.pump();
      expect(find.text('이 경기는 무효가 됐어요.'), findsOneWidget);
      expect(find.textContaining('RATE_LIMITED'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a void battle or an opener without a search only goes home', (
      tester,
    ) async {
      await open(tester, offerRematch: true);
      session
        ..phase = OnlinePhase.voided
        ..result = {'reason': 'both_disconnected'}
        ..notifyListeners();
      await tester.pump();
      expect(find.text('경기 무효'), findsOneWidget);
      expect(find.text('두 사람의 연결이 모두 끊겨 이 경기는 무효가 됐어요.'), findsOneWidget);
      expect(find.text('다시 매칭'), findsNothing);
      expect(find.widgetWithText(AccentButton, '홈으로 돌아가기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await open(tester);
      session.cancel(battleSetupTimeoutReason);
      await tester.pump();
      expect(find.text('다시 매칭'), findsNothing);
      expect(find.widgetWithText(AccentButton, '홈으로 돌아가기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('세팅·종료 계측 (P17)', () {
    List<Map<String, Object?>> ends(Telemetry t) =>
        t.pending.where((e) => e['event'] == 'setup_finished').toList();

    testWidgets('opening the setup records its start for the main queue', (
      tester,
    ) async {
      final telemetry = Telemetry();
      await open(tester, telemetry: telemetry);
      final start = telemetry.pending.single;
      expect(start['event'], 'setup_started');
      expect(start['exercise'], 'push_up');
      expect(start['mode'], 'main');
    });

    testWidgets('a friend battle is mode friend', (tester) async {
      final telemetry = Telemetry();
      await open(tester, telemetry: telemetry, friendId: '7');
      expect(telemetry.pending.single['mode'], 'friend');
    });

    testWidgets('the setup time running out is timeout, with the limit and '
        'what the checker last asked for', (tester) async {
      final telemetry = Telemetry();
      await open(tester, telemetry: telemetry);
      await pose(tester, found: false);
      session.cancel('setup_timeout');
      await tester.pump();
      final end = ends(telemetry).single;
      expect(end['result'], 'timeout');
      expect(end['limit_ms'], 20000);
      expect(end['last_reason'], 'no_person');
      expect(end['attempt_id'], telemetry.pending.first['attempt_id']);
    });

    testWidgets('the 60 s ready time running out is a timeout too', (
      tester,
    ) async {
      final telemetry = Telemetry();
      await open(tester, telemetry: telemetry);
      session.cancel('ready_timeout');
      await tester.pump();
      expect(ends(telemetry).single['result'], 'timeout');
      expect(ends(telemetry).single['last_reason'], isNull);
    });

    testWidgets('the server setting the start is ready, and the end counts '
        'once', (tester) async {
      final telemetry = Telemetry();
      await open(tester, telemetry: telemetry);
      session
        ..phase = OnlinePhase.scheduled
        ..startAtMs = session.serverNow + 3000
        ..notifyListeners();
      await tester.pump();
      session.cancel('user_exit');
      await tester.pump();
      expect(ends(telemetry).single['result'], 'ready');
    });

    testWidgets('the opponent leaving before the start is cancelled', (
      tester,
    ) async {
      final telemetry = Telemetry();
      await open(tester, telemetry: telemetry);
      session.cancel('user_exit');
      await tester.pump();
      expect(ends(telemetry).single['result'], 'cancelled');
    });

    testWidgets('leaving the setup yourself is cancelled', (tester) async {
      final telemetry = Telemetry();
      await open(tester, telemetry: telemetry);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.text('게임 나가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(closed, isTrue);
      expect(ends(telemetry).single['result'], 'cancelled');
    });
  });
}
