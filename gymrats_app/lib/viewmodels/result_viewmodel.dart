import 'package:flutter/foundation.dart';

import '../models/battle_result.dart';
import '../models/exercise_type.dart';
import '../models/feedback_stats.dart';
import '../models/form_report.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../models/matchup.dart';
import '../services/feedback/feedback_stats.dart';
import '../services/feedback/form_analyzer.dart';
import '../services/user/user_repository.dart';

/// Where the result report's comparison with earlier battles stands.
enum ResultHistoryPhase {
  /// The earlier battles are loading; the screen shows the top part first.
  loading,

  /// [ResultState.previousBest] and the recent values are filled in (they
  /// stay null or empty when there were no earlier battles).
  ready,

  /// The earlier battles could not be loaded; the screen leaves that part
  /// out.
  failed,
}

/// The one thing to try next battle: the first issue's fix.
class NextTip {
  const NextTip({required this.headline, this.detail, this.code});

  /// How to fix it, from the form analyzer, e.g. "가슴이 바닥에 가까워질 때까지
  /// 내려간 뒤 올라와요.".
  final String headline;

  /// What the issue was, e.g. "깊이 부족 2회"; null when there is no title.
  final String? detail;

  /// The issue's stable code, as in [FormFinding.code].
  final String? code;
}

/// Everything the result report shows of one battle. Numbers stay in their
/// own units, and the screen picks the words.
class ResultState {
  const ResultState({
    required this.endedAt,
    required this.outcome,
    required this.exercise,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.myReps,
    this.end,
    this.opponent,
    this.isOnline,
    this.roundLength,
    this.myInvalidReps,
    this.opponentLeft = false,
    this.history = ResultHistoryPhase.loading,
    this.previousBest,
    this.isNewBest = false,
    this.recentScores = const [],
    this.recentFrom,
    this.recentAverage,
    this.recentAverageOf = 0,
    this.form,
    this.nextTip,
    this.rematch,
  });

  /// When the battle ended.
  final DateTime endedAt;
  final MatchOutcome outcome;

  /// KO or time up; null for an online forfeit or disconnect, or a past
  /// battle the server did not say for.
  final GameEnd? end;
  final ExerciseType exercise;

  /// The opponent of a battle just played (a bot carries its difficulty);
  /// null for a past battle, which keeps only [opponentName].
  final Opponent? opponent;
  final String opponentName;

  /// Online 1v1 (true) or against the bot (false); null when not known.
  final bool? isOnline;

  /// How long the round was (shorter after a KO); null for a past battle
  /// without a form report.
  final Duration? roundLength;

  /// The big numbers: game scores, or counted reps for a battle saved
  /// before scores were kept.
  final int myScore;
  final int opponentScore;

  /// The user's counted reps.
  final int myReps;

  /// The user's rejected reps; null for a past battle without feedback.
  final int? myInvalidReps;

  /// An online battle won because the opponent forfeited or dropped out.
  final bool opponentLeft;

  final ResultHistoryPhase history;

  /// Best score of the same exercise before this battle; null for the
  /// first battle, or while [history] is not ready.
  final int? previousBest;

  /// This battle beat [previousBest]. False when there is none.
  final bool isNewBest;

  /// Scores of the same exercise, oldest first, this battle last: at most
  /// 8. Empty while [history] is not ready.
  final List<int> recentScores;

  /// When the first battle of [recentScores] was played.
  final DateTime? recentFrom;

  /// Mean score, rounded, of the up to 5 battles of the same exercise just
  /// before this one; null when there were none.
  final int? recentAverage;

  /// How many battles [recentAverage] is over (0 to 5).
  final int recentAverageOf;

  /// The battle's form report; null hides the feedback button and the tip.
  final FormReport? form;

  /// The first thing to fix in [form]; null when there is nothing to fix.
  final NextTip? nextTip;

  /// The same bot battle again; null online and for a past battle.
  final BotMatchRequest? rematch;

  ResultState copyWith({
    ResultHistoryPhase? history,
    int? previousBest,
    bool? isNewBest,
    List<int>? recentScores,
    DateTime? recentFrom,
    int? recentAverage,
    int? recentAverageOf,
    FormReport? form,
    NextTip? nextTip,
    Duration? roundLength,
  }) => ResultState(
    endedAt: endedAt,
    outcome: outcome,
    end: end,
    exercise: exercise,
    opponent: opponent,
    opponentName: opponentName,
    isOnline: isOnline,
    roundLength: roundLength ?? this.roundLength,
    myScore: myScore,
    opponentScore: opponentScore,
    myReps: myReps,
    myInvalidReps: myInvalidReps,
    opponentLeft: opponentLeft,
    history: history ?? this.history,
    previousBest: previousBest ?? this.previousBest,
    isNewBest: isNewBest ?? this.isNewBest,
    recentScores: recentScores ?? this.recentScores,
    recentFrom: recentFrom ?? this.recentFrom,
    recentAverage: recentAverage ?? this.recentAverage,
    recentAverageOf: recentAverageOf ?? this.recentAverageOf,
    form: form ?? this.form,
    nextTip: nextTip ?? this.nextTip,
    rematch: rematch,
  );
}

/// The result report of a battle just played ([ResultViewModel.battle], bot
/// or online) or of a past one from the archive ([ResultViewModel.record]).
///
/// The comparison with earlier battles comes from the server's list of the
/// user's battles of the same exercise, keeping only those played before
/// this one. So a battle just played gives the same numbers whether or not
/// its upload has landed yet, and a past battle gives its numbers as they
/// were up to that battle.
class ResultViewModel extends ChangeNotifier {
  /// The report of [result], played just now.
  ResultViewModel.battle(
    BattleResult result, {
    required this._history,
    this.analyzer = const FormAnalyzer(),
  }) : _repository = null,
       _matchId = null,
       _hasTime = true,
       _thisScore = result.hasGame ? result.myScore : null,
       _state = ResultState(
         endedAt: result.endedAt,
         outcome: result.outcome,
         end: result.departure == BattleDeparture.none ? result.end : null,
         exercise: result.matchup.exercise,
         opponent: result.matchup.opponent,
         opponentName: result.matchup.opponent.name,
         isOnline: !result.matchup.opponent.isBot,
         roundLength: result.roundLength,
         myScore: result.myDisplayScore,
         opponentScore: result.opponentDisplayScore,
         myReps: result.myReps,
         myInvalidReps: result.myInvalidReps,
         opponentLeft: result.departure == BattleDeparture.opponentLeft,
         form: result.form,
         nextTip: _tipOf(result.form, analyzer),
         rematch: result.matchup.opponent.isBot ? result.matchup.rematch : null,
       );

  /// The report of [record], a past battle. Its form report is loaded from
  /// [repository] when the battle has feedback.
  ResultViewModel.record(
    MatchRecord record, {
    required this._history,
    UserRepository? repository,
    this.analyzer = const FormAnalyzer(),
  }) : _repository = record.hasFeedback ? repository : null,
       _matchId = record.id,
       _thisScore = record.myScore,
       _hasTime = record.playedAt != null,
       _state = ResultState(
         endedAt: record.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
         outcome: record.outcome,
         end: record.gameEnd,
         exercise: record.exercise,
         opponentName: record.opponentName,
         isOnline: record.isOnline,
         myScore: record.hasScores ? record.myScore! : record.myReps,
         opponentScore: record.hasScores
             ? record.opponentScore!
             : record.opponentReps,
         myReps: record.myReps,
         myInvalidReps: record.feedbackSummary?.invalidReps,
         opponentLeft: record.opponentLeft,
       );

  /// A battle just played may already be on the server when the list
  /// arrives, with the server's end time, which can differ a little from
  /// the phone's. A battle ending this close before it is taken as itself:
  /// two real battles are always further apart (setup and round alone take
  /// longer).
  static const sameBattleWindow = Duration(seconds: 5);

  /// How many scores [ResultState.recentScores] shows, this battle included.
  static const recentCount = 8;

  /// How many battles before this one [ResultState.recentAverage] is over.
  static const averageCount = 5;

  final FeedbackStatsSource _history;
  final UserRepository? _repository;
  final int? _matchId;

  /// This battle's game score; null when it kept none.
  final int? _thisScore;

  /// Whether [ResultState.endedAt] is the battle's real time: a past
  /// record without one is never dated in [ResultState.recentFrom].
  final bool _hasTime;

  /// The rules [ResultState.nextTip] comes from.
  final FormAnalyzer analyzer;

  ResultState _state;
  bool _loading = false;
  bool _disposed = false;

  ResultState get state => _state;

  /// Loads the earlier battles, and a past battle's form report. Does
  /// nothing while a load is running.
  Future<void> load() async {
    if (_disposed || _loading) return;
    _loading = true;
    try {
      await Future.wait([_loadHistory(), _loadForm()]);
    } finally {
      _loading = false;
    }
  }

  Future<void> _loadHistory() async {
    if (_state.history != ResultHistoryPhase.loading) {
      _setState(_state.copyWith(history: ResultHistoryPhase.loading));
    }
    final List<StatsPoint> points;
    try {
      points = await _history.fetchStatsPoints(exercise: _state.exercise);
    } on Exception {
      _setState(_state.copyWith(history: ResultHistoryPhase.failed));
      return;
    }
    final earlier = _earlier(points);
    final scores = [for (final p in earlier) p.score!];
    final best = scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b);
    final thisScore = _thisScore;
    final recentEarlier = earlier.length > recentCount - 1
        ? earlier.sublist(earlier.length - (recentCount - 1))
        : earlier;
    final recent = [for (final p in recentEarlier) p.score!, ?thisScore];
    final averaged = scores.length > averageCount
        ? scores.sublist(scores.length - averageCount)
        : scores;
    _setState(
      ResultState(
        endedAt: _state.endedAt,
        outcome: _state.outcome,
        end: _state.end,
        exercise: _state.exercise,
        opponent: _state.opponent,
        opponentName: _state.opponentName,
        isOnline: _state.isOnline,
        roundLength: _state.roundLength,
        myScore: _state.myScore,
        opponentScore: _state.opponentScore,
        myReps: _state.myReps,
        myInvalidReps: _state.myInvalidReps,
        opponentLeft: _state.opponentLeft,
        history: ResultHistoryPhase.ready,
        previousBest: best,
        isNewBest: best != null && thisScore != null && thisScore > best,
        recentScores: List.unmodifiable(recent),
        recentFrom: recentEarlier.isNotEmpty
            ? recentEarlier.first.playedAt
            : (thisScore != null && _hasTime ? _state.endedAt : null),
        recentAverage: averaged.isEmpty
            ? null
            : (averaged.reduce((a, b) => a + b) / averaged.length).round(),
        recentAverageOf: averaged.length,
        form: _state.form,
        nextTip: _state.nextTip,
        rematch: _state.rematch,
      ),
    );
  }

  /// The battles with a score played before this one, oldest first.
  List<StatsPoint> _earlier(List<StatsPoint> points) {
    final id = _matchId;
    final before = id == null
        ? _state.endedAt.subtract(sameBattleWindow)
        : _state.endedAt;
    return [
      for (final p in points)
        if (p.score != null &&
            p.exercise == _state.exercise &&
            (id == null || p.id != id) &&
            p.playedAt.isBefore(before))
          p,
    ]..sort((a, b) => a.playedAt.compareTo(b.playedAt));
  }

  Future<void> _loadForm() async {
    final repository = _repository, id = _matchId;
    if (repository == null || id == null || _state.form != null) return;
    try {
      final report = await repository.fetchFeedback(id);
      if (report == null) return;
      _setState(
        _state.copyWith(
          form: report,
          roundLength: report.roundLength,
          nextTip: _tipOf(report, analyzer),
        ),
      );
    } on Exception {
      // The report shows without the feedback button and the tip.
    }
  }

  static NextTip? _tipOf(FormReport? report, FormAnalyzer analyzer) {
    if (report == null) return null;
    final issue = analyzer
        .analyze(report)
        .where((f) => f.kind == FindingKind.issue && f.fix != null)
        .firstOrNull;
    if (issue == null) return null;
    return NextTip(headline: issue.fix!, detail: issue.title, code: issue.code);
  }

  void _setState(ResultState state) {
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
