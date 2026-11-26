import 'skill_matchmaker.dart';

/// The opponent a player gets when no real player came in time (P10): a
/// simulated player that copies the account whose skill is closest to the
/// player's, under that account's nickname.
///
/// The battle itself runs on the phone, as an AI battle at [expectedReps],
/// so only the player's own record keeps it; the copied account's never
/// does.
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

  /// The fewest and most reps the phone may be asked to play.
  static const minReps = 1, maxReps = 60;

  /// The copied account's nickname, or [fallbackName].
  final String displayName;

  /// The valid reps it plays for: the copied account's estimate, rounded.
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

  /// The `match.virtual` payload: what the phone needs to play it.
  Map<String, dynamic> toPayload(String exercise) => {
    'exercise': exercise,
    'opponent': {'display_name': displayName, 'expected_reps': expectedReps},
  };
}
