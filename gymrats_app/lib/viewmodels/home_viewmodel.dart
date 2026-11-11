import 'package:flutter/foundation.dart';

import '../models/bot_difficulty.dart';
import '../models/exercise_type.dart';
import '../models/match_record.dart';
import '../models/user_profile.dart';
import '../services/api/api_client.dart';
import '../services/user/user_repository.dart';
import 'login_viewmodel.dart';

/// What the home screen is showing.
enum HomePhase {
  /// Fetching the profile.
  loading,

  /// The profile is shown.
  ready,

  /// Loading failed; the user can retry.
  failed,
}

/// How a battle is set up: the exercise, and the bot's level for a battle
/// with the bot.
@immutable
class BattleSetup {
  const BattleSetup({required this.exercise, this.difficulty});

  /// The setup of [match]: a battle with the bot when the opponent is one of
  /// its levels, an online battle otherwise.
  ///
  /// A record keeps no mode, only the opponent's name, so a person who took
  /// a bot's name (e.g. "RepBot") reads as that bot.
  factory BattleSetup.of(MatchRecord match) => BattleSetup(
    exercise: match.exercise,
    difficulty: _botLevelNamed(match.opponentName),
  );

  /// The bot from before there were levels saved its battles under this
  /// name; it played like [BotDifficulty.expert].
  static const _oldBotName = 'RepBot';

  static BotDifficulty? _botLevelNamed(String opponentName) =>
      opponentName == _oldBotName
      ? BotDifficulty.expert
      : BotDifficulty.values
            .where((level) => level.opponentName == opponentName)
            .firstOrNull;

  final ExerciseType exercise;

  /// The bot's level; null for an online battle.
  final BotDifficulty? difficulty;

  bool get isOnline => difficulty == null;

  @override
  bool operator ==(Object other) =>
      other is BattleSetup &&
      other.exercise == exercise &&
      other.difficulty == difficulty;

  @override
  int get hashCode => Object.hash(exercise, difficulty);
}

/// Immutable state rendered by the home lobby and the pages it opens.
class HomeState {
  const HomeState({
    this.phase = HomePhase.loading,
    this.profile,
    this.errorMessage,
    this.botExercise = ExerciseType.pushUp,
    this.botLevel = BotDifficulty.intermediate,
  });

  final HomePhase phase;

  /// The last loaded profile; null until a load succeeds.
  final UserProfile? profile;

  /// Why the load failed, e.g. no network; null for the default message.
  final String? errorMessage;

  /// What the AI 1v1 page has chosen so far: push-ups against 중수 at first.
  final ExerciseType botExercise;
  final BotDifficulty botLevel;

  /// [botExercise] against [botLevel].
  BattleSetup get botSetup =>
      BattleSetup(exercise: botExercise, difficulty: botLevel);

  /// The setup of the latest battle, to play it again; null before the
  /// first battle.
  BattleSetup? get lastSetup => switch (profile?.lastMatch) {
    final match? => BattleSetup.of(match),
    null => null,
  };

  HomeState copyWith({
    HomePhase? phase,
    UserProfile? profile,
    String? errorMessage,
    ExerciseType? botExercise,
    BotDifficulty? botLevel,
  }) => HomeState(
    phase: phase ?? this.phase,
    profile: profile ?? this.profile,
    errorMessage: errorMessage ?? this.errorMessage,
    botExercise: botExercise ?? this.botExercise,
    botLevel: botLevel ?? this.botLevel,
  );
}

/// Loads the user's profile for the home lobby, and keeps what the AI 1v1
/// page has chosen.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required this._repository});

  final UserRepository _repository;

  HomeState _state = const HomeState();
  bool _fetching = false;
  bool _disposed = false;

  HomeState get state => _state;

  /// Fetches the profile. Does nothing while a fetch is running.
  ///
  /// The first load shows the loading state, and the failed state on an
  /// [Exception] from the repository. A reload keeps the profile on screen
  /// until the new one arrives, and keeps it if the reload fails. The
  /// profile load sends queued battles first, so its latest battle and
  /// bests include them.
  Future<void> load() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    final reloading = _state.profile != null;
    if (!reloading) _setState(_state.copyWith(phase: HomePhase.loading));
    try {
      final profile = await _repository.fetchProfile();
      _setState(_state.copyWith(phase: HomePhase.ready, profile: profile));
    } on Exception catch (e) {
      if (!reloading) {
        _setState(
          _state.copyWith(
            phase: HomePhase.failed,
            errorMessage: e is ApiException ? e.message : genericErrorMessage,
          ),
        );
      }
    } finally {
      _fetching = false;
    }
  }

  /// The exercise for the battle with the bot.
  void chooseBotExercise(ExerciseType exercise) =>
      _setState(_state.copyWith(botExercise: exercise));

  /// The bot's level.
  void chooseBotLevel(BotDifficulty level) =>
      _setState(_state.copyWith(botLevel: level));

  void _setState(HomeState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
