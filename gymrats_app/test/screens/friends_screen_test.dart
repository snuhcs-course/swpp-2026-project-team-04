import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/friends_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/friends/friend_repository.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/friends_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/friend_invite_parts.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

const _me = FriendPerson(id: 1, nickname: '쥐돌이', code: '쥐돌이#0001');
const _friend = FriendPerson(id: 2, nickname: '헬창', code: '헬창#0002');
const _other = FriendPerson(id: 3, nickname: '근육', code: '근육#0003');

class _Repo extends InMemoryFriendRepository {
  _Repo({super.now}) : super(me: _me, people: const [_friend, _other]);

  bool fail = false;
  int fetches = 0;

  /// While set, accepting an invite waits for it.
  Completer<void>? holdAccept;

  @override
  Future<BattleInvite> acceptInvite(int inviteId) async {
    await holdAccept?.future;
    return super.acceptInvite(inviteId);
  }

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
    // A11: the invite cards' and the alert's characters idle for as long as
    // they show, and a page cannot settle under a running ticker; reduced
    // motion holds them still. The A11 tests at the end turn motion back on
    // where they check it.
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  Future<void> open(
    WidgetTester tester, {
    Future<ExerciseType?> Function(BuildContext, FriendPerson)? pickExercise,
    Duration refreshEvery = const Duration(hours: 1),
    UserRepository? users,
  }) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      // The app's profile source, for the exercise sheet's bests (A11).
      Provider<UserRepository>.value(
        value: users ?? FakeUserRepository(),
        child: MaterialApp(
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
    expect(find.text('친구 추가'), findsOneWidget);
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

  testWidgets('대결 asks for the exercise on the online battle\'s sheet, then '
      'opens the waiting room (A11 spec 1)', (tester) async {
    repo.friends.add(_friend);
    await open(tester);
    await tester.tap(find.text('대결'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsOneWidget);
    expect(find.text('헬창님과 친구 1v1 · 30초'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ExerciseSheet),
        matching: find.text('스쿼트'),
      ),
    );
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
    // A11: a card with the exercise on its pill.
    expect(find.byType(FriendInviteCard), findsOneWidget);
    expect(find.text('푸쉬업 대결'), findsOneWidget);
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

  testWidgets('another battle opened while accepting: no second lobby, and '
      'the accept is taken back', (tester) async {
    repo.friends.addAll([_friend, _other]);
    final invite = repo.receiveInvite(_friend, ExerciseType.pushUp);
    await open(tester, pickExercise: (_, _) async => ExerciseType.squat);
    repo.holdAccept = Completer<void>();
    await tester.tap(find.text('수락'));
    await tester.pump();
    // Meanwhile I challenge another friend: that lobby opens.
    await tester.tap(find.text('대결').last);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect((opened.single! as FriendBattle).inviting, isTrue);
    repo.holdAccept!.complete();
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect((await repo.fetchInvite(invite.id)).status, InviteStatus.cancelled);
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
      // A11: "헬창님이" over "스쿼트 대결을 신청했어요".
      expect(find.text('헬창님이'), findsOneWidget);
      expect(find.text('스쿼트 대결을 신청했어요'), findsOneWidget);
      expect(find.text('거절'), findsOneWidget);
      expect(find.text('수락'), findsOneWidget);
      expect(find.text('home page'), findsOneWidget);
      // At the top of the screen.
      expect(tester.getTopLeft(find.text('헬창님이')).dy, lessThan(200));
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
      expect(find.text('푸쉬업 대결을 신청했어요'), findsOneWidget);
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

    testWidgets('signed out while 수락 is on its way: no waiting room opens', (
      tester,
    ) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      repo.holdAccept = Completer<void>();
      await openApp(tester);
      await tester.tap(find.text('수락'));
      await tester.pump();
      alert.setSignedIn(false);
      repo.holdAccept!.complete();
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.text('home page'), findsOneWidget);
      expect(repo.invites.single.status, InviteStatus.cancelled);
    });

    testWidgets('a battle opened while 수락 is on its way: no friend waiting '
        'room over it', (tester) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      repo.holdAccept = Completer<void>();
      await openApp(tester);
      await tester.tap(find.text('수락'));
      await tester.pump();
      push(GymRatsApp.onlineBattleRoute);
      await tester.pumpAndSettle();
      repo.holdAccept!.complete();
      await tester.pumpAndSettle();
      expect(opened.whereType<FriendBattle>(), isEmpty);
      expect(repo.invites.single.status, InviteStatus.cancelled);
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
      // A hidden app draws no frames, so the alert's own state is what
      // counts here: it is off and stops reading.
      expect(alert.visible, isFalse);
      final idle = repo.fetches;
      await tester.pump(const Duration(seconds: 20));
      expect(repo.fetches, idle);
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

    testWidgets('the notification shade (inactive) does not hide it', (
      tester,
    ) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openApp(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(alert.visible, isTrue);
      expect(find.textContaining('대결을 신청했어요'), findsOneWidget);
      // Still in front: it keeps reading.
      final reads = repo.fetches;
      await tester.pump(const Duration(seconds: 20));
      expect(repo.fetches, greaterThan(reads));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
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
      expect(find.text('헬창님이'), findsOneWidget);
      expect(find.text('푸쉬업 대결을 신청했어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('A11: the redesigned page and alert', () {
    late DateTime clock;

    /// How far the phone's clock runs ahead of the server's ([clock]).
    late Duration ahead;

    setUp(() {
      clock = DateTime(2026, 11, 27, 12);
      ahead = Duration.zero;
      repo = _Repo(now: () => clock);
    });

    /// The page on [clock], as [open], at [size].
    Future<FakeUserRepository> openAt(
      WidgetTester tester, {
      Size size = const Size(412, 1400),
      FakeUserRepository? users,
      Object? argument,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = users ?? FakeUserRepository();
      await tester.pumpWidget(
        Provider<UserRepository>.value(
          value: source,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: RouteSettings(
                        name: GymRatsApp.friendsRoute,
                        arguments: argument,
                      ),
                      builder: (_) => FriendsScreen(
                        createViewModel: () => FriendsViewModel(
                          repository: repo,
                          now: () => clock.add(ahead),
                        ),
                        refreshEvery: const Duration(hours: 1),
                      ),
                    ),
                  ),
                  child: const Text('below'),
                ),
              ),
            ),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) {
                opened.add(settings.arguments);
                return const Scaffold(body: Text('lobby page'));
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('below'));
      await tester.pumpAndSettle();
      return source;
    }

    testWidgets('five groups in order: invites, requests to me, friends, '
        'requests I sent, then my code and the code field (spec 4)', (
      tester,
    ) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      repo.incoming.add(const FriendRequestItem(id: 40, person: _other));
      repo.outgoing.add(
        const FriendRequestItem(
          id: 41,
          person: FriendPerson(id: 9, nickname: '철봉', code: '철봉#0009'),
        ),
      );
      await openAt(tester);
      final tops = [
        for (final label in [
          '받은 대결 신청',
          '받은 친구 요청',
          '친구 1',
          '보낸 친구 요청',
          '친구 추가',
          '내 친구 코드',
        ])
          tester.getTopLeft(find.text(label)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(tops.length));
      // A label is 20 under what is above it and 8 over its own card.
      final card = tester.getRect(find.byType(FriendInviteCard));
      final label = tester.getRect(find.text('받은 친구 요청'));
      expect(label.top, card.bottom + AppSpacing.s20);
    });

    testWidgets('an invite card: the inviter\'s character on the pink panel, '
        'the nickname, 1:00, the exercise pill, a full bar and both buttons '
        '(spec 4)', (tester) async {
      repo.receiveInvite(_friend, ExerciseType.squat, character: 'bear');
      await openAt(tester);
      final card = find.byType(FriendInviteCard);
      Finder inCard(Finder of) => find.descendant(of: card, matching: of);
      final figure = tester.widget<CharacterIdleFigure>(
        inCard(find.byType(CharacterIdleFigure)).first,
      );
      expect((figure.characterId, figure.side), ('bear', BattleSide.opponent));
      expect(inCard(find.text('헬창')), findsOneWidget);
      expect(inCard(find.text('1:00')), findsOneWidget);
      expect(inCard(find.text('스쿼트 대결')), findsOneWidget);
      expect(
        tester
            .widget<FriendTimeBar>(inCard(find.byType(FriendTimeBar)))
            .fraction,
        1,
      );
      expect(inCard(find.text('거절')), findsOneWidget);
      expect(inCard(find.text('수락')), findsOneWidget);
      expect(
        tester.getSize(inCard(find.byType(FriendInvitePanel))).width,
        FriendInviteCard.panelWidth,
      );
      final frame = tester.widget<Container>(
        find.descendant(of: card, matching: find.byType(Container)).first,
      );
      final decoration = frame.decoration! as BoxDecoration;
      expect(decoration.border, Border.all(color: AppColors.ink, width: 2));
      expect(decoration.borderRadius, BorderRadius.circular(18));
    });

    testWidgets('the time left counts down from expires_at every second, and '
        'at 0 the card leaves the page (spec 4, 9.3)', (tester) async {
      repo.receiveInvite(_friend, ExerciseType.pushUp);
      await openAt(tester);
      clock = clock.add(const Duration(seconds: 17));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:43'), findsOneWidget);
      expect(
        tester.widget<FriendTimeBar>(find.byType(FriendTimeBar)).seconds,
        43,
      );
      clock = clock.add(const Duration(seconds: 43));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FriendInviteCard), findsNothing);
      expect(find.text('받은 대결 신청'), findsNothing);
    });

    testWidgets('a phone clock over a minute ahead: the invite shows 0:00 and '
        'an empty bar until the server stops listing it (user, 2026-11-27)', (
      tester,
    ) async {
      ahead = const Duration(seconds: 61);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openAt(tester);
      expect(find.byType(FriendInviteCard), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(
        tester.widget<FriendTimeBar>(find.byType(FriendTimeBar)).fraction,
        0,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(FriendInviteCard), findsOneWidget);
    });

    testWidgets('no character, or one that cannot be picked: GYM마우스 (spec '
        '7)', (tester) async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      repo.receiveInvite(_other, ExerciseType.squat, character: 'dragon');
      await openAt(tester);
      expect(
        tester
            .widgetList<CharacterIdleFigure>(find.byType(CharacterIdleFigure))
            .map((f) => f.characterId)
            .toSet(),
        {'mouse'},
      );
      expect(find.byType(FriendInviteCard), findsNWidgets(2));
    });

    testWidgets('while an answer is on its way both buttons are off', (
      tester,
    ) async {
      repo.friends.add(_friend);
      repo.receiveInvite(_friend, ExerciseType.squat);
      await openAt(tester);
      repo.holdAccept = Completer<void>();
      await tester.tap(find.text('수락'));
      await tester.pump();
      for (final button in tester.widgetList<OutlinedButton>(
        find.descendant(
          of: find.byType(FriendAnswerButtons),
          matching: find.byType(OutlinedButton),
        ),
      )) {
        expect(button.onPressed, isNull);
      }
      repo.holdAccept!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a friend row: at least 64 high, the nickname in Do Hyeon 21 '
        'over the code, and a lime 대결 with an arrow (spec 4)', (tester) async {
      repo.friends.add(_friend);
      await openAt(tester);
      final name = tester.widget<Text>(find.text('헬창'));
      expect(name.style!.fontSize, 21);
      expect(name.style!.fontFamily, AppFonts.display);
      final code = tester.widget<Text>(find.text('헬창#0002'));
      expect(code.style!.fontFamily, AppFonts.number);
      expect(code.style!.color, AppColors.textMuted);
      final button = find.ancestor(
        of: find.text('대결'),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(40));
      final style = tester.widget<OutlinedButton>(button).style!;
      expect(style.backgroundColor!.resolve({}), AppColors.accent);
      expect(
        find.descendant(of: button, matching: find.byType(ArcadeGlyphIcon)),
        findsOneWidget,
      );
      final row = tester.getRect(find.text('헬창'));
      expect(
        tester.getRect(find.text('헬창#0002')).top,
        greaterThanOrEqualTo(row.bottom),
      );
    });

    testWidgets('the sheet shows the bests of the profile 게임 시작 passed, '
        'with no read; back from a battle, the profile is read again', (
      tester,
    ) async {
      repo.friends.add(_friend);
      final users = FakeUserRepository();
      await openAt(
        tester,
        users: users,
        argument: const UserProfile(
          name: '우현',
          bests: {ExerciseType.pushUp: PersonalBest(reps: 24, score: 240)},
        ),
      );
      expect(users.fetchCount, 0);
      await tester.tap(find.text('대결'));
      await tester.pumpAndSettle();
      expect(find.text('개인 최고 240점', findRichText: true), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ExerciseSheet),
          matching: find.text('푸쉬업'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('lobby page'), findsOneWidget);
      users.profile = const UserProfile(
        name: '우현',
        bests: {ExerciseType.pushUp: PersonalBest(reps: 30, score: 300)},
      );
      Navigator.pop(tester.element(find.text('lobby page')));
      await tester.pumpAndSettle();
      expect(users.fetchCount, 1);
      await tester.tap(find.text('대결'));
      await tester.pumpAndSettle();
      expect(find.text('개인 최고 300점', findRichText: true), findsOneWidget);
    });

    testWidgets('without the route\'s profile the page reads one; a failed '
        'read after a battle keeps it', (tester) async {
      repo.friends.add(_friend);
      final users = FakeUserRepository()
        ..profile = const UserProfile(
          name: '우현',
          bests: {ExerciseType.squat: PersonalBest(reps: 31)},
        );
      await openAt(tester, users: users);
      expect(users.fetchCount, 1);
      await tester.tap(find.text('대결'));
      await tester.pumpAndSettle();
      expect(find.text('개인 최고 31회', findRichText: true), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ExerciseSheet),
          matching: find.text('스쿼트'),
        ),
      );
      await tester.pumpAndSettle();
      users.error = Exception('offline');
      Navigator.pop(tester.element(find.text('lobby page')));
      await tester.pumpAndSettle();
      expect(users.fetchCount, 2);
      await tester.tap(find.text('대결'));
      await tester.pumpAndSettle();
      expect(find.text('개인 최고 31회', findRichText: true), findsOneWidget);
    });

    testWidgets('no profile at all: 대결 says why and opens nothing', (
      tester,
    ) async {
      repo.friends.add(_friend);
      final users = FakeUserRepository()
        ..error = const ApiException(ApiErrorKind.network);
      await openAt(tester, users: users);
      await tester.tap(find.text('대결'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseSheet), findsNothing);
      expect(opened, isEmpty);
      expect(find.textContaining('서버에 연결하지 못했어요'), findsOneWidget);
    });

    testWidgets('my code: 18 bold, its tag in the number font', (tester) async {
      await openAt(tester);
      final code = tester.widget<Text>(find.text('쥐돌이#0001'));
      expect(code.style!.fontSize, 18);
      expect(code.style!.fontWeight, FontWeight.w700);
      final spans = (code.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect([for (final s in spans) s.text], ['쥐돌이', '#0001']);
      expect(spans.last.style!.fontFamily, AppFonts.number);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
        '닉네임#0000',
      );
    });

    testWidgets('the code field keeps its name for a screen reader, typed '
        'into or not', (tester) async {
      final semantics = tester.ensureSemantics();
      await openAt(tester);
      final empty = tester.getSemantics(find.byType(TextField));
      expect(empty, isSemantics(isTextField: true));
      expect(empty.label, startsWith('친구 코드로 추가'));
      await tester.enterText(find.byType(TextField), '헬창#0002');
      await tester.pump();
      final typed = tester.getSemantics(find.byType(TextField));
      expect(typed, isSemantics(isTextField: true));
      expect(typed.label, startsWith('친구 코드로 추가'));
      semantics.dispose();
    });

    testWidgets('the invite card\'s character idles; with reduced motion it '
        'stands still (spec 4)', (tester) async {
      repo.receiveInvite(_friend, ExerciseType.squat, character: 'seal');
      await openAt(tester);
      expect(tester.hasRunningAnimations, isFalse);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (size, scale) in const [
      (Size(360, 780), 1.3),
      (Size(320, 640), 1.0),
    ]) {
      testWidgets('nothing overflows at ${size.width.toInt()} x '
          '${size.height.toInt()} with $scale times the text (spec 9.10)', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const long = FriendPerson(
          id: 8,
          nickname: '가나다라마바사아자차카타',
          code: '가나다라마바사아자차카타#0008',
        );
        repo.friends.addAll(const [_friend, long]);
        repo.receiveInvite(long, ExerciseType.squat, character: 'kangaroo');
        repo.incoming.add(const FriendRequestItem(id: 40, person: _other));
        await openAt(tester, size: size);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('요청').hitTestable(), findsOneWidget);
      });
    }

    group('the alert', () {
      late FriendInviteAlertViewModel alert;

      Future<void> openAlert(WidgetTester tester, {Size? size}) async {
        if (size != null) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
        }
        alert = FriendInviteAlertViewModel(
          repository: repo,
          pollEvery: const Duration(seconds: 5),
          now: () => clock.add(ahead),
        );
        final routes = FriendInviteRouteWatch();
        final navigator = GlobalKey<NavigatorState>();
        addTearDown(alert.dispose);
        addTearDown(routes.dispose);
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
            home: const Scaffold(body: Center(child: Text('home page'))),
          ),
        );
        alert.setSignedIn(true);
        await tester.pumpAndSettle();
      }

      testWidgets('the inviter\'s character, "{nickname}님이", the exercise '
          'line, the time left, its bar and both buttons (spec 6)', (
        tester,
      ) async {
        repo.receiveInvite(_friend, ExerciseType.squat, character: 'kangaroo');
        await openAlert(tester);
        final card = find.byType(FriendInviteAlertCard);
        Finder inCard(Finder of) => find.descendant(of: card, matching: of);
        final figure = tester.widget<CharacterIdleFigure>(
          inCard(find.byType(CharacterIdleFigure)).first,
        );
        expect(
          (figure.characterId, figure.side),
          ('kangaroo', BattleSide.opponent),
        );
        expect(inCard(find.text('헬창님이')), findsOneWidget);
        expect(inCard(find.text('스쿼트 대결을 신청했어요')), findsOneWidget);
        expect(inCard(find.text('1:00')), findsOneWidget);
        expect(inCard(find.byType(FriendTimeBar)), findsOneWidget);
        expect(inCard(find.text('거절')), findsOneWidget);
        expect(inCard(find.text('수락')), findsOneWidget);
        // The bar runs along the card's whole bottom.
        final bar = tester.getRect(inCard(find.byType(FriendTimeBar)));
        final frame = tester.getRect(card);
        expect(bar.height, 5);
        expect(bar.bottom, closeTo(frame.bottom - 2, 0.01));
        expect(bar.width, closeTo(frame.width - 4, 0.01));
        expect(
          tester.getSize(inCard(find.byType(FriendInvitePanel))).width,
          FriendInviteAlertCard.panelWidth,
        );
      });

      testWidgets('its frame: a 2 ink edge, 20 corners and a hard ink shadow, '
          'no lift; the error card has the same frame', (tester) async {
        final sent = repo.receiveInvite(_friend, ExerciseType.squat);
        await openAlert(tester);
        BoxDecoration frameOf(Finder of) =>
            tester
                    .widget<Container>(
                      find
                          .descendant(of: of, matching: find.byType(Container))
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        final frame = frameOf(find.byType(FriendInviteAlertCard));
        expect(frame.border, Border.all(color: AppColors.ink, width: 2));
        expect(frame.borderRadius, BorderRadius.circular(20));
        expect(frame.boxShadow!.single.offset, const Offset(3, 4));
        expect(frame.boxShadow!.single.blurRadius, 0);
        repo.answer(sent.id, InviteStatus.cancelled);
        await tester.tap(find.text('수락'));
        await tester.pump();
        final error = find.byType(FriendAlertErrorCard);
        expect(error, findsOneWidget);
        expect(frameOf(error).border, frame.border);
        expect(find.byType(FriendInvitePanel), findsNothing);
        expect(find.text('거절'), findsNothing);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
      });

      testWidgets('it counts down each second, and at 0 it goes and the '
          'invite is not offered again (spec 6, 9.7)', (tester) async {
        repo.receiveInvite(_friend, ExerciseType.pushUp);
        await openAlert(tester);
        clock = clock.add(const Duration(seconds: 59));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('0:01'), findsOneWidget);
        expect(
          tester.widget<FriendTimeBar>(find.byType(FriendTimeBar)).seconds,
          1,
        );
        clock = clock.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(FriendInviteAlertCard), findsNothing);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(find.byType(FriendInviteAlertCard), findsNothing);
      });

      testWidgets('a phone clock over a minute ahead: the alert shows 0:00 '
          'and an empty bar, and goes with the next read that no longer lists '
          'it (user, 2026-11-27)', (tester) async {
        ahead = const Duration(seconds: 61);
        repo.receiveInvite(_friend, ExerciseType.squat);
        await openAlert(tester);
        expect(find.byType(FriendInviteAlertCard), findsOneWidget);
        expect(find.text('0:00'), findsOneWidget);
        expect(
          tester.widget<FriendTimeBar>(find.byType(FriendTimeBar)).fraction,
          0,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(FriendInviteAlertCard), findsOneWidget);
        clock = clock.add(const Duration(minutes: 1));
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(find.byType(FriendInviteAlertCard), findsNothing);
      });

      testWidgets('a screen reader hears the sentence as it comes; the '
          'picture is not read', (tester) async {
        final semantics = tester.ensureSemantics();
        repo.receiveInvite(_friend, ExerciseType.squat);
        await openAlert(tester);
        final node = tester.getSemantics(
          find.bySemanticsLabel('헬창님이 스쿼트 대결을 신청했어요'),
        );
        expect(node, isSemantics(isLiveRegion: true));
        expect(find.bySemanticsLabel('헬창님이'), findsNothing);
        expect(find.bySemanticsLabel('1:00'), findsNothing);
        expect(find.bySemanticsLabel('수락'), findsOneWidget);
        semantics.dispose();
      });

      for (final (size, scale) in const [
        (Size(360, 780), 1.3),
        (Size(320, 640), 1.0),
      ]) {
        testWidgets('it fits ${size.width.toInt()} x ${size.height.toInt()} '
            'with $scale times the text and a long nickname (spec 9.10)', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          repo.receiveInvite(
            const FriendPerson(
              id: 8,
              nickname: '가나다라마바사아자차카타',
              code: '가나다라마바사아자차카타#0008',
            ),
            ExerciseType.squat,
          );
          await openAlert(tester, size: size);
          expect(find.byType(FriendInviteAlertCard), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}
