import 'dart:async';
import 'dart:math' as math;

import '../../models/battle_rules.dart';
import '../../models/rep_event.dart';
import '../pose/setup_checker.dart' show Clock;
import 'opponent_source.dart';

/// The AI opponent: 20 to 28 valid reps a minute, with a few rejected ones.
///
/// [start] plans the whole round with [planRound]. The reps then arrive at
/// their planned times on the injected clock, leaving out paused time.
/// Inject the [math.Random] and the clock to make a round repeatable.
class BotOpponent implements OpponentSource {
  BotOpponent({
    math.Random? random,
    Clock? clock,
    this.roundLength = battleDuration,
  }) : _random = random ?? math.Random(),
       _clock = clock ?? _stopwatchClock();

  /// Every planned rep falls inside this.
  final Duration roundLength;

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

  /// The bot's pace: 20 to 28 valid and up to 3 rejected reps in a minute.
  static const _paceLength = Duration(seconds: 60);
  static const _fewestValid = 20;
  static const _mostValid = 28;
  static const _mostRejected = 3;

  static Clock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Plans one round: when each rep ends, and which ones are rejected.
  ///
  /// The valid count is drawn first, so every round lands in the bot's
  /// pace: 20 to 28 in a 60-second round, 7 to 9 in a 20-second one. A few
  /// rejected reps are mixed in. Gaps widen towards the end, and each rep
  /// moves a little off its slot. In a 60-second round, reps stay at least
  /// 0.9 seconds apart and in order.
  static List<RepEvent> planRound(math.Random random, Duration roundLength) {
    int atPace(int perMinute) =>
        (perMinute * roundLength.inMicroseconds / _paceLength.inMicroseconds)
            .round();
    final fewestValid = atPace(_fewestValid);
    final validCount =
        fewestValid + random.nextInt(atPace(_mostValid) - fewestValid + 1);
    final rejectedCount = random.nextInt(atPace(_mostRejected) + 1);
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
          ? RejectReason.values[random.nextInt(RejectReason.values.length)]
          : null;
      plan.add(
        RepEvent(
          index: i + 1,
          valid: reason == null,
          reason: reason,
          at:
              _startDelay +
              Duration(microseconds: (span * progress + jitter).round()),
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
    _plan = planRound(_random, roundLength);
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
