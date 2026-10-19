import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/config/server_config.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/screens/online_lobby_screen.dart';
import 'package:gymrats_app/screens/login_screen.dart';
import 'package:gymrats_app/screens/matching_screen.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/screens/online_battle_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/grid_background.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/user/avatar_store.dart';

import '../support/fakes.dart';
import '../support/flow_snapshot.dart';

class _Session extends OnlineBattleSession {
  _Session(Uri endpoint, String token, AvatarModel avatar)
    : super(endpoint: endpoint, accessToken: token, avatar: avatar);
  bool wasDisposed = false, left = false;
  @override
  Future<void> connect() async {
    playerId = 'me';
    connected = true;
    phase = OnlinePhase.queued;
    notifyListeners();
  }

  void found({int duration = 60000}) {
    opponent = const OnlinePlayer('other', '실제상대', AvatarModel.robot);
    durationMs = duration;
    phase = OnlinePhase.preparing;
    notifyListeners();
  }

  @override
  void ready(bool value) {
    if (value) {
      readyPlayers.add(playerId!);
    } else {
      readyPlayers.remove(playerId);
    }
    notifyListeners();
  }

  @override
  Future<void> leave() async {
    left = true;
    phase = OnlinePhase.cancelled;
  }

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}

class _SlowAvatarStore extends MemoryAvatarStore {
  final gate = Completer<AvatarModel>();
  @override
  Future<AvatarModel> read(int id) => gate.future;
}

class _ReadFailureStore extends MemoryAvatarStore {
  bool fail = true;
  @override
  Future<AvatarModel> read(int id) async {
    if (fail) throw StateError('test read failure');
    return AvatarModel.humanoid;
  }
}

Future<InMemoryAuthRepository> loggedIn() async {
  final auth = InMemoryAuthRepository()
    ..addAccount(loginId: 'human', nickname: '로그인사용자', password: 'password1');
  await auth.logIn(loginId: 'human', password: 'password1');
  return auth;
}

void main() {
  for (final phase in [OnlinePhase.preparing, OnlinePhase.playing]) {
    testWidgets('leaving $phase closes both battle and lobby to home', (
      tester,
    ) async {
      final auth = await loggedIn();
      late _Session session;
      final camera = FakeCameraService();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnlineLobbyScreen(
                      auth: auth,
                      createSession: (u, t, a) => session = _Session(u, t, a),
                      createCounter: () => RepCounterViewModel(
                        camera: camera,
                        estimator: FakePoseEstimator(),
                        roundLength: const Duration(days: 1),
                      ),
                    ),
                  ),
                ),
                child: const Text('홈 · 온라인 대결'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('홈 · 온라인 대결'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      session.found();
      await tester.pumpAndSettle();
      await tester.tap(find.text('자세 세팅 시작'));
      await tester.pumpAndSettle();
      session.phase = phase;
      session.notifyListeners();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ExitDialog), findsOneWidget);
      // Cancelling the dialog must preserve the ongoing match.
      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(OnlineBattleScreen), findsOneWidget);
      expect(session.left, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '게임 나가기'));
      await tester.pumpAndSettle();
      expect(find.text('홈 · 온라인 대결'), findsOneWidget);
      expect(find.byType(OnlineBattleScreen), findsNothing);
      expect(find.byType(OnlineLobbyScreen), findsNothing);
      expect(find.text('LIVE BATTLE'), findsNothing);
      expect(session.left, isTrue);
      expect(session.wasDisposed, isTrue);
      expect(camera.stopCount, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'avatar read error requires retry; never silently queues the wrong avatar',
    (tester) async {
      final auth = await loggedIn();
      final avatars = _ReadFailureStore();
      _Session? created;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(
            auth: auth,
            avatarStore: avatars,
            createSession: (u, t, a) => created = _Session(u, t, a),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, isNull);
      expect(find.text('프로필 아바타를 불러오지 못했어요. 다시 시도해주세요.'), findsOneWidget);
      avatars.fail = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(created!.avatar, AvatarModel.humanoid);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'expired login while avatar loads cannot create a stale matchmaking session',
    (tester) async {
      final auth = await loggedIn();
      final avatars = _SlowAvatarStore();
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(
            auth: auth,
            avatarStore: avatars,
            createSession: (u, t, a) {
              created++;
              return _Session(u, t, a);
            },
          ),
        ),
      );
      await auth.expireSession();
      await tester.pump();
      avatars.gate.complete(AvatarModel.robot);
      await tester.pumpAndSettle();
      expect(created, 0);
      expect(find.text('로그인이 필요해요.'), findsOneWidget);
    },
  );

  testWidgets(
    'live flow uses AI radar then real-player VS before camera setup',
    (tester) async {
      await prepareFlowSnapshotFonts(tester);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = await loggedIn();
      late _Session session;
      final camera = FakeCameraService();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: OnlineLobbyScreen(
            autoJoin: false,
            auth: auth,
            createSession: (u, t, a) => session = _Session(u, t, a),
            createCounter: () => RepCounterViewModel(
              camera: camera,
              estimator: FakePoseEstimator(),
              roundLength: const Duration(days: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('온라인 상대 찾기'));
      await tester.tap(find.text('온라인 상대 찾기'));
      await tester.pump();
      expect(find.byType(BattleSearchView), findsOneWidget);
      expect(find.byType(BattleSearchRadar), findsOneWidget);
      expect(find.byType(GridBackground), findsOneWidget);
      expect(find.text('실시간 상대를 찾는 중'), findsOneWidget);
      expect(find.text('기다리는 동안 자리를 준비해 두세요'), findsOneWidget);
      expect(camera.startCount, 0);
      await captureFlowSnapshot('online-search');
      session.found(duration: 30000);
      await tester.pump();
      expect(find.byType(VersusScreen), findsOneWidget);
      expect(find.text('MATCH FOUND'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('실제상대'), findsOneWidget);
      expect(find.text('로그인사용자'), findsOneWidget);
      expect(find.text('AI'), findsNothing);
      expect(find.text('푸쉬업 · 30초'), findsOneWidget);
      expect(find.text('경기 규칙'), findsOneWidget);
      expect(find.byType(OnlineBattleScreen), findsNothing);
      expect(camera.startCount, 0);
      await captureFlowSnapshot('online-versus');
      await tester.tap(find.text('자세 세팅 시작'));
      await tester.pumpAndSettle();
      expect(find.byType(OnlineBattleScreen), findsOneWidget);
      expect(find.byType(PoseSetupPanel), findsOneWidget);
      expect(find.byType(PoseSetupTopButtons), findsOneWidget);
      expect(find.text('실제상대 · 자세 세팅 중'), findsOneWidget);
      expect(camera.startCount, 1);
      session.ready(true);
      await tester.pump();
      expect(find.text('상대 준비를 기다리는 중…'), findsOneWidget);
      expect(find.text('준비 취소'), findsOneWidget);
      expect(session.phase, OnlinePhase.preparing);
      expect(session.startAtMs, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'back confirmation can cancel a match found while the dialog is open',
    (tester) async {
      final auth = await loggedIn();
      late _Session session;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: OnlineLobbyScreen(
            autoJoin: false,
            auth: auth,
            createSession: (u, t, a) => session = _Session(u, t, a),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('온라인 상대 찾기'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ExitDialog), findsOneWidget);
      session.found();
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(ExitDialog),
          matching: find.text('매칭 취소'),
        ),
      );
      await tester.pumpAndSettle();
      expect(session.left, isTrue);
      expect(session.wasDisposed, isTrue);
      expect(find.byType(VersusScreen), findsNothing);
      expect(find.text('온라인 상대 찾기'), findsOneWidget);
    },
  );

  testWidgets(
    'lobby uses signed-in JWT and fixed WSS; no second login, token or URL fields',
    (tester) async {
      final auth = await loggedIn();
      _Session? created;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(
            autoJoin: false,
            auth: auth,
            createSession: (url, token, avatar) =>
                created = _Session(url, token, avatar),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('로그인사용자 계정으로 참가합니다.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('새 테스트 계정'), findsNothing);
      await tester.tap(find.text('온라인 상대 찾기'));
      await tester.pump();
      expect(created!.endpoint.toString(), gymratsBattleUrl);
      expect(created!.accessToken, auth.session!.token);
      expect(created!.avatar, AvatarModel.astronaut);
      await tester.tap(find.text('매칭 취소'));
      await tester.pump();
      expect(created!.left, isTrue);
      expect(created!.wasDisposed, isTrue);
      expect(auth.session, isNotNull);
    },
  );

  testWidgets('signed-out user cannot create a battle session', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(
          auth: InMemoryAuthRepository(),
          createSession: (u, t, a) {
            calls++;
            return _Session(u, t, a);
          },
        ),
      ),
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '온라인 상대 찾기'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('로그인이 필요해요.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
    'session expiry closes queue and prevents joining with stale token',
    (tester) async {
      final auth = await loggedIn();
      late _Session created;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(
            autoJoin: false,
            auth: auth,
            createSession: (u, t, a) => created = _Session(u, t, a),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('온라인 상대 찾기'));
      await tester.pump();
      await auth.expireSession();
      await tester.pump();
      expect(created.wasDisposed, isTrue);
      expect(find.text('로그인이 필요해요.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '온라인 상대 찾기'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'home routes to lobby with the SAME repository; expiry returns to login',
    (tester) async {
      final auth = await loggedIn();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          auth: auth,
          createOnlineSession: (u, t, a) => _Session(u, t, a),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('온라인 1v1 대결');
      await tester.scrollUntilVisible(button, 180);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<OnlineLobbyScreen>(find.byType(OnlineLobbyScreen)).auth,
        same(auth),
      );
      expect(find.byType(TextField), findsNothing);
      await auth.expireSession();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnlineLobbyScreen), findsNothing);
    },
  );

  testWidgets(
    'entering online auto-matches with the stored profile avatar; no picker',
    (tester) async {
      final auth = await loggedIn();
      final avatars = MemoryAvatarStore();
      await avatars.write(auth.session!.account.id, AvatarModel.robot);
      _Session? created;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: OnlineLobbyScreen(
            auth: auth,
            avatarStore: avatars,
            createSession: (u, t, a) => created = _Session(u, t, a),
          ),
        ),
      );
      await tester.pump();
      expect(created, isNotNull);
      expect(created!.avatar, AvatarModel.robot);
      expect(created!.accessToken, auth.session!.token);
      expect(find.text('실시간 상대를 찾는 중'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<AvatarModel>), findsNothing);
      expect(find.text('이번 경기의 아바타'), findsNothing);
      // Profile changes never mutate an already queued match's frozen avatar.
      await avatars.write(auth.session!.account.id, AvatarModel.humanoid);
      await tester.pump();
      expect(created!.avatar, AvatarModel.robot);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
