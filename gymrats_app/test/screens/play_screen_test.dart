import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/play_screen.dart';
import 'package:gymrats_app/services/friends/friend_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_play_card.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/gym_owner_figure.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

MatchRecord _battleWith(String opponentName, ExerciseType exercise) =>
    MatchRecord(
      exercise: exercise,
      opponentName: opponentName,
      myReps: 10,
      opponentReps: 8,
    );

void main() {
  late FakeUserRepository repository;

  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  setUp(() {
    repository = FakeUserRepository()
      ..profile = UserProfile(
        name: '우현',
        bests: const {
          ExerciseType.pushUp: PersonalBest(reps: 24, score: 240),
          ExerciseType.squat: PersonalBest(reps: 30),
        },
        lastMatch: _battleWith(
          BotDifficulty.expert.opponentName,
          ExerciseType.pushUp,
        ),
      );
  });

  /// The play page over a stub page, on home's loaded view model, with stub
  /// pages for the routes it opens that show their arguments.
  Future<HomeViewModel> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = HomeViewModel(repository: repository);
    addTearDown(vm.dispose);
    await vm.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: vm,
                    child: const PlayScreen(),
                  ),
                ),
              ),
              child: const Text('below'),
            ),
          ),
        ),
        routes: {
          GymRatsApp.helpRoute: (_) => const HelpScreen(),
          GymRatsApp.friendsRoute: (_) =>
              const Scaffold(body: Text('friends page')),
          GymRatsApp.onlineBattleRoute: (context) => Scaffold(
            body: Text('lobby ${ModalRoute.of(context)!.settings.arguments}'),
          ),
          GymRatsApp.arcadeRoute: (_) =>
              const Scaffold(body: Text('arcade map')),
          GymRatsApp.weeklyRankingsRoute: (_) =>
              const Scaffold(body: Text('weekly rankings')),
        },
      ),
    );
    await tester.tap(find.text('below'));
    await tester.pumpAndSettle();
    return vm;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the two cards and the rules, no AI 1v1 and no again '
      'row (P16 spec 3, 13.1)', (tester) async {
    await open(tester);
    expect(find.text('01 / PLAY'), findsOneWidget);
    expect(find.text('게임 시작'), findsOneWidget);
    expect(find.byType(ArcadePlayCard), findsNWidgets(2));
    expect(find.text('온라인 대결'), findsOneWidget);
    expect(find.text('아케이드'), findsOneWidget);
    expect(find.text('친구와의 대전'), findsOneWidget);
    expect(find.text('친구 코드로 추가하고 대결 신청'), findsOneWidget);
    // No AI 1v1 and no 이어하기, though the last battle was against a bot.
    expect(find.text('AI 1v1'), findsNothing);
    expect(find.text('초보 · 중수 · 고수'), findsNothing);
    expect(find.text('푸쉬업 · AI 1v1 · 고수'), findsNothing);
    expect(find.text('규칙 보기'), findsOneWidget);
    // Replaced by 친구와의 대전 (P9): no play-again row, no rule line.
    expect(find.text('최근 설정으로 다시 하기'), findsNothing);
    expect(find.text('30초 · 점수 높은 쪽 승리'), findsNothing);
  });

  testWidgets("the cards are the design's size and pictures: 펭뚱이 against "
      "GYM마우스, and 1F's owner (PlayX)", (tester) async {
    await open(tester);
    for (final card in tester.widgetList<ArcadePlayCard>(
      find.byType(ArcadePlayCard),
    )) {
      expect(
        tester.getSize(find.byWidget(card)),
        const Size(ArcadePlayCard.width, ArcadePlayCard.height),
      );
    }
    final online = find.ancestor(
      of: find.text('온라인 대결'),
      matching: find.byType(ArcadePlayCard),
    );
    final figures = tester
        .widgetList<CharacterFigure>(
          find.descendant(of: online, matching: find.byType(CharacterFigure)),
        )
        .toList();
    // Each figure is drawn once more for its white edge.
    expect(
      {for (final f in figures) (f.characterId, f.side)},
      {('penguin', BattleSide.opponent), ('mouse', BattleSide.me)},
    );
    final arcade = find.ancestor(
      of: find.text('아케이드'),
      matching: find.byType(ArcadePlayCard),
    );
    expect(
      tester
          .widgetList<GymOwnerFigure>(
            find.descendant(of: arcade, matching: find.byType(GymOwnerFigure)),
          )
          .map((owner) => owner.ownerId)
          .toSet(),
      {'seal'},
    );
  });

  testWidgets("the online card's GYM마우스 is fixed, not the user's "
      'character', (tester) async {
    await open(tester);
    expect(
      tester
          .widgetList<CharacterFigure>(find.byType(CharacterFigure))
          .where((figure) => figure.side == BattleSide.me)
          .map((figure) => figure.characterId)
          .toSet(),
      {'mouse'},
    );
  });

  testWidgets('the arcade card opens the arcade', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('아케이드'));
    expect(find.text('arcade map'), findsOneWidget);
  });

  testWidgets('the online card asks for the exercise, then opens the lobby', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('온라인 대결'));
    // The main match: no mode to pick first (friends have their own row).
    expect(find.text('메인 매치'), findsNothing);
    expect(find.byType(ExerciseSheet), findsOneWidget);
    // P11: no "온라인 1v1 · 30초" line; the weekly rankings row instead.
    expect(find.text('온라인 1v1 · 30초'), findsNothing);
    expect(find.byType(WeeklyRankingsRow), findsOneWidget);
    // The sheet reads each exercise's own best.
    expect(find.text('개인 최고 240점', findRichText: true), findsOneWidget);
    expect(find.text('개인 최고 30회', findRichText: true), findsOneWidget);

    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(ExerciseSheet),
        matching: find.text('스쿼트'),
      ),
    );
    expect(find.text('lobby ${ExerciseType.squat}'), findsOneWidget);
  });

  testWidgets('the sheet\'s weekly rankings row opens the rankings over it', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('온라인 대결'));
    await tapAndSettle(tester, find.text('주간 랭킹'));
    expect(find.text('weekly rankings'), findsOneWidget);

    // Back comes to the sheet, still asking for the exercise.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsOneWidget);
  });

  testWidgets('closing the online sheet stays here with no lobby', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('온라인 대결'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(find.textContaining('lobby'), findsNothing);
  });

  testWidgets('an exercise chosen after the page has gone opens no lobby', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('온라인 대결'));
    final page = ModalRoute.of(tester.element(find.byType(PlayScreen)))!;
    page.navigator!.removeRoute(page);
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(ExerciseSheet),
        matching: find.text('푸쉬업'),
      ),
    );
    expect(find.textContaining('lobby'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('규칙 보기 opens the rules', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('규칙 보기'));
    expect(find.byType(HelpScreen), findsOneWidget);
  });

  testWidgets('back returns to the page below', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.byTooltip('뒤로'));
    expect(find.byType(PlayScreen), findsNothing);
    expect(find.text('below'), findsOneWidget);
  });

  for (final (label, size, scale) in [
    ('a short phone', const Size(360, 640), 1.0),
    ('a large text size', const Size(360, 780), 2.0),
  ]) {
    testWidgets('fits $label without overflow, scrolling if it must', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text('규칙 보기'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(find.text('규칙 보기').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('no 캐릭터 row: the character is picked from home\'s menu', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('캐릭터'), findsNothing);
    expect(find.text('GYM마우스'), findsNothing);
  });

  testWidgets('every button is big enough and has a name', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(find.bySemanticsLabel('온라인 대결'), findsOneWidget);
    expect(find.bySemanticsLabel('아케이드'), findsOneWidget);
    expect(find.bySemanticsLabel('친구와의 대전, 친구 코드로 추가하고 대결 신청'), findsOneWidget);
    semantics.dispose();
  });

  group('친구와의 대전 row (P9)', () {
    const friend = FriendPerson(id: 2, nickname: '헬창', code: '헬창#0002');

    /// The play page with [friends] provided, as the app does.
    Future<void> openWith(WidgetTester tester, FriendRepository friends) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vm = HomeViewModel(repository: repository);
      addTearDown(vm.dispose);
      await vm.load();
      await tester.pumpWidget(
        Provider<FriendRepository>.value(
          value: friends,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: ChangeNotifierProvider.value(
              value: vm,
              child: const PlayScreen(),
            ),
            routes: {
              GymRatsApp.friendsRoute: (_) =>
                  const Scaffold(body: Text('friends page')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it sits under the two cards and opens the friends page', (
      tester,
    ) async {
      await open(tester);
      // No top-right friends button: the row is the way in.
      expect(find.byTooltip('친구'), findsNothing);
      final row = tester.getRect(find.text('친구와의 대전'));
      final card = tester.getRect(find.byType(ArcadePlayCard).first);
      expect(row.top, greaterThan(card.bottom));
      await tapAndSettle(tester, find.text('친구와의 대전'));
      expect(find.text('friends page'), findsOneWidget);
      Navigator.pop(tester.element(find.text('friends page')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayScreen), findsOneWidget);
    });

    testWidgets('no dot while nothing waits for an answer', (tester) async {
      final friends = InMemoryFriendRepository()..friends.add(friend);
      await openWith(tester, friends);
      expect(find.text('친구 코드로 추가하고 대결 신청'), findsOneWidget);
      expect(find.text('새 친구 요청이나 대결 신청이 있어요'), findsNothing);
    });

    testWidgets('a dot for a friend request, cleared after coming back', (
      tester,
    ) async {
      final friends = InMemoryFriendRepository()
        ..incoming.add(const FriendRequestItem(id: 5, person: friend));
      await openWith(tester, friends);
      expect(find.text('새 친구 요청이나 대결 신청이 있어요'), findsOneWidget);
      await tapAndSettle(tester, find.text('친구와의 대전'));
      friends.incoming.clear();
      Navigator.pop(tester.element(find.text('friends page')));
      await tester.pumpAndSettle();
      expect(find.text('친구 코드로 추가하고 대결 신청'), findsOneWidget);
    });

    testWidgets('a request that comes while the page is open shows within '
        'one refresh', (tester) async {
      final friends = InMemoryFriendRepository()..friends.add(friend);
      await openWith(tester, friends);
      expect(find.text('새 친구 요청이나 대결 신청이 있어요'), findsNothing);
      friends.incoming.add(const FriendRequestItem(id: 7, person: friend));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('새 친구 요청이나 대결 신청이 있어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no reading while another page is on top', (tester) async {
      final friends = _CountingFriends()..friends.add(friend);
      await openWith(tester, friends);
      await tester.tap(find.text('친구와의 대전'));
      await tester.pumpAndSettle();
      final reads = friends.reads;
      await tester.pump(const Duration(seconds: 20));
      expect(friends.reads, reads);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a slow read is not started again on the next tick', (
      tester,
    ) async {
      final friends = _CountingFriends()..hold = Completer<void>();
      await openWith(tester, friends);
      expect(friends.reads, 1);
      await tester.pump(const Duration(seconds: 15));
      expect(friends.reads, 1);
      friends.hold!.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(friends.reads, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no reading while the app is in the background', (
      tester,
    ) async {
      final friends = _CountingFriends();
      await openWith(tester, friends);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      final reads = friends.reads;
      await tester.pump(const Duration(seconds: 20));
      expect(friends.reads, reads);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(seconds: 5));
      expect(friends.reads, reads + 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a dot for a battle invite', (tester) async {
      final friends = InMemoryFriendRepository()..friends.add(friend);
      friends.receiveInvite(friend, ExerciseType.squat);
      await openWith(tester, friends);
      expect(find.text('새 친구 요청이나 대결 신청이 있어요'), findsOneWidget);
    });

    testWidgets('no dot when the server cannot be read', (tester) async {
      await openWith(tester, _FailingFriends());
      expect(find.text('친구 코드로 추가하고 대결 신청'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _CountingFriends extends InMemoryFriendRepository {
  int reads = 0;

  /// While set, reads wait for it.
  Completer<void>? hold;

  @override
  Future<FriendsOverview> fetchOverview() async {
    reads++;
    await hold?.future;
    return super.fetchOverview();
  }
}

class _FailingFriends extends InMemoryFriendRepository {
  @override
  Future<FriendsOverview> fetchOverview() async => throw StateError('down');
}
