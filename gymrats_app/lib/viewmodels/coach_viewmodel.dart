import 'package:flutter/foundation.dart';

import '../models/feedback_goal.dart';
import '../models/feedback_stats.dart';
import '../models/form_report.dart';
import '../services/feedback/coach_script.dart';
import '../services/feedback/feedback_stats.dart';
import '../services/feedback/form_analyzer.dart';
import '../services/feedback/goal_store.dart';
import '../services/user/user_repository.dart';
import 'feedback_viewmodel.dart';
import 'result_viewmodel.dart';

/// Whether the talk is ready to be heard.
enum CoachPhase {
  /// The earlier battles are loading; the report's card waits for the
  /// number of lines.
  loading,

  /// [CoachState.script] is built.
  ready,
}

/// Where the character's talk stands (A10 spec 3): which page shows, how
/// many of its letters are out, and what the user picked.
@immutable
class CoachState {
  const CoachState({
    this.phase = CoachPhase.loading,
    this.script,
    this.index = 0,
    this.revealed = 0,
    this.answered = false,
    this.choice,
    this.ended = false,
  });

  final CoachPhase phase;

  /// The talk; null while loading.
  final CoachScript? script;

  /// The page: the talk's lines, then the question ([questionIndex]), then
  /// the answer to the user's choice.
  final int index;

  /// How many letters of [line] are out.
  final int revealed;

  /// Whether the user picked a goal or declined.
  final bool answered;

  /// The goal picked; null before a choice and after '사양할래'.
  final GoalSuggestion? choice;

  /// The last line ('오늘 이야기는 여기까지!') is showing.
  final bool ended;

  /// The question's page.
  int get questionIndex => script?.talk.length ?? 0;

  /// The pages the dots count: the talk, the question and the answer.
  int get pageCount => questionIndex + 2;

  /// What the character says now; null while loading.
  CoachLine? get line {
    final script = this.script;
    if (script == null) return null;
    if (ended) return script.end;
    if (index < script.talk.length) return script.talk[index];
    if (index == questionIndex) return script.question;
    return script.answer(choice);
  }

  /// Whether every letter of [line] is out.
  bool get fullyShown => revealed >= (line?.length ?? 0);

  /// The goal question is showing.
  bool get onQuestion => script != null && !ended && index == questionIndex;

  /// The choices show once the question is fully out.
  bool get showsChoices => onQuestion && fullyShown && !answered;

  /// [line]'s pieces cut at [revealed] letters.
  List<CoachPiece> get shownPieces {
    final line = this.line;
    if (line == null) return const [];
    var left = revealed;
    final shown = <CoachPiece>[];
    for (final piece in line.pieces) {
      if (left <= 0) break;
      final letters = piece.text.runes.toList();
      final cut = letters.length <= left ? letters : letters.sublist(0, left);
      left -= letters.length;
      shown.add(CoachPiece(String.fromCharCodes(cut), marked: piece.marked));
    }
    return shown;
  }

  CoachState _at(int index, {required bool instant}) => CoachState(
    phase: phase,
    script: script,
    index: index,
    revealed: instant ? _lengthAt(index) : 0,
    answered: answered,
    choice: choice,
  );

  CoachState _copyRevealed(int revealed) => CoachState(
    phase: phase,
    script: script,
    index: index,
    revealed: revealed,
    answered: answered,
    choice: choice,
    ended: ended,
  );

  int _lengthAt(int index) =>
      CoachState(
        phase: phase,
        script: script,
        index: index,
        answered: answered,
        choice: choice,
      ).line?.length ??
      0;
}

/// The character's talk about one battle (A10 spec 3 to 5): it loads the
/// earlier battles, builds the lines with [CoachScript], types them out,
/// and saves the goal the user picks.
///
/// One per report: the result screen makes it when the battle has a form
/// report, shows its number of lines on the character card, and opens the
/// talk screen on it ([start]). The talk screen drives the typing with
/// [tick] and passes the user's taps on.
class CoachViewModel extends ChangeNotifier {
  CoachViewModel({
    required this.report,
    required this.characterId,
    required this.summary,
    this._history,
    this._repository,
    this._goalStore,
    this._accountId,
    this._matchId,
    this.analyzer = const FormAnalyzer(),
    DateTime Function()? now,
  }) : voice = CoachVoice.of(characterId),
       _now = now ?? DateTime.now;

  /// The battle talked about.
  final FormReport report;

  /// The character played in [report] ([FormReport.characterId]; the one
  /// chosen now for a report that kept none): it talks, and a goal picked
  /// here keeps it (task.md W11 decision 11).
  final String characterId;

  /// Who talks: the name tag and the sentence ending.
  final CoachVoice voice;

  /// The pill at the top, e.g. "스쿼트 · RepBot 중수 · 승리".
  final String summary;

  final FormAnalyzer analyzer;

  /// The server's list of the user's battles; null leaves out the
  /// comparison with earlier battles.
  final FeedbackStatsSource? _history;

  /// Gives an earlier battle's form report; null leaves out their pace and
  /// combo.
  final UserRepository? _repository;

  /// Where the picked goal goes, and where the last goal is read from to
  /// check it (A11 spec 6); without it or [_accountId] neither happens.
  final GoalStore? _goalStore;
  final int? _accountId;

  /// The server id of a past battle opened from 기록보관소; null for the
  /// battle just played.
  final int? _matchId;
  final DateTime Function() _now;

  /// How many earlier battles the talk compares with (A10 spec 4).
  static const earlierCount = 5;

  /// How long the talk waits for the last goal: a read takes a few
  /// milliseconds; a stuck one leaves the goal unchecked rather than the
  /// talk unready.
  static const lastGoalWait = Duration(seconds: 2);

  CoachState _state = const CoachState();
  bool _instant = false;
  bool _loading = false;
  bool _disposed = false;

  CoachState get state => _state;

  /// How many lines the talk has before the goal question: the "할 말이
  /// N개" on the report's card. Null while loading.
  int? get lineCount =>
      _state.phase == CoachPhase.ready ? _state.questionIndex : null;

  /// Loads the earlier battles and the last goal, and builds the talk. A
  /// failed load builds it as for a first battle, without a goal to check.
  /// Does nothing once loading or ready.
  Future<void> load() async {
    if (_disposed || _loading || _state.phase == CoachPhase.ready) return;
    _loading = true;
    final (earlier, lastGoal) = await (_loadEarlier(), _loadLastGoal()).wait;
    _loading = false;
    if (_disposed) return;
    final feedback = FormFeedback.of(report, analyzer: analyzer);
    final script = CoachScript.build(
      CoachInput(
        report: report,
        findings: feedback.findings,
        pace: CoachPace(
          buckets: feedback.paceBuckets,
          sliceSeconds: feedback.sliceSeconds,
        ),
        characterId: characterId,
        earlier: earlier,
        lastGoal: lastGoal,
      ),
    );
    _set(CoachState(phase: CoachPhase.ready, script: script));
  }

  /// The account's goal for this exercise when it was set before this
  /// battle ended, to check it (A11 spec 6); a goal set after it (picked in
  /// this very talk) is not this battle's. Read only.
  Future<FeedbackGoal?> _loadLastGoal() async {
    final store = _goalStore, account = _accountId;
    if (store == null || account == null) return null;
    try {
      final goal = await store
          .read(account, report.exercise)
          .timeout(lastGoalWait, onTimeout: () => null);
      if (goal == null || !goal.setAt.isBefore(report.endedAt)) return null;
      return goal;
    } on Object {
      return null;
    }
  }

  /// The newest [earlierCount] battles of the same exercise played before
  /// this one, oldest first, with the form report of each that kept one.
  Future<List<CoachEarlier>> _loadEarlier() async {
    final history = _history;
    if (history == null) return const [];
    final List<StatsPoint> points;
    try {
      points = await history.fetchStatsPoints(exercise: report.exercise);
    } on Object {
      return const [];
    }
    final id = _matchId;
    // The battle just played may be on the server already, with the
    // server's end time (as in [ResultViewModel]).
    final before = id == null
        ? report.endedAt.subtract(ResultViewModel.sameBattleWindow)
        : report.endedAt;
    final earlier = [
      for (final p in points)
        if (p.exercise == report.exercise &&
            (id == null || p.id != id) &&
            p.playedAt.isBefore(before))
          p,
    ]..sort((a, b) => a.playedAt.compareTo(b.playedAt));
    final latest = earlier.length > earlierCount
        ? earlier.sublist(earlier.length - earlierCount)
        : earlier;
    return Future.wait([for (final p in latest) _earlierOf(p)]);
  }

  Future<CoachEarlier> _earlierOf(StatsPoint point) async {
    final repository = _repository;
    if (!point.hasFeedback || repository == null) {
      return CoachEarlier(reps: point.reps);
    }
    try {
      final earlier = await repository.fetchFeedback(point.id);
      if (earlier == null) return CoachEarlier(reps: point.reps);
      final feedback = FormFeedback.of(earlier, analyzer: analyzer);
      return CoachEarlier(
        reps: point.reps,
        pace: CoachPace(
          buckets: feedback.paceBuckets,
          sliceSeconds: feedback.sliceSeconds,
        ),
        longestCombo: CoachFacts.longestComboOf(earlier),
      );
    } on Object {
      // Its counted reps still count for the average.
      return CoachEarlier(reps: point.reps);
    }
  }

  /// Opens the talk from its first line, or ([atGoal], '건너뛰기' on the
  /// report) at the goal question. Anything picked before is forgotten.
  void start({bool atGoal = false}) {
    if (_state.phase != CoachPhase.ready) return;
    final fresh = CoachState(phase: CoachPhase.ready, script: _state.script);
    _set(fresh._at(atGoal ? fresh.questionIndex : 0, instant: _instant));
  }

  /// '처음부터 다시': the talk from its first line.
  void restart() => start();

  /// Reduced motion: every line shows whole at once.
  void setInstant(bool instant) {
    _instant = instant;
    if (instant) _revealAll();
  }

  /// One more letter of the line, while it types.
  void tick() {
    if (_state.line == null || _state.fullyShown) return;
    _set(_copy(revealed: _state.revealed + 1));
  }

  /// A tap on the dialog box: the whole line while it types, else the next
  /// page. The question waits for a choice instead; the last line waits
  /// for a button.
  void tap() {
    if (_state.line == null) return;
    if (!_state.fullyShown) {
      _revealAll();
      return;
    }
    if (_state.ended || _state.onQuestion) return;
    if (_state.index > _state.questionIndex) {
      _set(_endState());
    } else {
      _set(_state._at(_state.index + 1, instant: _instant));
    }
  }

  /// '건너뛰기': to the goal question, or from there on to the end.
  void skip() {
    if (_state.line == null || _state.ended) return;
    if (_state.index < _state.questionIndex) {
      _set(_state._at(_state.questionIndex, instant: _instant));
    } else {
      _set(_endState());
    }
  }

  /// The user picked [goal], or declined it (null, '사양할래'): the answer
  /// line shows, and the account's goal for this exercise is saved over,
  /// or removed. Only while the choices show, and once.
  Future<void> choose(GoalSuggestion? goal) async {
    if (!_state.showsChoices) return;
    final answered = CoachState(
      phase: _state.phase,
      script: _state.script,
      index: _state.index,
      answered: true,
      choice: goal,
    );
    _set(answered._at(_state.questionIndex + 1, instant: _instant));
    final store = _goalStore, account = _accountId;
    if (store == null || account == null) return;
    try {
      if (goal == null) {
        await store.clear(account, report.exercise);
      } else {
        await store.write(
          account,
          goal.toGoal(
            exercise: report.exercise,
            setAt: _now(),
            characterId: characterId,
            fromMatch: report.id,
          ),
        );
      }
    } on Object {
      // The talk goes on; the goal is not kept on this phone.
    }
  }

  CoachState _endState() {
    final end = CoachState(
      phase: _state.phase,
      script: _state.script,
      index: _state.index,
      answered: _state.answered,
      choice: _state.choice,
      ended: true,
    );
    return _instant ? end._copyRevealed(end.line!.length) : end;
  }

  void _revealAll() {
    final line = _state.line;
    if (line == null || _state.fullyShown) return;
    _set(_copy(revealed: line.length));
  }

  CoachState _copy({required int revealed}) => _state._copyRevealed(revealed);

  void _set(CoachState state) {
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
