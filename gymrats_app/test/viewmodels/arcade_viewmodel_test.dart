import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/arcade_ai_level.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/services/arcade/arcade_star_judge.dart';
import 'package:gymrats_app/viewmodels/arcade_viewmodel.dart';

import '../support/fakes.dart';

/// A store whose reads wait for [answer], and which can fail.
class _SlowStore extends MemoryArcadeProgressStore {
  final reads = <int, Completer<ArcadeProgress>>{};
  bool failReads = false;
  bool failRecords = false;

  /// Whether reads wait for [answer]; off, they answer from memory.
  bool hold = true;

  @override
  Future<ArcadeProgress> read(int accountId) {
    if (failReads) return Future.error(StateError('read failed'));
    if (!hold) return super.read(accountId);
    return (reads[accountId] = Completer()).future;
  }

  void answer(int accountId, ArcadeProgress progress) =>
      reads[accountId]!.complete(progress);

  /// When set, saves wait for it before they read and write.
  Completer<void>? saveGate;

  @override
  Future<ArcadeProgress> recordStage(
    int accountId,
    int number,
    int stars,
  ) async {
    await saveGate?.future;
    if (failRecords) throw StateError('write failed');
    // From memory, not through [read], so a save never waits on a read.
    final progress = (await super.read(accountId)).withStars(number, stars);
    await write(accountId, progress);
    return progress;
  }
}

ArcadeProgress _progress(List<int> first) =>
    ArcadeProgress([...first, for (var i = first.length; i < 24; i++) 0]);

void main() {
  late _SlowStore store;
  late ArcadeViewModel arcade;

  setUp(() {
    store = _SlowStore();
    arcade = ArcadeViewModel(store: store);
  });

  tearDown(() => arcade.dispose());

  group('progress (P16 spec 9)', () {
    test('nothing until the account\'s progress is read', () async {
      expect(arcade.progress, isNull);
      final load = arcade.load(7);
      expect(arcade.accountId, 7);
      expect(arcade.progress, isNull);
      store.answer(7, _progress([3, 2]));
      await load;
      expect(arcade.progress, _progress([3, 2]));
    });

    test('a store that cannot be read gives the first state', () async {
      store.failReads = true;
      await arcade.load(7);
      expect(arcade.progress, ArcadeProgress.initial());
    });

    test('changing account reads that account\'s, and drops a late answer '
        'for the one before', () async {
      final first = arcade.load(1);
      final second = arcade.load(2);
      store.answer(2, _progress([1]));
      await second;
      store.answer(1, _progress([3, 3, 3]));
      await first;
      expect(arcade.accountId, 2);
      expect(arcade.progress, _progress([1]));
    });

    test('refresh shows what it has meanwhile, then the new read', () async {
      final load = arcade.load(1);
      store.answer(1, _progress([1]));
      await load;
      final refresh = arcade.refresh();
      expect(arcade.progress, _progress([1]));
      store.answer(1, _progress([2, 1]));
      await refresh;
      expect(arcade.progress, _progress([2, 1]));
    });

    test('a failed refresh keeps the progress shown', () async {
      final load = arcade.load(1);
      store.answer(1, _progress([3]));
      await load;
      store.failReads = true;
      await arcade.refresh();
      expect(arcade.progress, _progress([3]));
    });

    test('signing out clears everything', () async {
      final load = arcade.load(1);
      store.answer(1, _progress([1]));
      await load;
      arcade.request(4);
      arcade.clear();
      expect(arcade.accountId, isNull);
      expect(arcade.progress, isNull);
      expect(arcade.takeRequest(), isNull);
      await arcade.refresh();
      expect(arcade.progress, isNull);
    });

    test('notifies on every change', () async {
      var heard = 0;
      arcade.addListener(() => heard += 1);
      final load = arcade.load(1);
      expect(heard, 1);
      store.answer(1, _progress([]));
      await load;
      expect(heard, 2);
    });
  });

  group('record', () {
    setUp(() async {
      final load = arcade.load(1);
      store.answer(1, ArcadeProgress.initial());
      await load;
      store.hold = false;
    });

    test(
      'keeps the stars in the store and shows the progress after it',
      () async {
        await arcade.record(1, const ArcadeStars(true, true, false));
        expect(arcade.progress!.bestOf(1), 2);
        expect(store.saved[1]!.bestOf(1), 2);
      },
    );

    test('playing again never loses a star (A2)', () async {
      await arcade.record(1, const ArcadeStars(true, true, true));
      await arcade.record(1, const ArcadeStars(true, false, false));
      expect(arcade.progress!.bestOf(1), 3);
    });

    test('a store that fails leaves the progress as it was', () async {
      store.failRecords = true;
      await arcade.record(1, const ArcadeStars(true, false, false));
      expect(arcade.progress, ArcadeProgress.initial());
    });

    test('signed out, nothing is kept', () async {
      arcade.clear();
      await arcade.record(1, const ArcadeStars(true, false, false));
      expect(store.saved, isEmpty);
    });

    test('saving while the stars are kept; the end is heard, kept or failed '
        '(PR #91 review)', () async {
      final gate = store.saveGate = Completer<void>();
      var heard = 0;
      arcade.addListener(() => heard += 1);
      final kept = arcade.record(1, const ArcadeStars(true, false, false));
      expect(arcade.saving, isTrue);
      gate.complete();
      await kept;
      expect(arcade.saving, isFalse);
      expect(heard, 1);
      expect(arcade.progress!.bestOf(1), 1);

      store.failRecords = true;
      await arcade.record(2, const ArcadeStars(true, false, false));
      expect(arcade.saving, isFalse);
      expect(heard, 2);
      expect(arcade.progress!.bestOf(2), 0);
    });

    test('a read begun while the stars are kept, answered after them, does '
        'not bring back the progress before them (PR #91 review)', () async {
      final gate = store.saveGate = Completer<void>();
      final kept = arcade.record(1, const ArcadeStars(true, true, false));
      store.hold = true;
      final read = arcade.refresh();
      gate.complete();
      await kept;
      expect(arcade.progress!.bestOf(1), 2);
      store.answer(1, ArcadeProgress.initial());
      await read;
      expect(arcade.progress!.bestOf(1), 2);
    });
  });

  group('the stage asked for, taken once it is open (PR #91 review)', () {
    setUp(() async {
      final load = arcade.load(1);
      store.answer(1, _progress([1]));
      await load;
      store.hold = false;
    });

    test('open: taken at once, then gone', () {
      arcade.request(2);
      expect(arcade.takeOpenRequest(), 2);
      expect(arcade.hasRequest, isFalse);
      expect(arcade.takeOpenRequest(), isNull);
    });

    test('locked while the stars are kept: still asked for, and taken once '
        'they are', () async {
      final gate = store.saveGate = Completer<void>();
      final kept = arcade.record(2, const ArcadeStars(true, false, false));
      arcade.request(3);
      expect(arcade.takeOpenRequest(), isNull);
      expect(arcade.hasRequest, isTrue);
      gate.complete();
      await kept;
      expect(arcade.takeOpenRequest(), 3);
      expect(arcade.hasRequest, isFalse);
    });

    test(
      'locked with nothing being kept, or after a failed save: dropped',
      () async {
        arcade.request(3);
        expect(arcade.takeOpenRequest(), isNull);
        expect(arcade.hasRequest, isFalse);

        store.failRecords = true;
        await arcade.record(2, const ArcadeStars(true, false, false));
        arcade.request(3);
        expect(arcade.takeOpenRequest(), isNull);
        expect(arcade.hasRequest, isFalse);
      },
    );
  });

  test('the boss run holds R1 until it ends', () {
    final stage = ArcadeCatalog.stage(6) as ArcadeBossStage;
    final first = BattleResult(
      matchup: ArcadeMatchups.boss(stage, 1, playerName: '우현'),
      myReps: 10,
      myInvalidReps: 0,
      opponentReps: 5,
      endedAt: DateTime(2026, 11, 23),
    );
    const round = ArcadeRound(
      won: true,
      wonByKo: false,
      rejects: 0,
      longestCombo: 3,
      excellent: 2,
    );
    expect(arcade.bossRun, isNull);
    arcade.wonFirstRound(stage, first, round);
    expect(arcade.bossRun!.stage, stage);
    expect(arcade.bossRun!.first, same(first));
    expect(arcade.bossRun!.firstRound, round);
    arcade.endBossRun();
    expect(arcade.bossRun, isNull);
  });

  test('a stage asked for is taken once', () {
    arcade.request(9);
    expect(arcade.takeRequest(), 9);
    expect(arcade.takeRequest(), isNull);
  });

  group('ArcadeMatchups', () {
    test('a fight is its character at its AI level with its exercise', () {
      final stage = ArcadeCatalog.stage(8) as ArcadeFightStage;
      final matchup = ArcadeMatchups.fight(stage, playerName: '우현');
      expect(matchup.exercise, stage.exercise);
      expect(matchup.playerName, '우현');
      expect(matchup.opponent.characterId, stage.character);
      expect(matchup.opponent.pace, stage.aiLevel);
      expect(matchup.opponent.arcadeStage, 8);
      expect(matchup.opponent.arcadeRound, isNull);
    });

    test('a boss match is R1 push-ups and R2 squats against the owner', () {
      final stage = ArcadeCatalog.stage(6) as ArcadeBossStage;
      final first = ArcadeMatchups.boss(stage, 1, playerName: '우현');
      final second = ArcadeMatchups.boss(stage, 2, playerName: '우현');
      expect(first.exercise, ExerciseType.pushUp);
      expect(second.exercise, ExerciseType.squat);
      for (final (index, matchup) in [first, second].indexed) {
        expect(matchup.opponent.characterId, 'seal');
        expect(matchup.opponent.pace, ArcadeAiLevel.lv4);
        expect(matchup.opponent.arcadeStage, 6);
        expect(matchup.opponent.arcadeRound, index + 1);
      }
      expect(first.opponent.name, 'STAGE 6 R1 · 물렁범');
    });
  });

  group('ArcadeWords (P16 spec 4)', () {
    test('titles of a fight, a hold and a boss match', () {
      expect(ArcadeWords.title(ArcadeCatalog.stage(8)), '물렁범 · 스쿼트');
      expect(ArcadeWords.title(ArcadeCatalog.stage(1)), 'RepBot · 푸쉬업');
      expect(ArcadeWords.title(ArcadeCatalog.stage(9)), '펭뚱이 · 하이 플랭크');
      expect(ArcadeWords.title(ArcadeCatalog.stage(11)), '펭뚱이 · 의자 자세');
      expect(ArcadeWords.title(ArcadeCatalog.stage(6)), '보스 매치 · 물렁범');
    });

    test('tags and level chips', () {
      expect(ArcadeWords.stageTag(ArcadeCatalog.stage(8)), 'STAGE 8 · 2F');
      expect(ArcadeWords.levelChip(ArcadeCatalog.stage(8)), 'AI LV 6');
      expect(ArcadeWords.levelChip(ArcadeCatalog.stage(6)), 'AI LV 4');
      expect(ArcadeWords.levelChip(ArcadeCatalog.stage(3)), isNull);
    });

    test('character names come from the character rig', () {
      expect(ArcadeWords.characterName('kangaroo'), '그루');
      expect(ArcadeWords.characterName('bot'), 'RepBot');
    });
  });

  group('finishBattle: what a battle comes to (P16 spec 6 and 7)', () {
    setUp(() async {
      store.hold = false;
      store.saved[1] = _progress([1, 1, 1, 1, 1, 1, 1]);
      await arcade.load(1);
    });

    BattleResult battle(
      Matchup matchup, {
      required bool won,
      bool ko = false,
    }) => BattleResult(
      matchup: matchup,
      myReps: 10,
      myInvalidReps: 0,
      opponentReps: 6,
      myScore: won ? 150 : 80,
      opponentScore: won ? 80 : 150,
      decidedOutcome: won ? MatchOutcome.win : MatchOutcome.lose,
      end: ko ? GameEnd.ko : GameEnd.timeUp,
      endedAt: DateTime(2026, 11, 23),
    );

    final fight = ArcadeCatalog.stage(8) as ArcadeFightStage;
    final boss = ArcadeCatalog.stage(6) as ArcadeBossStage;

    test('a fight won ends with its stars, and keeps them', () async {
      final result = battle(
        ArcadeMatchups.fight(fight, playerName: '우현'),
        won: true,
        ko: true,
      );
      final outcome = arcade.finishBattle(result, passDepth: 0.5);
      expect(outcome, isA<ArcadeStageEnded>());
      final ended = outcome as ArcadeStageEnded;
      expect(ended.stage, fight);
      expect(ended.rounds, [result]);
      expect(ended.stars, const ArcadeStars(true, false, true));
      await pumpEventQueue();
      expect(store.saved[1]!.bestOf(8), 2);
    });

    test('a fight lost ends without stars, and keeps nothing', () async {
      final outcome = arcade.finishBattle(
        battle(ArcadeMatchups.fight(fight, playerName: '우현'), won: false),
        passDepth: 0.5,
      );
      expect((outcome as ArcadeStageEnded).stars, ArcadeStars.none);
      await pumpEventQueue();
      expect(store.saved[1]!.bestOf(8), 0);
    });

    test('a boss match: R1 lost ends it, without stars', () {
      final outcome = arcade.finishBattle(
        battle(ArcadeMatchups.boss(boss, 1, playerName: '우현'), won: false),
        passDepth: 0.5,
      );
      final ended = outcome as ArcadeStageEnded;
      expect(ended.rounds, hasLength(1));
      expect(ended.stars, ArcadeStars.none);
      expect(arcade.bossRun, isNull);
    });

    test('R1 won goes to the break and keeps R1 for R2', () {
      final first = battle(
        ArcadeMatchups.boss(boss, 1, playerName: '우현'),
        won: true,
      );
      final outcome = arcade.finishBattle(first, passDepth: 0.5);
      expect(outcome, isA<ArcadeBossBreak>());
      expect((outcome as ArcadeBossBreak).first, same(first));
      expect(arcade.bossRun!.first, same(first));
      expect(arcade.bossRun!.firstRound.won, isTrue);
    });

    test(
      'R2 won after R1 ends the match with both rounds and its stars',
      () async {
        final first = battle(
          ArcadeMatchups.boss(boss, 1, playerName: '우현'),
          won: true,
          ko: true,
        );
        arcade.finishBattle(first, passDepth: 0.5);
        final second = battle(
          ArcadeMatchups.boss(boss, 2, playerName: '우현'),
          won: true,
          ko: true,
        );
        final ended =
            arcade.finishBattle(second, passDepth: 0.5) as ArcadeStageEnded;
        expect(ended.rounds, [first, second]);
        expect(ended.stars, const ArcadeStars(true, false, true));
        expect(arcade.bossRun, isNull);
        await pumpEventQueue();
        expect(store.saved[1]!.bestOf(6), 2);
      },
    );

    test('R2 lost ends the match without stars', () {
      arcade.finishBattle(
        battle(ArcadeMatchups.boss(boss, 1, playerName: '우현'), won: true),
        passDepth: 0.5,
      );
      final ended = arcade.finishBattle(
        battle(ArcadeMatchups.boss(boss, 2, playerName: '우현'), won: false),
        passDepth: 0.5,
      ) as ArcadeStageEnded;
      expect(ended.rounds, hasLength(2));
      expect(ended.stars, ArcadeStars.none);
    });

    test('R2 without R1 known, or of another boss, counts as left', () {
      expect(
        arcade.finishBattle(
          battle(ArcadeMatchups.boss(boss, 2, playerName: '우현'), won: true),
          passDepth: 0.5,
        ),
        isA<ArcadeBattleLeft>(),
      );
      final other = ArcadeCatalog.stage(12) as ArcadeBossStage;
      arcade.finishBattle(
        battle(ArcadeMatchups.boss(other, 1, playerName: '우현'), won: true),
        passDepth: 0.5,
      );
      expect(
        arcade.finishBattle(
          battle(ArcadeMatchups.boss(boss, 2, playerName: '우현'), won: true),
          passDepth: 0.5,
        ),
        isA<ArcadeBattleLeft>(),
      );
    });

    test('a battle outside the arcade counts as left', () {
      expect(
        arcade.finishBattle(
          battle(
            const Matchup(
              exercise: ExerciseType.pushUp,
              playerName: '우현',
              opponent: Opponent(name: 'AI 봇 · 고수', isBot: true),
            ),
            won: true,
          ),
          passDepth: 0.5,
        ),
        isA<ArcadeBattleLeft>(),
      );
    });
  });

  group('what the battle is handed (P16 spec 6)', () {
    final fight2F = ArcadeMatchups.fight(
      ArcadeCatalog.stage(8) as ArcadeFightStage,
      playerName: '우현',
    );

    test('rulesOf: the stage\'s floor\'s rules; outside the arcade the '
        'default', () {
      expect(ArcadeMatchups.rulesOf(fight2F).feverStart, Duration(seconds: 15));
      final fight3F = ArcadeMatchups.fight(
        ArcadeCatalog.stage(14) as ArcadeFightStage,
        playerName: '우현',
      );
      expect(
        ArcadeMatchups.rulesOf(fight3F).comboBonus,
        battleRules.comboBonus * 2,
      );
      final boss4F = ArcadeMatchups.boss(
        ArcadeCatalog.stage(24) as ArcadeBossStage,
        1,
        playerName: '우현',
      );
      expect(
        ArcadeMatchups.rulesOf(boss4F).excellentPoints,
        battleRules.excellentPoints * 2,
      );
      const plain = Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'AI 봇 · 고수', isBot: true),
      );
      expect(ArcadeMatchups.rulesOf(plain), same(battleRules));
    });

    test(
      'botOf: the stage\'s AI level; outside the arcade the chosen level',
      () {
        expect(
          ArcadeMatchups.botOf(fight2F, passDepth: 0.5).difficulty,
          ArcadeAiLevel.lv6,
        );
        const plain = Matchup(
          exercise: ExerciseType.squat,
          playerName: '우현',
          opponent: Opponent(
            name: 'AI 봇 · 중수',
            isBot: true,
            difficulty: BotDifficulty.intermediate,
          ),
        );
        final bot = ArcadeMatchups.botOf(plain, passDepth: 0.5);
        expect(bot.difficulty, BotDifficulty.intermediate);
        expect(bot.passDepth, 0.5);
      },
    );

    test('battleOf: the battle of the stage, by its floor\'s rules, with the '
        'setup and the user\'s character', () {
      final counter = RepCounterViewModel(
        camera: FakeCameraService(),
        estimator: FakePoseEstimator(),
        exercise: fight2F.exercise,
        roundLength: const Duration(days: 1),
      );
      final battle = ArcadeMatchups.battleOf(
        fight2F,
        counter: counter,
        repository: FakeUserRepository(),
        sound: FakeRepSound(),
        characterId: 'kangaroo',
      );
      addTearDown(battle.dispose);
      expect(battle.matchup, same(fight2F));
      expect(battle.rules.feverStart, const Duration(seconds: 15));
      expect(battle.characterId, 'kangaroo');
      expect(battle.roundLength, battleDuration);
    });
  });

  test('nothing is heard after dispose', () async {
    final load = arcade.load(1);
    arcade.dispose();
    store.answer(1, ArcadeProgress.initial());
    await load;
    arcade = ArcadeViewModel(store: store);
  });
}
