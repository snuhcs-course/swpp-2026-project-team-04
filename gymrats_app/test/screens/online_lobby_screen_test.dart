import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/config/server_config.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/screens/online_lobby_screen.dart';
import 'package:gymrats_app/screens/login_screen.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';

import '../support/fakes.dart';

class _Session extends OnlineBattleSession {
  _Session(Uri endpoint, String token, AvatarModel avatar)
    : super(endpoint: endpoint, accessToken: token, avatar: avatar);
  bool wasDisposed = false, left = false;
  @override
  Future<void> connect() async {
    connected = true;
    phase = OnlinePhase.queued;
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

Future<InMemoryAuthRepository> loggedIn() async {
  final auth = InMemoryAuthRepository()
    ..addAccount(loginId: 'human', nickname: '로그인사용자', password: 'password1');
  await auth.logIn(loginId: 'human', password: 'password1');
  return auth;
}

void main() {
  testWidgets(
    'lobby uses signed-in JWT and fixed WSS; no second login, token or URL fields',
    (tester) async {
      final auth = await loggedIn();
      _Session? created;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(
            auth: auth,
            createSession: (url, token, avatar) =>
                created = _Session(url, token, avatar),
          ),
        ),
      );
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
            auth: auth,
            createSession: (u, t, a) => created = _Session(u, t, a),
          ),
        ),
      );
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
      await tester.pumpWidget(testApp(auth: auth));
      await tester.pumpAndSettle();
      final button = find.text('온라인 1v1 · 아바타 대결');
      await tester.scrollUntilVisible(button, 180);
      await tester.tap(button);
      await tester.pumpAndSettle();
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
}
