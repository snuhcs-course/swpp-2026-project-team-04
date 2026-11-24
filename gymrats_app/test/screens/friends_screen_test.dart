import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/screens/friends_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/friends/friend_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/friends_viewmodel.dart';

import '../support/fakes.dart';

const _me = FriendPerson(id: 1, nickname: '쥐돌이', code: '쥐돌이#0001');
const _friend = FriendPerson(id: 2, nickname: '헬창', code: '헬창#0002');
const _other = FriendPerson(id: 3, nickname: '근육', code: '근육#0003');

class _Repo extends InMemoryFriendRepository {
  _Repo() : super(me: _me, people: const [_friend, _other]);

  bool fail = false;
  int fetches = 0;

  @override
  Future<FriendsOverview> fetchOverview() async {
    fetches++;
    if (fail) throw const ApiException(ApiErrorKind.network);
    return super.fetchOverview();
  }
}

void main() {
  late _Repo repo;
  late List<Object?> opened;

  setUp(() {
    repo = _Repo();
    opened = [];
  });

  Future<void> open(
    WidgetTester tester, {
    Future<ExerciseType?> Function(BuildContext, FriendPerson)? pickExercise,
    Duration refreshEvery = const Duration(hours: 1),
  }) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: FriendsScreen(
          createViewModel: () => FriendsViewModel(repository: repo),
          refreshEvery: refreshEvery,
          pickExercise: pickExercise,
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) {
            opened.add(settings.arguments);
            return const Scaffold(body: Text('lobby page'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows my code, the add field and an empty friends list', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('친구와의 대전'), findsOneWidget);
    expect(find.text('내 친구 코드'), findsOneWidget);
    expect(find.text('쥐돌이#0001'), findsOneWidget);
    expect(find.text('친구 코드로 추가'), findsOneWidget);
    expect(find.text('친구 0'), findsOneWidget);
    expect(find.textContaining('아직 친구가 없어요'), findsOneWidget);
    // No empty sections for requests or invites.
    expect(find.text('받은 대결 신청'), findsNothing);
    expect(find.text('받은 친구 요청'), findsNothing);
    expect(find.text('보낸 친구 요청'), findsNothing);
  });

  testWidgets('copy puts my code on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(tester);
    await tester.tap(find.byTooltip('친구 코드 복사'));
    await tester.pump();
    expect(copied, '쥐돌이#0001');
    expect(find.text('친구 코드를 복사했어요'), findsOneWidget);
  });

  testWidgets('a code sends a request, which shows as sent', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '헬창#0002');
    await tester.tap(find.text('요청'));
    await tester.pumpAndSettle();
    expect(find.text('친구 요청을 보냈어요.'), findsOneWidget);
    expect(find.text('보낸 친구 요청'), findsOneWidget);
    expect(find.text('수락을 기다리는 중'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('a duplicate request says so and keeps the code', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '헬창#0002');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '헬창#0002');
    await tester.tap(find.text('요청'));
    await tester.pumpAndSettle();
    expect(find.textContaining('이미 요청을 보냈어요'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '헬창#0002',
    );
  });

  testWidgets('a wrong code says what is wrong', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '헬창#0009');
    await tester.tap(find.text('요청'));
    await tester.pumpAndSettle();
    expect(find.textContaining('그런 친구 코드가 없어요'), findsOneWidget);
  });

  testWidgets('an incoming request is accepted into the friends list', (
    tester,
  ) async {
    repo.incoming.add(const FriendRequestItem(id: 10, person: _friend));
    await open(tester);
    expect(find.text('받은 친구 요청'), findsOneWidget);
    expect(find.text('헬창#0002'), findsOneWidget);
    await tester.tap(find.text('수락'));
    await tester.pumpAndSettle();
    expect(find.text('받은 친구 요청'), findsNothing);
    expect(find.text('친구 1'), findsOneWidget);
    expect(find.text('대결'), findsOneWidget);
  });

  testWidgets('an incoming request can be declined', (tester) async {
    repo.incoming.add(const FriendRequestItem(id: 10, person: _friend));
    await open(tester);
    await tester.tap(find.text('거절'));
    await tester.pumpAndSettle();
    expect(find.text('받은 친구 요청'), findsNothing);
    expect(find.text('친구 0'), findsOneWidget);
  });

  testWidgets('대결 asks for the exercise, then opens the waiting room', (
    tester,
  ) async {
    repo.friends.add(_friend);
    await open(tester);
    await tester.tap(find.text('대결'));
    await tester.pumpAndSettle();
    expect(find.text('헬창님과 무엇으로 대결할까요?'), findsOneWidget);
    await tester.tap(find.text('스쿼트'));
    await tester.pumpAndSettle();
    expect(find.text('lobby page'), findsOneWidget);
    final battle = opened.single! as FriendBattle;
    expect(battle.friend, _friend);
    expect(battle.exercise, ExerciseType.squat);
    expect(battle.inviting, isTrue);
  });

  testWidgets('closing the exercise sheet opens nothing', (tester) async {
    repo.friends.add(_friend);
    await open(tester, pickExercise: (_, _) async => null);
    await tester.tap(find.text('대결'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('an invite to me is accepted into its waiting room', (
    tester,
  ) async {
    repo.friends.add(_friend);
    final invite = repo.receiveInvite(_friend, ExerciseType.pushUp);
    await open(tester);
    expect(find.text('받은 대결 신청'), findsOneWidget);
    expect(find.text('푸쉬업 대결 · 1분 안에 수락'), findsOneWidget);
    await tester.tap(find.text('수락'));
    await tester.pumpAndSettle();
    final battle = opened.single! as FriendBattle;
    expect(battle.inviting, isFalse);
    expect(battle.accepted!.id, invite.id);
    expect(battle.friend, _friend);
    expect(battle.exercise, ExerciseType.pushUp);
    // Back from the battle, the lists read again: the invite is answered.
    Navigator.pop(tester.element(find.text('lobby page')));
    await tester.pumpAndSettle();
    expect(find.text('받은 대결 신청'), findsNothing);
  });

  testWidgets('an invite that expired says so and opens nothing', (
    tester,
  ) async {
    repo.friends.add(_friend);
    final invite = repo.receiveInvite(_friend, ExerciseType.pushUp);
    await open(tester);
    repo.answer(invite.id, InviteStatus.cancelled);
    await tester.tap(find.text('수락'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('이미 끝난 대결 신청이에요.'), findsOneWidget);
  });

  testWidgets('an invite can be declined', (tester) async {
    repo.receiveInvite(_friend, ExerciseType.pushUp);
    await open(tester);
    await tester.tap(find.text('거절'));
    await tester.pumpAndSettle();
    expect(find.text('받은 대결 신청'), findsNothing);
    expect(repo.invites.single.status, InviteStatus.declined);
  });

  testWidgets('friends are listed by nickname, each with 대결', (tester) async {
    repo.friends.addAll(const [_friend, _other]);
    await open(tester);
    expect(find.text('친구 2'), findsOneWidget);
    expect(find.text('대결'), findsNWidgets(2));
    final first = tester.getTopLeft(find.text('근육')).dy;
    final second = tester.getTopLeft(find.text('헬창')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('a failed load offers 다시 시도', (tester) async {
    repo.fail = true;
    await open(tester);
    expect(find.textContaining('서버에 연결하지 못했어요'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('쥐돌이#0001'), findsOneWidget);
  });

  testWidgets('the lists read again while open, so a new invite shows', (
    tester,
  ) async {
    await open(tester, refreshEvery: const Duration(seconds: 5));
    expect(find.text('받은 대결 신청'), findsNothing);
    repo.friends.add(_friend);
    repo.receiveInvite(_friend, ExerciseType.squat);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('받은 대결 신청'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final after = repo.fetches;
    await tester.pump(const Duration(seconds: 10));
    expect(repo.fetches, after);
  });

  group('invite alert above every page', () {
    late FriendInviteAlertViewModel alert;
    late FriendInviteRouteWatch routes;
    late GlobalKey<NavigatorState> navigator;

    Future<void> openApp(WidgetTester tester) async {
      alert = FriendInviteAlertViewModel(
        repository: repo,
        pollEvery: const Duration(seconds: 5),
      );
      routes = FriendInviteRouteWatch();
      navigator = GlobalKey<NavigatorState>();
      addTearDown(alert.dispose);
      addTearDown(routes.dispose);
      Widget page(String name) => Scaffold(body: Center(child: Text(name)));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          navigatorKey: navigator,
          navigatorObservers: [routes],
          builder: (context, child) => FriendInviteOverlay(
            viewModel: alert,
            routes: routes,
            navigator: navigator,
            child: child!,
          ),
          home: page('home page'),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) {
              opened.add(settings.arguments);
              return page('${settings.name}');
            },
          ),
        ),
      );
      alert.setSignedIn(true);
      await tester.pumpAndSettle();
    }

    void push(String name) =>
        unawaited(navigator.currentState!.pushNamed(name));

    testWidgets("a friend's invite shows on top of the page, 거절 and 수락", (
      tester,
    ) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      expect(find.text('헬창님이 스쿼트 대결을 신청했어요'), findsOneWidget);
      expect(find.text('거절'), findsOneWidget);
      expect(find.text('수락'), findsOneWidget);
      expect(find.text('home page'), findsOneWidget);
      // At the top of the screen.
      expect(
        tester.getTopLeft(find.text('헬창님이 스쿼트 대결을 신청했어요')).dy,
        lessThan(200),
      );
    });

    testWidgets('an invite that comes later shows on the next read', (
      tester,
    ) async {
      repo.friends.add(_friend);
      await openApp(tester);
      expect(find.textContaining('대결을 신청했어요'), findsNothing);
      repo.receiveInvite(_friend, ExerciseType.pushUp);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('헬창님이 푸쉬업 대결을 신청했어요'), findsOneWidget);
    });

    testWidgets('수락 opens the waiting room with the accepted invite', (
      tester,
    ) async {
      repo.friends.add(_friend);
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      await tester.tap(find.text('수락'));
      await tester.pumpAndSettle();
      expect(find.text(GymRatsApp.onlineBattleRoute), findsOneWidget);
      final battle = opened.single! as FriendBattle;
      expect(battle.accepted!.id, sent.id);
      expect(battle.friend, _friend);
      expect(battle.exercise, ExerciseType.squat);
      expect(find.textContaining('대결을 신청했어요'), findsNothing);
    });

    testWidgets('거절 declines it and the alert goes', (tester) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      await tester.tap(find.text('거절'));
      await tester.pumpAndSettle();
      expect(find.textContaining('대결을 신청했어요'), findsNothing);
      expect(repo.invites.single.status, InviteStatus.declined);
      expect(opened, isEmpty);
    });

    testWidgets('an invite that ran out says so for a moment', (tester) async {
      repo.friends.add(_friend);
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      repo.answer(sent.id, InviteStatus.cancelled);
      await tester.tap(find.text('수락'));
      await tester.pump();
      expect(find.text('이미 끝난 대결 신청이에요.'), findsOneWidget);
      expect(opened, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('이미 끝난 대결 신청이에요.'), findsNothing);
    });

    for (final route in [
      ...FriendInviteRouteWatch.busyRoutes,
      GymRatsApp.friendsRoute,
    ]) {
      testWidgets('hidden while $route is open, back after it', (tester) async {
        repo.friends.add(_friend);
        repo.receiveInvite(_friend, ExerciseType.squat);
        await openApp(tester);
        push(route);
        await tester.pumpAndSettle();
        expect(find.textContaining('대결을 신청했어요'), findsNothing);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.textContaining('대결을 신청했어요'), findsOneWidget);
      });
    }

    testWidgets('a page above a battle still hides it; other pages do not', (
      tester,
    ) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      push(GymRatsApp.historyRoute);
      await tester.pumpAndSettle();
      expect(find.textContaining('대결을 신청했어요'), findsOneWidget);
      push(GymRatsApp.onlineBattleRoute);
      await tester.pumpAndSettle();
      push('/unnamed-battle-page');
      await tester.pumpAndSettle();
      expect(find.textContaining('대결을 신청했어요'), findsNothing);
      // The friends page under another page does not hide it.
      navigator.currentState!.popUntil((r) => r.isFirst);
      push(GymRatsApp.friendsRoute);
      push(GymRatsApp.historyRoute);
      await tester.pumpAndSettle();
      expect(find.textContaining('대결을 신청했어요'), findsOneWidget);
    });

    testWidgets('a sheet over the friends page keeps it hidden', (
      tester,
    ) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      push(GymRatsApp.friendsRoute);
      await tester.pumpAndSettle();
      // An unnamed route on top, as the friends page's exercise sheet.
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('sheet')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('대결을 신청했어요'), findsNothing);
    });

    testWidgets('the alert stops reading once the overlay is gone', (
      tester,
    ) async {
      repo.friends.add(_friend);
      await openApp(tester);
      await tester.pumpWidget(const SizedBox());
      final reads = repo.fetches;
      await tester.pump(const Duration(seconds: 20));
      expect(repo.fetches, reads);
      expect(alert.visible, isFalse);
    });

    testWidgets('a replaced route is followed', (tester) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      push(GymRatsApp.historyRoute);
      await tester.pumpAndSettle();
      unawaited(
        navigator.currentState!.pushReplacementNamed(GymRatsApp.battleRoute),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('대결을 신청했어요'), findsNothing);
      unawaited(
        navigator.currentState!.pushReplacementNamed(GymRatsApp.historyRoute),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('대결을 신청했어요'), findsOneWidget);
    });

    testWidgets('hidden while the app is in the background', (tester) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(find.textContaining('대결을 신청했어요'), findsNothing);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('대결을 신청했어요'), findsOneWidget);
    });

    testWidgets('the app shows it on home while signed in', (tester) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.pushUp);
      await tester.pumpWidget(
        GymRatsApp(
          authRepository: signedInAuth(),
          userRepository: FakeUserRepository(),
          friendRepository: repo,
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('헬창님이 푸쉬업 대결을 신청했어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
