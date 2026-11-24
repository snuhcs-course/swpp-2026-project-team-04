import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/arcade_boss_screen.dart';
import 'package:gymrats_app/screens/arcade_flow.dart';
import 'package:gymrats_app/screens/arcade_screen.dart';
import 'package:gymrats_app/screens/hold_stage_screen.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';
import 'package:gymrats_app/services/pose/hold_poses.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/arcade_viewmodel.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/viewmodels/hold_stage_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_hold_music.dart';
import 'package:gymrats_app/widgets/arcade_map.dart';
import 'package:gymrats_app/widgets/arcade_stage_sheet.dart';
import 'package:provider/provider.dart';

import '../support/audio_fakes.dart';

ArcadeProgress _progress(List<int> first) =>
    ArcadeProgress([...first, for (var i = first.length; i < 24; i++) 0]);

/// The design's `cur`: stages 1 to 7 played, 17 stars.
final _atStage8 = _progress([3, 2, 3, 3, 3, 2, 1]);

/// A store whose first read waits until [release].
class _WaitingStore extends MemoryArcadeProgressStore {
  final gate = Completer<void>();

  @override
  Future<ArcadeProgress> read(int accountId) async {
    await gate.future;
    return super.read(accountId);
  }
}

/// A store whose saves wait until [release], as a slow phone's can, and
/// then fail when [fail] is set.
class _SlowSaveStore extends MemoryArcadeProgressStore {
  final _gate = Completer<void>();
  bool fail = false;

  void release() => _gate.complete();

  @override
  Future<ArcadeProgress> recordStage(
    int accountId,
    int number,
    int stars,
  ) async {
    await _gate.future;
    if (fail) throw StateError('write failed');
    return super.recordStage(accountId, number, stars);
  }
}

void main() {
  late MemoryArcadeProgressStore store;
  late ArcadeViewModel arcade;
  late List<ArcadeHoldStage> holds;

  /// How the stand-in hold screen is left.
  HoldStageExit? holdExit;

  /// When set, the stand-in hold keeps these stars before it is left, as
  /// A4's screen does: in the store the arcade gives a hold's screen
  /// ([ArcadeFlow.holdStore]), without waiting for the save.
  int? holdStars;

  /// Whether the stand-in hold opens a page of its own and is left from it,
  /// as A4's screen is (the map then hears the page close).
  bool holdPage = false;

  setUp(() {
    store = MemoryArcadeProgressStore();
    holds = [];
    holdExit = null;
    holdStars = null;
    holdPage = false;
  });

  /// The map over a page below, signed in as account 1 with [progress].
  Future<void> open(
    WidgetTester tester, {
    ArcadeProgress? progress,
    MemoryArcadeProgressStore? using,
    bool realHold = false,
    CharacterViewModel? characters,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    if (using != null) store = using;
    if (progress != null) store.saved[1] = progress;
    arcade = ArcadeViewModel(store: store);
    addTearDown(arcade.dispose);
    unawaited(arcade.load(1));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ArcadeViewModel>.value(value: arcade),
          if (characters != null)
            ChangeNotifierProvider<CharacterViewModel>.value(value: characters),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          navigatorObservers: [GymRatsApp.routeObserver],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, GymRatsApp.arcadeRoute),
                child: const Text('below'),
              ),
            ),
          ),
          onGenerateRoute: (settings) => switch (settings.name) {
            GymRatsApp.arcadeRoute => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => ArcadeScreen(
                openHold: realHold
                    ? null
                    : (context, stage) async {
                        holds.add(stage);
                        final stars = holdStars;
                        if (holdPage) {
                          return Navigator.push<HoldStageExit>(
                            context,
                            MaterialPageRoute(
                              builder: (page) => Scaffold(
                                body: Column(
                                  children: [
                                    const Text('hold page'),
                                    TextButton(
                                      onPressed: () {
                                        if (stars != null) {
                                          unawaited(
                                            ArcadeFlow.holdStore(page)!
                                                .recordStage(
                                                  1,
                                                  stage.number,
                                                  stars,
                                                )
                                                .then<void>(
                                                  (_) {},
                                                  onError: (_) {},
                                                ),
                                          );
                                        }
                                        Navigator.pop(page, holdExit);
                                      },
                                      child: const Text('leave the hold'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        if (stars != null) {
                          unawaited(
                            ArcadeFlow.holdStore(context)!
                                .recordStage(1, stage.number, stars)
                                .then<void>((_) {}, onError: (_) {}),
                          );
                        }
                        return holdExit;
                      },
              ),
            ),
            GymRatsApp.versusRoute => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: Text(
                  'versus ${(settings.arguments! as Matchup).opponent.name}',
                ),
              ),
            ),
            _ => null,
          },
        ),
      ),
    );
    await tester.tap(find.text('below'));
    await tester.pumpAndSettle();
  }

  Finder cell(int number) => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('STAGE $number,') ?? false),
  );

  Future<void> tapCell(WidgetTester tester, int number) async {
    await tester.ensureVisible(cell(number));
    await tester.pumpAndSettle();
    await tester.tap(cell(number), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('while the progress is read only the header shows (spec 9)', (
    tester,
  ) async {
    final waiting = _WaitingStore();
    await open(tester, using: waiting);
    expect(find.text('아케이드'), findsOneWidget);
    expect(find.text('PLAY / ARCADE'), findsOneWidget);
    expect(find.byType(ArcadeMap), findsNothing);
    expect(find.text('도전'), findsNothing);
    expect(find.text('/ 72'), findsNothing);
    waiting.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ArcadeMap), findsOneWidget);
  });

  testWidgets('STAGE 8: 17 of 72 stars, and the bar with the stage to play '
      '(design ArcMap cur)', (tester) async {
    await open(tester, progress: _atStage8);
    // 17 is also a stage's number on the map.
    expect(find.text('17'), findsWidgets);
    expect(find.text('/ 72'), findsOneWidget);
    expect(find.bySemanticsLabel('별 17개, 72개 중'), findsOneWidget);
    expect(find.text('STAGE 8 · 2F'), findsOneWidget);
    expect(find.text('물렁범 · 스쿼트'), findsOneWidget);
    expect(find.text('도전'), findsOneWidget);
  });

  testWidgets('it opens with the stage to play about the middle of the map '
      '(spec 4)', (tester) async {
    await open(tester, progress: _atStage8);
    final view = tester.getRect(find.byType(SingleChildScrollView));
    final stage = tester.getCenter(cell(8));
    expect((stage.dy - view.center.dy).abs(), lessThan(2));
  });

  testWidgets('a new account opens at STAGE 1, the map scrolled to its end', (
    tester,
  ) async {
    await open(tester, progress: ArcadeProgress.initial());
    expect(find.text('STAGE 1 · 1F'), findsOneWidget);
    expect(find.text('RepBot · 푸쉬업'), findsOneWidget);
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(scroll.pixels, scroll.maxScrollExtent);
  });

  testWidgets('all 24 cleared: no bar, 72 stars, at the top with 5F', (
    tester,
  ) async {
    await open(tester, progress: ArcadeProgress(List.filled(24, 3)));
    expect(find.text('72'), findsOneWidget);
    expect(find.text('도전'), findsNothing);
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(scroll.pixels, 0);
    expect(find.text('공사중').hitTestable(), findsWidgets);
  });

  testWidgets('the bar\'s 도전 opens the stage sheet; 닫기 closes it (spec 5)', (
    tester,
  ) async {
    await open(tester, progress: _atStage8);
    await tester.tap(find.text('도전'));
    await tester.pumpAndSettle();
    expect(find.byType(ArcadeStageSheet), findsOneWidget);
    expect(find.text('STAGE 8'), findsOneWidget);
    expect(find.text('2F · AI LV 6'), findsOneWidget);
    expect(find.text('스쿼트 · 30초'), findsOneWidget);
    // The rule chip of 2F, also on its band under the sheet.
    expect(
      find.descendant(
        of: find.byType(ArcadeStageSheet),
        matching: find.text('피버 15초부터'),
      ),
      findsOneWidget,
    );
    expect(find.text('별 조건'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(ArcadeStageSheet), findsNothing);
    expect(find.byType(ArcadeScreen), findsOneWidget);
  });

  testWidgets('the sheet\'s 도전 opens the stage\'s versus', (tester) async {
    await open(tester, progress: _atStage8);
    await tester.tap(find.text('도전'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ArcadeStageSheet),
        matching: find.text('도전'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('versus STAGE 8 · 물렁범'), findsOneWidget);
  });

  testWidgets('cells: a played fight opens its sheet again, a boss its '
      'intro, a hold the hold screen; a locked one nothing (spec 4)', (
    tester,
  ) async {
    await open(tester, progress: _atStage8);
    await tapCell(tester, 7);
    expect(find.byType(ArcadeStageSheet), findsOneWidget);
    expect(find.text('STAGE 7'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    await tapCell(tester, 3);
    expect(holds.map((stage) => stage.number), [3]);

    await tapCell(tester, 9);
    expect(find.byType(ArcadeStageSheet), findsNothing);
    expect(holds.map((stage) => stage.number), [3]);

    await tapCell(tester, 6);
    expect(find.byType(ArcadeBossScreen), findsOneWidget);
    expect(find.text('STAGE 6 · 1F BOSS'), findsOneWidget);
  });

  testWidgets('back from a stage reads the progress again, moves the bar on, '
      'and opens the stage a result asked for', (tester) async {
    await open(tester, progress: _atStage8);
    await tester.tap(find.text('도전'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ArcadeStageSheet),
        matching: find.text('도전'),
      ),
    );
    await tester.pumpAndSettle();
    // Meanwhile stage 8 and the hold after it were cleared, and the result
    // asked for stage 10.
    store.saved[1] = _progress([3, 2, 3, 3, 3, 2, 1, 2, 1]);
    arcade.request(10);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('STAGE 10 · 2F'), findsOneWidget);
    expect(find.byType(ArcadeStageSheet), findsOneWidget);
    expect(find.text('곰탱이'), findsWidgets);
    expect(arcade.takeRequest(), isNull);
  });

  testWidgets('a hold\'s 다음 스테이지 reads the progress again and opens the '
      'stage after it (spec 8)', (tester) async {
    await open(tester, progress: _progress([3, 2]));
    // The hold keeps its stars itself (A4), then 다음 스테이지.
    store.saved[1] = _progress([3, 2, 2]);
    holdExit = HoldStageExit.nextStage;
    await tapCell(tester, 3);
    await tester.pumpAndSettle();
    expect(holds.map((stage) => stage.number), [3]);
    expect(find.byType(ArcadeStageSheet), findsOneWidget);
    expect(find.text('STAGE 4'), findsOneWidget);
    expect(find.text('STAGE 4 · 1F'), findsOneWidget);
  });

  group("a hold's 다음 스테이지 while its stars are still being kept (PR #91 "
      'review)', () {
    testWidgets('it waits for the save, then opens the stage after it', (
      tester,
    ) async {
      final slow = _SlowSaveStore();
      await open(tester, progress: _progress([3, 2]), using: slow);
      holdStars = 2;
      holdExit = HoldStageExit.nextStage;
      await tapCell(tester, 3);
      expect(find.byType(ArcadeStageSheet), findsNothing);
      expect(arcade.progress!.isOpen(4), isFalse);

      slow.release();
      await tester.pumpAndSettle();
      expect(slow.saved[1]!.bestOf(3), 2);
      expect(holds.map((stage) => stage.number), [3]);
      expect(find.byType(ArcadeStageSheet), findsOneWidget);
      expect(find.text('STAGE 4'), findsOneWidget);
    });

    testWidgets("a hold left from its own page, as A4's is: the stage after "
        'it opens once, after the save', (tester) async {
      final slow = _SlowSaveStore();
      holdPage = true;
      await open(tester, progress: _progress([3, 2]), using: slow);
      holdStars = 2;
      holdExit = HoldStageExit.nextStage;
      await tapCell(tester, 3);
      expect(find.text('hold page'), findsOneWidget);
      await tester.tap(find.text('leave the hold'));
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(find.byType(ArcadeStageSheet), findsNothing);

      slow.release();
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeStageSheet), findsOneWidget);
      expect(find.text('STAGE 4'), findsOneWidget);
      expect(arcade.hasRequest, isFalse);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeStageSheet), findsNothing);
    });

    testWidgets("before a boss match it opens the boss's intro the same "
        'way', (tester) async {
      final slow = _SlowSaveStore();
      await open(tester, progress: _progress([3, 2, 2, 3]), using: slow);
      holdStars = 1;
      holdExit = HoldStageExit.nextStage;
      await tapCell(tester, 5);
      expect(find.byType(ArcadeBossScreen), findsNothing);

      slow.release();
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeBossScreen), findsOneWidget);
    });

    testWidgets('a save that fails drops it: the map stays', (tester) async {
      final slow = _SlowSaveStore()..fail = true;
      await open(tester, progress: _progress([3, 2]), using: slow);
      holdStars = 2;
      holdExit = HoldStageExit.nextStage;
      await tapCell(tester, 3);
      slow.release();
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeStageSheet), findsNothing);
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(arcade.progress!.isOpen(4), isFalse);
      expect(arcade.hasRequest, isFalse);
    });

    testWidgets('a page over the map meanwhile drops it', (tester) async {
      final slow = _SlowSaveStore();
      await open(tester, progress: _progress([3, 2]), using: slow);
      holdStars = 2;
      holdExit = HoldStageExit.nextStage;
      await tapCell(tester, 3);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('another page')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      slow.release();
      await tester.pumpAndSettle();
      expect(find.text('another page'), findsOneWidget);
      expect(find.byType(ArcadeStageSheet), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(arcade.progress!.isOpen(4), isTrue);
      expect(find.byType(ArcadeStageSheet), findsNothing);
    });

    testWidgets('leaving the map meanwhile drops it: the next visit opens '
        'nothing on its own', (tester) async {
      final slow = _SlowSaveStore();
      await open(tester, progress: _progress([3, 2]), using: slow);
      holdStars = 2;
      holdExit = HoldStageExit.nextStage;
      await tapCell(tester, 3);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeScreen), findsNothing);

      slow.release();
      await tester.pumpAndSettle();
      expect(arcade.hasRequest, isFalse);

      holdStars = null;
      holdExit = HoldStageExit.arcade;
      await tester.tap(find.text('below'));
      await tester.pumpAndSettle();
      await tapCell(tester, 3);
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(find.byType(ArcadeStageSheet), findsNothing);
    });
  });

  testWidgets('a hold left by 아케이드로 or mid-stage stays on the map', (
    tester,
  ) async {
    await open(tester, progress: _progress([3, 2]));
    for (final exit in [HoldStageExit.arcade, HoldStageExit.left, null]) {
      holdExit = exit;
      await tapCell(tester, 3);
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeStageSheet), findsNothing);
      expect(find.byType(ArcadeScreen), findsOneWidget);
    }
    expect(holds, hasLength(3));
  });

  testWidgets('the app\'s own way into a hold: A4\'s screen for the stage, '
      'with the arcade\'s store, account and the user\'s character', (
    tester,
  ) async {
    SoundServices.shared = SoundServices.silent();
    addTearDown(() => SoundServices.shared = null);
    final chosen = CharacterRig.standard.selectable
        .firstWhere((art) => art.id != CharacterRig.defaultId)
        .id;
    final characters = CharacterViewModel(store: MemoryCharacterStore());
    addTearDown(characters.dispose);
    await characters.load(1);
    await characters.choose(chosen);
    await open(
      tester,
      progress: _progress([3, 2]),
      realHold: true,
      characters: characters,
    );
    await tapCell(tester, 3);
    final screen = tester.widget<HoldStageScreen>(find.byType(HoldStageScreen));
    expect(screen.stage, 3);
    // The arcade's store, through the arcade's view model: a hold's save is
    // kept as a fight's (PR #91 review).
    expect(screen.progressStore, same(arcade.holdStore));
    final kept = screen.progressStore!.recordStage(1, 3, 2);
    expect(arcade.saving, isTrue);
    await tester.runAsync(() => kept);
    expect(arcade.saving, isFalse);
    expect(store.saved[1]!.bestOf(3), 2);
    expect(arcade.progress!.bestOf(3), 2);
    expect(screen.accountId, 1);
    expect(screen.myCharacter, chosen);
    expect(screen.createViewModel, isNull);
    // The app's sound, with the music in a fight stage's order.
    final shared = SoundServices.shared;
    expect(screen.sounds!.music, isA<ArcadeHoldMusic>());
    expect(screen.sounds!.effects, same(shared.effects));
    expect(screen.sounds!.voice, same(shared.voice));
    expect(screen.sounds!.settings, same(shared.settings));
    expect(holds, isEmpty);
  });

  group('a hold\'s music from the map, in a fight stage\'s order', () {
    late FakeBackgroundMusic music;

    setUp(() {
      music = FakeBackgroundMusic();
      SoundServices.shared = SoundServices(
        settings: SoundSettings(store: MemorySoundSettingsStore()),
        voice: FakeVoiceGuidance(),
        music: music,
        effects: FakeSoundEffects(),
      );
    });
    tearDown(() => SoundServices.shared = null);

    testWidgets('closed on its briefing after a jingle, the map stays '
        'silent, as after backing out of a fight\'s versus screen', (
      tester,
    ) async {
      await open(tester, progress: _progress([3, 2]), realHold: true);
      // A fight's result just played its jingle.
      SoundServices.shared.music.play(MusicCue.win);
      await tapCell(tester, 3);
      expect(find.byType(HoldStageScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('지도로'));
      await tester.pumpAndSettle();
      expect(find.byType(HoldStageScreen), findsNothing);
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(music.played, [MusicCue.win]);
    });
  });

  testWidgets('a chair stage opens the hold screen with the chair pose '
      '(A5), not a stand-in', (tester) async {
    SoundServices.shared = SoundServices.silent();
    addTearDown(() => SoundServices.shared = null);
    await open(tester, progress: _progress([3, 2, 3, 3]), realHold: true);
    await tapCell(tester, 5);
    final screen = tester.widget<HoldStageScreen>(find.byType(HoldStageScreen));
    expect(screen.stage, 5);
    expect(screen.createViewModel, isNull);
    final viewModel = Provider.of<HoldStageViewModel>(
      tester.element(find.text('STAGE 5 · 1F')),
      listen: false,
    );
    expect(viewModel.definition, same(HoldPoses.of(HoldPose.chair)));
    expect(find.text('의자 자세'), findsOneWidget);
    expect(holds, isEmpty);
  });

  testWidgets('back returns to 게임 시작', (tester) async {
    await open(tester, progress: _atStage8);
    await tester.tap(find.byTooltip('게임 시작으로'));
    await tester.pumpAndSettle();
    expect(find.text('below'), findsOneWidget);
  });

  testWidgets('every button is big enough and has a name (spec 11)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, progress: _atStage8);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      find.bySemanticsLabel('STAGE 8, 물렁범 · 스쿼트, 별 0개, 지금 판'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  test('the bar uses the stage\'s own title (ArcadeWords)', () {
    expect(ArcadeWords.title(ArcadeCatalog.stage(8)), '물렁범 · 스쿼트');
  });
}
