import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_result.dart';
import '../models/bot_difficulty.dart';
import '../models/character_rig.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/feedback_stats.dart';
import '../models/form_report.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../models/matchup.dart';
import '../services/feedback/feedback_stats.dart';
import '../services/feedback/goal_store.dart';
import '../services/user/user_repository.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/character_viewmodel.dart';
import '../viewmodels/coach_viewmodel.dart';
import '../viewmodels/result_viewmodel.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/result_cards.dart';
import '../widgets/result_report.dart';
import '../widgets/victory_overlay.dart';
import '../widgets/victory_scene.dart';

/// The result report of a battle (BResult): how it ended, both scores, the
/// user's reps, and the cards its values allow.
///
/// It draws only the values [reportOf] takes from 박진영's result view model
/// (J4) and its only behavior is navigation. The battle was saved before
/// this screen opened. The back button, 홈으로 and system back go home;
/// 다시 대결 replaces this screen with a new search.
///
/// My character sits in the report's seat, right of the headline (W5). When
/// the report opens, the victory scene ([sceneOf]) plays once over it; a tap
/// skips it. With reduced motion the seat shows only its end look.
///
/// [ResultScreen.record] is a past battle's report, opened from 기록보관소
/// ([reportTap]): the seat shows only the end look, system back returns to
/// the archive, and 다시 대결 starts the new battle from home.
///
/// A battle with a form report gets the character card (A10; online and
/// past battles too): the screen makes the talk's [CoachViewModel] once the
/// form report is in, and opens the talk screen on it
/// ([GymRatsApp.coachRoute]).
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required BattleResult this.result,
    this.createViewModel,
    this.createCoachViewModel,
  }) : record = null;

  /// The report of [record], a past battle (team decision 2026-11-08: a
  /// battle in 기록보관소 opens its report). It does not play the scene
  /// (W5 spec 11.1, answered 2026-11-14).
  const ResultScreen.record({
    super.key,
    required MatchRecord this.record,
    this.createViewModel,
    this.createCoachViewModel,
  }) : result = null;

  /// The battle just played; null for a past one.
  final BattleResult? result;

  /// The past battle; null for one just played.
  final MatchRecord? record;

  /// Builds the report's view model, for tests. Null builds
  /// [ResultViewModel.battle] of [result], or [ResultViewModel.record] of
  /// [record] with the app's repository for its form report, on
  /// [historyOf].
  final ResultViewModel Function()? createViewModel;

  /// Builds the talk's view model for the battle's form report, for tests.
  /// Null builds one on the app's repository, goal store, account and
  /// character.
  final CoachViewModel Function(FormReport form)? createCoachViewModel;

  /// Where the earlier battles come from: the app's [UserRepository] when it
  /// can give them (the server one can). Otherwise none, and the comparison
  /// is left out as after a failed load.
  static FeedbackStatsSource historyOf(BuildContext context) {
    final repository = Provider.of<UserRepository?>(context, listen: false);
    if (repository case final FeedbackStatsSource source) return source;
    return const _NoHistory();
  }

  /// The one place the report takes its values from: [state] as J4's view
  /// model gives it, as the report's cards take them. A card whose values
  /// are missing is left out; [scored] false (a battle without a game score,
  /// from a server without the game) leaves out the latest battles and the
  /// placeholder too, as their last bar would not be this battle.
  static ResultReportData reportOf(
    ResultState state, {
    bool scored = true,
    ResultCoachEntry? coach,
  }) {
    final ready = state.history == ResultHistoryPhase.ready;
    final previous = state.previousBest;
    final average = state.recentAverage;
    final from = state.recentFrom;
    return ResultReportData(
      outcome: state.outcome,
      byKo: state.end == GameEnd.ko,
      exercise: state.exercise,
      // A past battle keeps only the name.
      opponent:
          state.opponent ?? Opponent(name: state.opponentName, isBot: false),
      // A battle a player left carries the whole round, not when they left.
      played: state.departure == BattleDeparture.none
          ? state.roundLength
          : null,
      myScore: state.myScore,
      opponentScore: state.opponentScore,
      myValidReps: state.myReps,
      myInvalidReps: state.myInvalidReps,
      opponentValidReps: state.opponentReps,
      endedAt: state.endedAt,
      departure: state.departure,
      hasFeedback: state.form != null,
      // Without a score of its own nothing will replace the placeholder.
      comparisonLoading: scored && state.history == ResultHistoryPhase.loading,
      // The first battle has no earlier best, so it is never a new one.
      best: ready && state.isNewBest && previous != null
          ? ResultNewBest(
              previous: previous,
              current: state.myScore,
              gain: state.myScore - previous,
            )
          : null,
      // Without an earlier battle there is no average to compare with.
      recent:
          ready &&
              scored &&
              average != null &&
              from != null &&
              state.recentScores.isNotEmpty
          ? ResultRecent(
              scores: state.recentScores,
              firstPlayedAt: from,
              average: average,
              averageCount: state.recentAverageOf,
              difference: state.myScore - average,
            )
          : null,
      // The tip is said in the talk's form step now (task.md W10
      // decision 4).
      coach: state.form == null ? null : coach,
    );
  }

  /// The talk screen's pill: the exercise, the opponent and the result in
  /// the headline's words, e.g. "스쿼트 · RepBot 중수 · 승리" (task.md W10
  /// decision 5).
  static String summaryOf(ResultState state) => [
    state.exercise.koreanName,
    ResultSubLine.opponentText(
      state.opponent ?? Opponent(name: state.opponentName, isBot: false),
    ),
    ResultHeadline.wordFor(state.outcome, byKo: state.end == GameEnd.ko),
  ].join(' · ');

  /// The character card's values for [coach]'s talk.
  static ResultCoachEntry coachEntryOf(CoachViewModel coach) =>
      ResultCoachEntry(
        characterId: coach.voice.characterId,
        name: coach.voice.name,
        ending: coach.voice.ending,
        lineCount: coach.lineCount,
      );

  /// The victory scene of [state] (W5 spec 1 and 4): a win because the
  /// opponent left (기권승), by KO (KO 승리) or by time (판정승); a loss or a
  /// draw.
  static VictoryResult sceneOf(ResultState state) => VictoryResult.decide(
    state.outcome,
    byKo: state.end == GameEnd.ko,
    opponentLeft: state.opponentLeft,
  );

  /// The bot battle 다시 대결 starts for [state]; null opens the online
  /// lobby. A battle just played gives J4's rematch. A past battle keeps
  /// only the bot's name ("AI 봇 · 초보"): its level is read from it, else
  /// 고수, as the sub line reads a bot without a level. A past battle not
  /// known as online or not counts as a bot's when its name is one.
  static BotMatchRequest? rematchOf(ResultState state) {
    if (state.rematch case final rematch?) return rematch;
    final named = BotDifficulty.values
        .where((level) => level.opponentName == state.opponentName)
        .firstOrNull;
    final isBot =
        state.opponent?.isBot ??
        switch (state.isOnline) {
          false => true,
          true => false,
          null => named != null,
        };
    if (!isBot) return null;
    return BotMatchRequest(
      exercise: state.exercise,
      difficulty: named ?? BotDifficulty.expert,
    );
  }

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

/// What tapping [match] in 기록보관소 does: opens its report on top
/// ([ResultScreen.record]); every battle has one.
VoidCallback reportTap(BuildContext context, MatchRecord match) =>
    () => Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen.record(record: match)),
    );

class _ResultScreenState extends State<ResultScreen> {
  late final ResultViewModel _viewModel;

  /// The talk about this battle, once its form report is in.
  CoachViewModel? _coach;

  /// The talk's line count the card last showed: the card is redrawn only
  /// when it changes, not on every typed letter.
  int? _coachLines;

  /// Set once a leaving button is pressed, so a second tap does nothing.
  bool _leaving = false;

  /// The report's seat, to find where the scene ends.
  final _seatKey = GlobalKey();

  /// Where the seat is on this screen, once the report is laid out.
  Offset? _seat;

  /// Set when the scene is over (played out or skipped) or will not play
  /// (reduced motion when the report opened, or turned on while it plays):
  /// from then on the seat shows the end look. It plays once.
  bool _sceneOver = false;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _viewModel =
        widget.createViewModel?.call() ??
        (record == null
            ? ResultViewModel.battle(
                widget.result!,
                history: ResultScreen.historyOf(context),
              )
            : ResultViewModel.record(
                record,
                history: ResultScreen.historyOf(context),
                repository: Provider.of<UserRepository?>(
                  context,
                  listen: false,
                ),
              ));
    // A past report shows only the scene's end look.
    if (record != null) _sceneOver = true;
    _viewModel.addListener(_makeCoach);
    unawaited(
      _viewModel.load().whenComplete(() {
        if (mounted) setState(() => _formTried = true);
      }),
    );
    _makeCoach();
  }

  /// Whether the past battle's form report has been asked for and has come
  /// or not: until then its character is not known.
  bool _formTried = false;

  /// The character played in this battle (task.md W11 decision 11): the
  /// form report's; the one chosen now ([current]) for a report that kept
  /// none, or for a past battle without one. Null while a past battle's
  /// form report is still coming: nothing is drawn, so the character does
  /// not change face.
  String? _playedCharacter(String current) {
    final form = _viewModel.state.form;
    if (form?.characterId case final id?) return id;
    final record = widget.record;
    final waiting =
        record != null && record.hasFeedback && form == null && !_formTried;
    return waiting ? null : current;
  }

  /// Makes the talk once the battle's form report is in: a past battle's
  /// arrives after the report opens.
  void _makeCoach() {
    final form = _viewModel.state.form;
    if (_coach != null || form == null || !mounted) return;
    final coach = widget.createCoachViewModel?.call(form) ?? _coachOf(form);
    _coach = coach..addListener(_onCoachChanged);
    coach.load();
  }

  CoachViewModel _coachOf(FormReport form) => CoachViewModel(
    report: form,
    // The battle's character talks; a report that kept none, the one now.
    characterId:
        form.characterId ??
        Provider.of<CharacterViewModel?>(context, listen: false)?.characterId ??
        CharacterRig.defaultId,
    summary: ResultScreen.summaryOf(_viewModel.state),
    history: ResultScreen.historyOf(context),
    repository: Provider.of<UserRepository?>(context, listen: false),
    goalStore: Provider.of<GoalStore?>(context, listen: false),
    accountId: Provider.of<AuthViewModel?>(context, listen: false)?.account?.id,
    matchId: widget.record?.id,
  );

  void _onCoachChanged() {
    final lines = _coach?.lineCount;
    if (!mounted || lines == _coachLines) return;
    setState(() => _coachLines = lines);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _sceneOver = true;
  }

  /// Finds the seat after the next layout, while the scene plays: when the
  /// screen is built or the page scrolls (a screen reader can scroll it; a
  /// touch only skips). The report's values loading change only the cards
  /// below the seat.
  void _findSeatLater() {
    if (_sceneOver) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _findSeat());
  }

  /// Where the seat is now, for the scene to end on it.
  void _findSeat() {
    if (!mounted || _sceneOver) return;
    final cell = _seatKey.currentContext?.findRenderObject();
    final screen = context.findRenderObject();
    if (cell is! RenderBox || screen is! RenderBox || !cell.hasSize) return;
    final seat = cell.localToGlobal(Offset.zero, ancestor: screen);
    if (seat != _seat) setState(() => _seat = seat);
  }

  void _endScene() => setState(() => _sceneOver = true);

  @override
  void dispose() {
    _viewModel
      ..removeListener(_makeCoach)
      ..dispose();
    _coach
      ?..removeListener(_onCoachChanged)
      ..dispose();
    super.dispose();
  }

  /// The leaving buttons go through here, so only the first one pressed
  /// acts: after 홈으로, 다시 대결 does nothing either.
  void _leaveOnce(VoidCallback navigate) {
    if (_leaving) return;
    _leaving = true;
    navigate();
  }

  void _goHome() => _leaveOnce(() => popToHome(context));

  /// The talk, from its first line or ([atGoal], 건너뛰기) at the goal
  /// question. Opens on top, so back and 리포트로 come here again.
  void _openCoach({required bool atGoal}) {
    final coach = _coach;
    if (_leaving || coach == null || coach.lineCount == null) return;
    coach
      ..setInstant(MediaQuery.disableAnimationsOf(context))
      ..start(atGoal: atGoal);
    Navigator.pushNamed(context, GymRatsApp.coachRoute, arguments: coach);
  }

  /// Opens on top, so back comes here again. Not one of the leaving buttons.
  void _openFeedback() {
    if (_leaving) return;
    Navigator.pushNamed(
      context,
      GymRatsApp.feedbackRoute,
      arguments: _viewModel.state.form,
    );
  }

  /// The same battle again: a bot of the same level, or, after an online
  /// battle, the online lobby with the same exercise ([rematchOf]). It
  /// takes this report's place; from a past report it starts from home, as
  /// any battle does, so 기록보관소 is not left under it.
  void _matchAgain() => _leaveOnce(() {
    final state = _viewModel.state;
    final rematch = ResultScreen.rematchOf(state);
    final (route, argument) = rematch != null
        ? (GymRatsApp.matchingRoute, rematch as Object)
        : (GymRatsApp.onlineBattleRoute, state.exercise);
    if (widget.record == null) {
      Navigator.pushReplacementNamed(context, route, arguments: argument);
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (below) => below.isFirst,
        arguments: argument,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    // The battle's character (W11 decision 11); for a report that kept none
    // the app's, and without one above (a test) the default, as for a
    // character not known (W5 spec 8).
    final character = _playedCharacter(
      context.watch<CharacterViewModel?>()?.characterId ??
          CharacterRig.defaultId,
    );
    final scene = ResultScreen.sceneOf(_viewModel.state);
    final playing = !_sceneOver;
    if (playing) {
      // The seat moves with the screen's size, insets and text size: a
      // change builds this screen again, and it looks again.
      MediaQuery.sizeOf(context);
      MediaQuery.paddingOf(context);
      MediaQuery.textScalerOf(context);
      _findSeatLater();
    }
    final seat = _seat;
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _findSeatLater();
            return false;
          },
          child: ChangeNotifierProvider<ResultViewModel>.value(
            value: _viewModel,
            child: Consumer<ResultViewModel>(
              builder: (context, viewModel, _) => ResultReport(
                data: ResultScreen.reportOf(
                  viewModel.state,
                  // J4 compares a past battle by its score, when it has one.
                  scored:
                      widget.result?.hasGame ?? widget.record!.myScore != null,
                  coach: switch (_coach) {
                    final coach? => ResultScreen.coachEntryOf(coach),
                    null => null,
                  },
                ),
                onGoHome: _goHome,
                onRematch: _matchAgain,
                onOpenFeedback: _openFeedback,
                onHearCoach: () => _openCoach(atGoal: false),
                onSkipCoach: () => _openCoach(atGoal: true),
                // Empty while the scene plays: it draws the seat itself.
                seat: KeyedSubtree(
                  key: _seatKey,
                  child: playing || character == null
                      ? const SizedBox.expand()
                      : VictorySeat(result: scene, characterId: character),
                ),
              ),
            ),
          ),
        ),
        if (playing && seat != null && character != null)
          VictoryOverlay(
            result: scene,
            characterId: character,
            seat: seat,
            onEnd: _endScene,
          ),
      ],
    );
  }
}

/// No earlier battles to give: every fetch fails.
class _NoHistory implements FeedbackStatsSource {
  const _NoHistory();

  @override
  Future<List<StatsPoint>> fetchStatsPoints({
    ExerciseType? exercise,
    DateTime? since,
  }) async => throw Exception('this repository keeps no battle list');
}
