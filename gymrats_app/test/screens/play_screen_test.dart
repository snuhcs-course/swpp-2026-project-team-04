import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/arcade_play_card.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/friend_battle_card.dart';
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

  testWidgets('shows the two cards and the friend card, no AI 1v1, no again '
      'row and no rules link (P16 spec 3, 13.1; A11 spec 3)', (tester) async {
    await open(tester);
    expect(find.text('01 / PLAY'), findsOneWidget);
    expect(find.text('게임 시작'), findsOneWidget);
    expect(find.byType(ArcadePlayCard), findsNWidgets(2));
    expect(find.text('온라인 대결'), findsOneWidget);
    expect(find.text('아케이드'), findsOneWidget);
    expect(find.byType(FriendBattleCard), findsOneWidget);
    expect(find.text('친구와의\n대전'), findsOneWidget);
    // A11: the icon row's words are gone.
    expect(find.text('친구 코드로 추가하고 대결 신청'), findsNothing);
    // No AI 1v1 and no 이어하기, though the last battle was against a bot.
    expect(find.text('AI 1v1'), findsNothing);
    expect(find.text('초보 · 중수 · 고수'), findsNothing);
    expect(find.text('푸쉬업 · AI 1v1 · 고수'), findsNothing);
    // A11: no 규칙 보기 (the rules open from home's ? and 환경설정).
    expect(find.text('규칙 보기'), findsNothing);
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
    // On the online card (A11's friend card has its own fixed pair).
    final online = find.ancestor(
      of: find.text('온라인 대결'),
      matching: find.byType(ArcadePlayCard),
    );
    expect(
      tester
          .widgetList<CharacterFigure>(
            find.descendant(of: online, matching: find.byType(CharacterFigure)),
          )
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

  testWidgets('no 규칙 보기 link: nothing here opens the rules (A11 spec 3)', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('규칙 보기'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(HelpScreen), findsNothing);
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
    // A11 spec 9.10.
    ('360 x 780 at 1.3 times the text', const Size(360, 780), 1.3),
    ('a small phone, 320 x 640', const Size(320, 640), 1.0),
  ]) {
    testWidgets('fits $label without overflow, scrolling if it must', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      // The friend card's bottom, its arrow chip, can be reached.
      await tester.dragUntilVisible(
        find.byType(FriendBattleCard),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(FriendBattleCard));
      expect(card.height, greaterThanOrEqualTo(FriendBattleCard.minHeight));
      expect(card.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
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
    // A11 spec 3: the card's name alone while nothing waits.
    expect(find.bySemanticsLabel('친구와의 대전'), findsOneWidget);
    semantics.dispose();
  });

  group('친구와의 대전 card (P9, A11)', () {
    const friend = FriendPerson(id: 2, nickname: '헬창', code: '헬창#0002');

    // The 수락 대기! sticker shakes for as long as it shows; reduced motion
    // holds it still so the pages settle (its motion: friend_battle_card_test).
    setUp(() {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    });

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
      // No top-right friends button: the card is the way in.
      expect(find.byTooltip('친구'), findsNothing);
      final row = tester.getRect(find.byType(FriendBattleCard));
      final card = tester.getRect(find.byType(ArcadePlayCard).first);
      expect(row.top, greaterThan(card.bottom));
      await tapAndSettle(tester, find.byType(FriendBattleCard));
      expect(find.text('friends page'), findsOneWidget);
      Navigator.pop(tester.element(find.text('friends page')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayScreen), findsOneWidget);
    });

    testWidgets('the friends page opens with home\'s profile, for its '
        'exercise sheet\'s bests (A11 spec 4)', (tester) async {
      final vm = await open(tester);
      await tapAndSettle(tester, find.byType(FriendBattleCard));
      final route = ModalRoute.of(tester.element(find.text('friends page')))!;
      expect(route.settings.arguments, same(vm.state.profile));
      expect((route.settings.arguments! as UserProfile).name, '우현');
    });

    for (final size in const [Size(360, 780), Size(412, 915)]) {
      testWidgets('at ${size.width.toInt()} x ${size.height.toInt()} the card '
          'starts 12 under the two cards and runs to the page\'s bottom '
          'margin (A11 spec 3)', (tester) async {
        await open(tester, size: size);
        final cards = tester.getRect(find.byType(ArcadePlayCard).first);
        final friendCard = tester.getRect(find.byType(FriendBattleCard));
        expect(friendCard.top, cards.bottom + AppSpacing.s12);
        expect(friendCard.bottom, size.height - AppSpacing.s24);
        expect(friendCard.left, AppSpacing.s20);
        expect(friendCard.right, size.width - AppSpacing.s20);
      });
    }

    testWidgets('its picture: 그루 against 곰탱이 on discs with VS, the '
        'two-line name and a sky arrow (A11 spec 3)', (tester) async {
      await open(tester);
      final card = find.byType(FriendBattleCard);
      Finder inCard(Finder of) => find.descendant(of: card, matching: of);
      expect(
        {
          for (final f in tester.widgetList<CharacterFigure>(
            inCard(find.byType(CharacterFigure)),
          ))
            (f.characterId, f.side),
        },
        {('kangaroo', BattleSide.me), ('bear', BattleSide.opponent)},
      );
      expect(inCard(find.text('VS')), findsOneWidget);
      expect(inCard(find.text('친구와의\n대전')), findsOneWidget);
      expect(
        tester
            .widgetList<ArcadeGlyphIcon>(inCard(find.byType(ArcadeGlyphIcon)))
            .map((icon) => (icon.glyph, icon.color)),
        [(ArcadeGlyph.arrow, AppColors.fever)],
      );
    });

    testWidgets('no sticker while nothing waits for an answer', (tester) async {
      final friends = InMemoryFriendRepository()..friends.add(friend);
      await openWith(tester, friends);
      expect(find.text('수락 대기!'), findsNothing);
      expect(find.byType(FriendWaitSticker), findsNothing);
    });

    testWidgets('a sticker for a friend request, gone after coming back', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final friends = InMemoryFriendRepository()
        ..incoming.add(const FriendRequestItem(id: 5, person: friend));
      await openWith(tester, friends);
      // Its words only, no count.
      expect(
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(FriendWaitSticker),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data),
        ['수락 대기!'],
      );
      expect(
        find.bySemanticsLabel('친구와의 대전, 수락을 기다리는 신청이 있어요'),
        findsOneWidget,
      );
      await tapAndSettle(tester, find.byType(FriendBattleCard));
      friends.incoming.clear();
      Navigator.pop(tester.element(find.text('friends page')));
      await tester.pumpAndSettle();
      expect(find.text('수락 대기!'), findsNothing);
      expect(find.bySemanticsLabel('친구와의 대전'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a request that comes while the page is open shows within '
        'one refresh', (tester) async {
      final friends = InMemoryFriendRepository()..friends.add(friend);
      await openWith(tester, friends);
      expect(find.text('수락 대기!'), findsNothing);
      friends.incoming.add(const FriendRequestItem(id: 7, person: friend));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('수락 대기!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no reading while another page is on top', (tester) async {
      final friends = _CountingFriends()..friends.add(friend);
      await openWith(tester, friends);
      await tester.tap(find.byType(FriendBattleCard));
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

    testWidgets('a sticker for a battle invite', (tester) async {
      final friends = InMemoryFriendRepository()..friends.add(friend);
      friends.receiveInvite(friend, ExerciseType.squat);
      await openWith(tester, friends);
      expect(find.text('수락 대기!'), findsOneWidget);
    });

    testWidgets('no sticker when the server cannot be read', (tester) async {
      await openWith(tester, _FailingFriends());
      expect(find.text('수락 대기!'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the picture\'s scale (A11, user 2026-11-27)', () {
    // Last in the file: the fonts stay loaded for the rest of the run.
    Future<void> loadNameFont(WidgetTester tester) => tester.runAsync(() async {
      final loader = FontLoader(AppFonts.display)
        ..addFont(rootBundle.load('assets/fonts/DoHyeon-Regular.ttf'));
      await loader.load();
    });

    for (final (size, panel) in const [
      (Size(360, 780), 190.0),
      (Size(320, 640), 150.0),
      (Size(412, 915), 242.0),
    ]) {
      testWidgets('at ${size.width.toInt()} x ${size.height.toInt()} the '
          'panel is $panel wide, the name keeps its room and its size', (
        tester,
      ) async {
        await loadNameFont(tester);
        await open(tester, size: size);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();
        final card = tester.getSize(find.byType(FriendBattleCard));
        final inside = Size(card.width - 2, card.height - 2);
        final scale = FriendBattleCard.pictureScale(inside);
        final shown = tester.getSize(find.byType(ArcadeFriendPanel));
        expect(shown.width, closeTo(panel, 1e-9));
        expect(shown.width, closeTo(190 * scale, 1e-9));
        expect(shown.height, inside.height);
        expect(
          inside.width - shown.width,
          greaterThanOrEqualTo(FriendBattleCard.nameMinWidth - 1e-9),
        );
        if (size == const Size(360, 780)) expect(scale, 1);
        // Only the picture shrinks: the name is drawn at its own size.
        final fitted = tester.renderObject<RenderFittedBox>(
          find
              .ancestor(
                of: find.text('친구와의\n대전'),
                matching: find.byType(FittedBox),
              )
              .first,
        );
        expect(fitted.size, fitted.child!.size);
      });
    }
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
