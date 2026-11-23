import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_progress.dart';
import '../models/arcade_stage.dart';
import '../models/battle_result.dart';
import '../models/battle_rules.dart';
import '../models/character_rig.dart';
import '../models/exercise_type_korean.dart';
import '../models/matchup.dart';
import '../services/arcade/arcade_progress_store.dart';
import '../services/arcade/arcade_star_judge.dart';
import '../services/device/device_controls.dart';
import '../services/feedback/form_report_store.dart';
import '../services/opponent/bot_opponent.dart';
import '../services/pose/setup_checker.dart';
import '../services/user/user_repository.dart';
import 'battle_viewmodel.dart';
import 'rep_counter_viewmodel.dart';

/// The signed-in account's arcade (P16): its progress, read from the
/// [ArcadeProgressStore] and kept up to date as stages are played, the boss
/// match being played, and the stage the map is asked to open next.
///
/// One for the whole app, like the account's character, so the map and the
/// screens of a stage (which the navigator puts beside it, not under it)
/// share it.
class ArcadeViewModel extends ChangeNotifier {
  ArcadeViewModel({required this._store});

  final ArcadeProgressStore _store;

  int? _accountId;
  ArcadeProgress? _progress;

  /// Counts the reads, so one that answers after a newer one, or after the
  /// account changed, is dropped.
  int _reads = 0;

  ArcadeBossRun? _bossRun;
  int? _requested;
  bool _disposed = false;

  /// Where the progress is kept; A4's hold screens keep their stars there.
  ArcadeProgressStore get store => _store;

  /// The account whose arcade this is; null when signed out.
  int? get accountId => _accountId;

  /// The account's progress; null until it has been read (P16 spec 9: the
  /// map waits without it).
  ArcadeProgress? get progress => _progress;

  /// The boss match whose first round was won, until its second ends.
  ArcadeBossRun? get bossRun => _bossRun;

  /// Reads [accountId]'s progress. The previous account's is gone at once.
  /// A store that cannot be read gives the first state, as a new account.
  Future<void> load(int accountId) {
    _accountId = accountId;
    _progress = null;
    _bossRun = null;
    _requested = null;
    _notify();
    return refresh();
  }

  /// Reads the progress again, showing the one it has meanwhile.
  Future<void> refresh() async {
    final accountId = _accountId;
    if (accountId == null) return;
    final read = ++_reads;
    ArcadeProgress progress;
    try {
      progress = await _store.read(accountId);
    } on Object {
      progress = _progress ?? ArcadeProgress.initial();
    }
    if (_disposed || read != _reads || accountId != _accountId) return;
    _progress = progress;
    _notify();
  }

  /// Signed out: nothing to show.
  void clear() {
    _accountId = null;
    _progress = null;
    _bossRun = null;
    _requested = null;
    _reads += 1;
    _notify();
  }

  /// Keeps [stars] for stage [number] (A2's store keeps the most a stage
  /// ever got) and shows the progress after it. A store that fails leaves
  /// the progress shown as it was.
  Future<void> record(int number, ArcadeStars stars) async {
    final accountId = _accountId;
    if (accountId == null) return;
    _reads += 1;
    try {
      final after = await _store.recordStage(accountId, number, stars.count);
      if (_disposed || accountId != _accountId) return;
      _progress = after;
      _notify();
    } on Object {
      // The play is lost; the map shows what it had.
    }
  }

  /// What arcade battle [result] comes to (P16 spec 6 and 7): its round
  /// read for the stars with A2's judge ([passDepth] is the user's
  /// judge's), the stars kept when there are any, and the boss match
  /// carried from R1 to R2.
  ///
  /// A fight ends. A boss match's R1 won goes to the break; lost, the
  /// match ends there. R2 ends the match with R1's round; without R1
  /// known (the account signed out meanwhile) the match counts as left.
  ArcadeBattleOutcome finishBattle(
    BattleResult result, {
    required double passDepth,
  }) {
    final opponent = result.matchup.opponent;
    final number = opponent.arcadeStage;
    if (number == null) return const ArcadeBattleLeft();
    final stage = ArcadeCatalog.stage(number);
    final round = ArcadeRound.fromBattle(
      result,
      passDepth: passDepth,
      rules: ArcadeCatalog.floorOf(stage).rules,
    );
    switch (stage) {
      case ArcadeFightStage():
        final stars = ArcadeStarJudge.fight(stage, round);
        _keep(stage, stars);
        return ArcadeStageEnded(stage: stage, rounds: [result], stars: stars);
      case ArcadeBossStage() when opponent.arcadeRound == 1:
        if (!round.won) {
          endBossRun();
          return ArcadeStageEnded(
            stage: stage,
            rounds: [result],
            stars: ArcadeStars.none,
          );
        }
        wonFirstRound(stage, result, round);
        return ArcadeBossBreak(stage: stage, first: result);
      case ArcadeBossStage():
        final run = _bossRun;
        endBossRun();
        if (run == null || run.stage.number != stage.number) {
          return const ArcadeBattleLeft();
        }
        final stars = ArcadeStarJudge.boss(stage, run.firstRound, round);
        _keep(stage, stars);
        return ArcadeStageEnded(
          stage: stage,
          rounds: [run.first, result],
          stars: stars,
        );
      case ArcadeHoldStage():
        return const ArcadeBattleLeft();
    }
  }

  /// Keeps a play's stars; a play without one changes nothing.
  void _keep(ArcadeStage stage, ArcadeStars stars) {
    if (stars.cleared) unawaited(record(stage.number, stars));
  }

  /// The boss match [stage]'s first round, won as [first] and read for the
  /// stars as [firstRound]: kept for the second round's end.
  void wonFirstRound(
    ArcadeBossStage stage,
    BattleResult first,
    ArcadeRound firstRound,
  ) => _bossRun = ArcadeBossRun(
    stage: stage,
    first: first,
    firstRound: firstRound,
  );

  /// The boss match is over, or left.
  void endBossRun() => _bossRun = null;

  /// Asks the map to open stage [number] once it shows again: 다음 스테이지
  /// and "{n}층으로" go back to the map, which then opens it.
  void request(int number) => _requested = number;

  /// The stage asked for, once: the map opens it and it is gone.
  int? takeRequest() {
    final requested = _requested;
    _requested = null;
    return requested;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A boss match between its rounds: the stage and its first round, won.
class ArcadeBossRun {
  const ArcadeBossRun({
    required this.stage,
    required this.first,
    required this.firstRound,
  });

  final ArcadeBossStage stage;

  /// The first round as played, for its row and its report.
  final BattleResult first;

  /// The first round as the stars read it (its own exercise's depth).
  final ArcadeRound firstRound;
}

/// What an arcade battle came to ([ArcadeViewModel.finishBattle]).
sealed class ArcadeBattleOutcome {
  const ArcadeBattleOutcome();
}

/// The stage is over: a fight, or a boss match won or lost. [rounds] are
/// its battles, the last the one just ended; [stars] are the play's.
final class ArcadeStageEnded extends ArcadeBattleOutcome {
  const ArcadeStageEnded({
    required this.stage,
    required this.rounds,
    required this.stars,
  });

  final ArcadeStage stage;
  final List<BattleResult> rounds;
  final ArcadeStars stars;
}

/// A boss match's R1 won: the break before R2.
final class ArcadeBossBreak extends ArcadeBattleOutcome {
  const ArcadeBossBreak({required this.stage, required this.first});

  final ArcadeBossStage stage;
  final BattleResult first;
}

/// Nothing to show: back to the map, without stars.
final class ArcadeBattleLeft extends ArcadeBattleOutcome {
  const ArcadeBattleLeft();
}

/// The battles of the arcade's stages, for the versus and battle screens.
abstract final class ArcadeMatchups {
  /// The score rules [matchup] is played by (P16 spec 6): its stage's
  /// floor's; outside the arcade the default ones.
  static BattleRules rulesOf(Matchup matchup) =>
      switch (matchup.opponent.arcadeStage) {
        final stage? => ArcadeCatalog.floorOf(ArcadeCatalog.stage(stage)).rules,
        null => battleRules,
      };

  /// The bot of [matchup]: at its arcade AI level (P16 spec 6), otherwise
  /// as [BotOpponent.forMatchup] makes it. [passDepth] is the user's
  /// judge's.
  static BotOpponent botOf(Matchup matchup, {required double passDepth}) =>
      switch (matchup.opponent.pace) {
        final pace? => BotOpponent(passDepth: passDepth, difficulty: pace),
        null => BotOpponent.forMatchup(matchup, passDepth: passDepth),
      };

  /// An arcade stage's battle (P16 spec 6): as `BattleViewModel.bot` makes
  /// it, but with the bot of [botOf] and the rules of [rulesOf]. Only the
  /// values handed to the battle change. The clock stands in for the
  /// phone's own in tests.
  static BattleViewModel battleOf(
    Matchup matchup, {
    required RepCounterViewModel counter,
    required UserRepository repository,
    required RepSound sound,
    FormReportStore? formReports,
    String? characterId,
    Clock? clock,
  }) => BattleViewModel(
    matchup: matchup,
    counter: counter,
    opponent: botOf(matchup, passDepth: counter.passDepth),
    repository: repository,
    sound: sound,
    formReports: formReports,
    rules: rulesOf(matchup),
    setup: SetupChecker(exercise: matchup.exercise, clock: clock),
    characterId: characterId,
    clock: clock,
  );

  /// Fight stage [stage] for the user [playerName]: its character, at its
  /// AI level, with its exercise.
  static Matchup fight(ArcadeFightStage stage, {required String playerName}) =>
      Matchup(
        exercise: stage.exercise,
        playerName: playerName,
        opponent: Opponent.arcade(
          stage: stage.number,
          characterId: stage.character,
          pace: stage.aiLevel,
        ),
      );

  /// Round [round] (1 or 2) of boss match [stage]: the floor's owner as a
  /// fighter, at the stage's AI level, with the round's exercise.
  static Matchup boss(
    ArcadeBossStage stage,
    int round, {
    required String playerName,
  }) => Matchup(
    exercise: stage.rounds[round - 1],
    playerName: playerName,
    opponent: Opponent.arcade(
      stage: stage.number,
      round: round,
      characterId: stage.character,
      pace: stage.aiLevel,
    ),
  );
}

/// The words the arcade's screens say about its stages (P16 spec 4), from
/// A2's data.
abstract final class ArcadeWords {
  /// A character's name on screen: "물렁범", "RepBot".
  static String characterName(String id) => CharacterRig.standard.art(id).name;

  /// A stage's title: a fight "{opponent} · {exercise}", a hold "{owner} ·
  /// {pose}", a boss match "보스 매치 · {owner}".
  static String title(ArcadeStage stage) {
    final owner = ArcadeCatalog.floorOf(stage).ownerName;
    return switch (stage) {
      ArcadeFightStage(:final character, :final exercise) =>
        '${characterName(character)} · ${exercise.koreanName}',
      ArcadeHoldStage(:final pose) => '$owner · ${pose.label}',
      ArcadeBossStage() => '보스 매치 · $owner',
    };
  }

  /// "STAGE 8 · 2F".
  static String stageTag(ArcadeStage stage) =>
      'STAGE ${stage.number} · ${stage.floor}F';

  /// "AI LV 6" for a fight or a boss match; null for a hold.
  static String? levelChip(ArcadeStage stage) => switch (stage) {
    ArcadeFightStage(:final aiLevel) ||
    ArcadeBossStage(:final aiLevel) => 'AI LV ${aiLevel.level}',
    ArcadeHoldStage() => null,
  };
}
