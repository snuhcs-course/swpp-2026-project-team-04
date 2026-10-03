import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/exercise_type.dart';
import '../models/matchup.dart';
import '../services/matching/matchmaker.dart';
import '../services/pose/setup_checker.dart' show Clock;
import '../services/user/user_repository.dart';

/// What the matching screen is showing.
enum MatchingPhase {
  /// Looking for an opponent.
  searching,

  /// An opponent was found; [MatchingState.matchup] is set.
  found,

  /// The search failed; the user can retry.
  failed,
}

/// Immutable state rendered by the matching screen.
class MatchingState {
  const MatchingState({
    this.phase = MatchingPhase.searching,
    this.elapsed = Duration.zero,
    this.playerName,
    this.matchup,
  });

  final MatchingPhase phase;

  /// Time since the search started, in whole seconds.
  final Duration elapsed;

  /// The user's name for the avatar; null until the profile is loaded.
  final String? playerName;

  /// The battle to start; set once [phase] is [MatchingPhase.found].
  final Matchup? matchup;

  MatchingState copyWith({
    MatchingPhase? phase,
    Duration? elapsed,
    String? playerName,
    Matchup? matchup,
  }) => MatchingState(
    phase: phase ?? this.phase,
    elapsed: elapsed ?? this.elapsed,
    playerName: playerName ?? this.playerName,
    matchup: matchup ?? this.matchup,
  );
}

/// Finds an opponent for the matching screen and counts the time spent.
///
/// Reads the user's name first, then asks the [Matchmaker]. Both go into
/// the [Matchup] that the screen passes on.
class MatchingViewModel extends ChangeNotifier {
  MatchingViewModel({
    required this._matchmaker,
    required this._repository,
    required this.exercise,
    Clock? clock,
  }) : _clock = clock ?? _stopwatchClock();

  final Matchmaker _matchmaker;
  final UserRepository _repository;
  final ExerciseType exercise;
  final Clock _clock;

  MatchingState _state = const MatchingState();

  /// Incremented whenever a search stops, so late results are ignored.
  int _session = 0;
  bool _disposed = false;
  Timer? _ticker;
  Duration _startedAt = Duration.zero;

  static Clock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  MatchingState get state => _state;

  /// Starts a search, counting the elapsed time from zero. An [Exception]
  /// from the repository or the matchmaker shows the failed state.
  Future<void> start() async {
    if (_disposed) return;
    final session = ++_session;
    _startTicker();
    // The name stays through a retry, so the avatar does not flicker.
    _setState(MatchingState(playerName: _state.playerName));
    try {
      final profile = await _repository.fetchProfile();
      if (session != _session) return;
      _setState(_state.copyWith(playerName: profile.name));
      final opponent = await _matchmaker.findOpponent(exercise);
      if (session != _session) return;
      _stopTicker();
      _setState(
        _state.copyWith(
          phase: MatchingPhase.found,
          matchup: Matchup(
            exercise: exercise,
            playerName: profile.name,
            opponent: opponent,
          ),
        ),
      );
    } on Exception {
      if (session != _session) return;
      _stopTicker();
      _setState(_state.copyWith(phase: MatchingPhase.failed));
    }
  }

  /// Searches again after a failure.
  Future<void> retry() => start();

  /// Stops the search when the user leaves. A result arriving later is
  /// ignored.
  void cancel() {
    _session++;
    _stopTicker();
  }

  void _startTicker() {
    _startedAt = _clock();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final elapsed = Duration(seconds: (_clock() - _startedAt).inSeconds);
    if (elapsed != _state.elapsed) _setState(_state.copyWith(elapsed: elapsed));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _setState(MatchingState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
