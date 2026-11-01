import 'dart:async';
import 'dart:math' as math;

import '../../models/battle_rules.dart';
import '../../models/bot_difficulty.dart';
import '../../models/matchup.dart';
import '../../models/rep_event.dart';
import '../../models/exercise_type.dart';
import '../pose/exercise_judge.dart';
import '../pose/setup_checker.dart' show Clock;
import 'opponent_source.dart';

/// The AI opponent: valid reps and a few rejected ones, at the pace of its
/// [difficulty].
///
/// [start] plans the whole round with [planRound]. The reps then arrive at
/// their planned times on the injected clock, leaving out paused time.
/// Inject the [math.Random] and the clock to make a round repeatable.
class BotOpponent implements OpponentSource {
  BotOpponent({
    math.Random? random,
    Clock? clock,
    this.roundLength = battleDuration,
    this.passDepth = _pushUpPassDepth,
    this.difficulty = BotDifficulty.expert,
  }) : _random = random ?? math.Random(),
       _clock = clock ?? _stopwatchClock();

  /// The bot of [matchup]: its difficulty, at the pass depth of its exercise.
  factory BotOpponent.forMatchup(Matchup matchup) => BotOpponent(
    passDepth: judgeFor(matchup.exercise).passDepth,
    difficulty: matchup.opponent.difficulty ?? BotDifficulty.expert,
  );

  /// Every planned rep falls inside this.
  final Duration roundLength;

  /// How many reps it makes, and how well.
  final BotDifficulty difficulty;

  /// The pass depth of the exercise the bot plays. Its reps go that many times
  /// as deep, so they get the same grades in every exercise.
  final double passDepth;

  final math.Random _random;
  final Clock _clock;
  final StreamController<RepEvent> _reps = StreamController.broadcast();

  List<RepEvent> _plan = const [];

  /// Index in [_plan] of the next rep to send.
  int _nextRep = 0;
  bool _stopped = true;

  /// Round time run before the last start or resume. Grows at each pause.
  Duration _elapsedBeforeResume = Duration.zero;

  /// Clock time of the last start or resume; null while paused or stopped.
  Duration? _resumedAt;
  Timer? _timer;

  /// The first rep cannot end before this.
  static const _startDelay = Duration(seconds: 2);

  /// Kept free at the end, so a late rep still ends inside the round.
  static const _endMargin = Duration(milliseconds: 1500);

  /// How much the bot tires: the last gaps are about (1 + s) / (1 - s)
  /// times the first ones, here 1.9.
  static const _slowdown = 0.3;

  /// How far a rep may move off its slot, as a share of the gap there.
  static const _jitter = 0.15;

  /// A rep that closes right behind the last one comes this long after it,
  /// inside the game's combo window.
  static final _comboGap = battleRules.comboWindow * 0.8;

  /// The depth a push-up must reach: `RepJudgeConfig.bottomDepth`.
  static const _pushUpPassDepth = 1.1;

  /// How deep the bot's valid push-ups go, in top-pose shoulder widths: both
  /// are inside what normal push-ups reach, and only the deep one is excellent.
  /// Another exercise scales them by its pass depth.
  static const _normalDepth = 1.4;
  static const _deepDepth = 1.9;

  static Clock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Plans one round: when each rep ends, and which ones are rejected.
  ///
  /// The valid count is drawn first, so every round lands in the pace of
  /// [difficulty]. A few rejected reps are mixed in. Gaps widen towards the
  /// end, and each rep moves a little off its slot. Reps stay in order inside
  /// the round. Some valid reps go deep, so the game grades them higher;
  /// [passDepth] scales how deep. Rejected reps have no depth and no elbow
  /// angle, so they earn nothing.
  static List<RepEvent> planRound(
    math.Random random,
    Duration roundLength, {
    double passDepth = _pushUpPassDepth,
    BotDifficulty difficulty = BotDifficulty.expert,
  }) {
    // Exactly 1 at the default, so push-up depths stay exactly as they are.
    final depthScale = passDepth / _pushUpPassDepth;
    int atPace(int count) => BotDifficulty.atPace(count, roundLength);
    final fewestValid = atPace(difficulty.fewestValid);
    final validCount =
        fewestValid +
        random.nextInt(atPace(difficulty.mostValid) - fewestValid + 1);
    final fewestRejected = atPace(difficulty.fewestRejected);
    final rejectedCount =
        fewestRejected +
        random.nextInt(atPace(difficulty.mostRejected) - fewestRejected + 1);
    final count = validCount + rejectedCount;
    final slots = List.generate(count, (i) => i)..shuffle(random);
    final rejected = slots.take(rejectedCount).toSet();
    final span = (roundLength - _startDelay - _endMargin).inMicroseconds;
    final plan = <RepEvent>[];
    for (var i = 0; i < count; i++) {
      // Where the slot lies in the round, from 0 to 1.
      final slot = (i + 0.5) / count;
      // The time used up grows faster towards the end, so gaps widen.
      final progress = (1 - _slowdown) * slot + _slowdown * slot * slot;
      // The gap around the slot: the slope of progress, per rep.
      final gap = span / count * ((1 - _slowdown) + 2 * _slowdown * slot);
      final jitter = (random.nextDouble() * 2 - 1) * _jitter * gap;
      final reason = rejected.contains(i)
          ? RejectReason.forExercise(ExerciseType.pushUp)[random.nextInt(
              RejectReason.forExercise(ExerciseType.pushUp).length,
            )]
          : null;
      var at =
          _startDelay +
          Duration(microseconds: (span * progress + jitter).round());
      final maxDepth = reason != null
          ? null
          : (random.nextDouble() < difficulty.deepShare
                    ? _deepDepth
                    : _normalDepth) *
                depthScale;
      // No draw at a chance of 0, so that level's rounds stay the same.
      if (difficulty.comboChance > 0 &&
          reason == null &&
          plan.isNotEmpty &&
          plan.last.valid &&
          random.nextDouble() < difficulty.comboChance) {
        final behindLast = plan.last.at + _comboGap;
        if (behindLast < at) at = behindLast;
      }
      plan.add(
        RepEvent(
          index: i + 1,
          valid: reason == null,
          reason: reason,
          at: at,
          maxDepth: maxDepth,
        ),
      );
    }
    return plan;
  }

  @override
  Stream<RepEvent> get reps => _reps.stream;

  @override
  void start() {
    _timer?.cancel();
    _plan = planRound(
      _random,
      roundLength,
      passDepth: passDepth,
      difficulty: difficulty,
    );
    _nextRep = 0;
    _stopped = false;
    _elapsedBeforeResume = Duration.zero;
    _resumedAt = _clock();
    _scheduleNext();
  }

  @override
  void pause() {
    final resumedAt = _resumedAt;
    if (resumedAt == null) return;
    _elapsedBeforeResume += _clock() - resumedAt;
    _resumedAt = null;
    _timer?.cancel();
  }

  @override
  void resume() {
    if (_stopped || _resumedAt != null) return;
    _resumedAt = _clock();
    _scheduleNext();
  }

  @override
  void stop() {
    _timer?.cancel();
    _stopped = true;
    _resumedAt = null;
  }

  @override
  void dispose() {
    stop();
    unawaited(_reps.close());
  }

  /// Round time run so far, leaving out paused time.
  Duration get _elapsed {
    final resumedAt = _resumedAt;
    return resumedAt == null
        ? _elapsedBeforeResume
        : _elapsedBeforeResume + (_clock() - resumedAt);
  }

  void _scheduleNext() {
    if (_nextRep >= _plan.length) return;
    final wait = _plan[_nextRep].at - _elapsed;
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _deliverNext);
  }

  void _deliverNext() {
    _reps.add(_plan[_nextRep++]);
    _scheduleNext();
  }
}
