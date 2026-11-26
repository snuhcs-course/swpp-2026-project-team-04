import 'dart:math';

import '../../gymrats_app/lib/models/game_score.dart';
import 'skill_matchmaker.dart';

/// The opponent a player gets when no real player came in time (P10): a
/// simulated player that copies the account whose skill is closest to the
/// player's, under that account's nickname.
///
/// The battle server plays it as a player of the match, so the player's
/// phone sees what a real opponent shows: its setup and ready, its reps and
/// their points, and the same result. Only the player's record keeps the
/// battle; the copied account's never does.
class SimulatedPlayer {
  const SimulatedPlayer({
    required this.displayName,
    required this.expectedReps,
    required this.playerSkill,
    this.copiedId,
  });

  /// The name shown when nobody can be copied (no other account has a
  /// battle of the exercise yet).
  static const fallbackName = 'RepBot';

  /// The fewest and most valid reps it plans in a round.
  static const minReps = 1, maxReps = 60;

  /// The battle server's ids for simulated players start with this; a real
  /// account's id is a number.
  static const idPrefix = 'sim-';

  /// Whether [playerId] is a simulated player's.
  static bool isSimulatedId(String playerId) => playerId.startsWith(idPrefix);

  /// The copied account's nickname, or [fallbackName].
  final String displayName;

  /// The valid reps it plays for in a full round: the copied account's
  /// estimate, rounded.
  final int expectedReps;

  /// The player's own estimate, which chose it.
  final double playerSkill;

  /// The copied account; never sent to the phone.
  final String? copiedId;

  /// The simulated opponent for [playerId] in [exercise], from [index].
  factory SimulatedPlayer.forPlayer(
    SkillIndex index, {
    required String playerId,
    required String exercise,
  }) {
    final skill = index.estimateOf(playerId, exercise);
    final copied = index.nearest(exercise, skill, excludeId: playerId);
    return SimulatedPlayer(
      displayName: copied?.name ?? fallbackName,
      expectedReps: (copied?.skill ?? skill).round().clamp(minReps, maxReps),
      playerSkill: skill,
      copiedId: copied?.id,
    );
  }

  /// The first rep cannot close before this into the round.
  static const _firstRepMs = 1500;

  /// Kept free at the end, so the last rep still lands inside the round.
  static const _endMarginMs = 1200;

  /// About this share of the valid reps go deep enough to be excellent.
  static const excellentShare = 0.15;

  /// The round's reps, as `rep.submit` payloads in order: [expectedReps]
  /// valid ones give or take one, and up to two too shallow, spread over a
  /// round of [durationMs] with a little jitter.
  List<Map<String, dynamic>> planReps(
    Random random, {
    required int durationMs,
  }) {
    final valid = (expectedReps + random.nextInt(3) - 1).clamp(
      minReps,
      maxReps,
    );
    final rejected = random.nextInt(3);
    final count = valid + rejected;
    final kinds = [for (var i = 0; i < count; i++) i < rejected]
      ..shuffle(random);
    // A round too short for the margins (tests) uses all of it.
    final roomy = durationMs > _firstRepMs + _endMarginMs;
    final start = roomy ? _firstRepMs : 0;
    final end = roomy ? durationMs - _endMarginMs : durationMs;
    final slot = (end - start) / count;
    final plan = <Map<String, dynamic>>[];
    var last = 0;
    for (var i = 0; i < count; i++) {
      final jitter = (random.nextDouble() - .5) * slot * .6;
      var at = (start + slot * (i + .5) + jitter).round();
      // In order, and inside the round.
      at = max(at, last + 1).clamp(0, durationMs - 1);
      last = at;
      final isValid = !kinds[i];
      plan.add({
        'rep_seq': i + 1,
        'elapsed_ms': at,
        'valid': isValid,
        'reason': isValid ? null : 'insufficient_depth',
        'grade': isValid
            ? (random.nextDouble() < excellentShare
                      ? GameGrade.excellent
                      : GameGrade.good)
                  .name
            : null,
      });
    }
    return plan;
  }
}
