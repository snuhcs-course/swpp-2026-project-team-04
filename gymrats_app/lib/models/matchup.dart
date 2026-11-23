import 'bot_difficulty.dart';
import 'character_rig.dart';
import 'exercise_type.dart';

/// Who the user battles against.
class Opponent {
  const Opponent({
    required this.name,
    required this.isBot,
    this.difficulty,
    this.characterId,
    this.pace,
    this.arcadeStage,
    this.arcadeRound,
  });

  /// An arcade stage's opponent (P16): a bot drawn as [characterId] that
  /// plays at [pace], in stage [stage] and, in a boss match, round [round]
  /// (1 or 2). Its [name], the one the battle's record keeps, says the stage
  /// ([arcadeName]); screens that show the opponent itself use
  /// [characterName].
  factory Opponent.arcade({
    required int stage,
    int? round,
    required String characterId,
    required BotPace pace,
  }) => Opponent(
    name: arcadeName(stage, round, _nameOf(characterId)),
    isBot: true,
    characterId: characterId,
    pace: pace,
    arcadeStage: stage,
    arcadeRound: round,
  );

  /// e.g. "AI 봇 · 초보"; an arcade opponent's is "STAGE 8 · 물렁범".
  final String name;

  /// Whether the opponent is an AI. Screens tag it with "AI".
  final bool isBot;

  /// How hard a bot plays; null for a person, and for a bot no level was
  /// chosen for, which plays as an expert.
  final BotDifficulty? difficulty;

  /// The character the opponent is drawn as (a `CharacterRig` id); null
  /// draws a bot as RepBot.
  final String? characterId;

  /// How a bot plays when it is not one of the AI 1v1 levels: an arcade AI
  /// level. Null plays as [difficulty] says.
  final BotPace? pace;

  /// The arcade stage this battle is, from 1 to 24; null outside the
  /// arcade.
  final int? arcadeStage;

  /// In an arcade boss match, the round: 1 (push-ups) or 2 (squats).
  final int? arcadeRound;

  /// Whether this is an arcade battle.
  bool get isArcade => arcadeStage != null;

  /// The name to show for the opponent itself: an arcade opponent's
  /// character name ("물렁범"), any other opponent's [name].
  String get characterName => switch ((arcadeStage, characterId)) {
    (_?, final id?) => _nameOf(id),
    _ => name,
  };

  static String _nameOf(String characterId) =>
      CharacterRig.standard.art(characterId).name;

  /// The name an arcade battle keeps in its record and report (P16 spec
  /// 13.3): "STAGE 8 · 물렁범", and with the round in a boss match,
  /// "STAGE 6 R1 · 물렁범".
  static String arcadeName(int stage, int? round, String characterName) =>
      'STAGE $stage${round == null ? '' : ' R$round'} · $characterName';

  /// Whether [name] is one [arcadeName] makes: a past battle keeps only its
  /// opponent's name.
  static bool isArcadeName(String name) => _arcadeName.hasMatch(name);

  static final _arcadeName = RegExp(r'^STAGE \d+( R[12])? · .+$');

  /// This opponent at [difficulty]: a bot takes that level and its name, and a
  /// person stays as they are.
  Opponent at(BotDifficulty difficulty) => isBot
      ? Opponent(
          name: difficulty.opponentName,
          isBot: true,
          difficulty: difficulty,
        )
      : this;
}

/// What home or the result screen asks the matching screen to find: its route
/// argument.
class BotMatchRequest {
  const BotMatchRequest({required this.exercise, required this.difficulty});

  final ExerciseType exercise;
  final BotDifficulty difficulty;
}

/// A battle about to start, seen from the user's side: the exercise, the
/// user, and the opponent.
///
/// MatchingScreen builds it when an opponent is found. The versus screen and
/// the battle screen receive it as their route argument.
class Matchup {
  const Matchup({
    required this.exercise,
    required this.playerName,
    required this.opponent,
  });

  final ExerciseType exercise;

  /// The user's name, e.g. "우현".
  final String playerName;

  final Opponent opponent;

  /// The same battle again: the same exercise and the same difficulty.
  BotMatchRequest get rematch => BotMatchRequest(
    exercise: exercise,
    difficulty: opponent.difficulty ?? BotDifficulty.expert,
  );
}
