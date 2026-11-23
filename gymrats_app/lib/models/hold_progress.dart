import 'hold_reading.dart';

/// Where a hold is, from GO on (arcade hold spec 3).
enum HoldState {
  /// After GO, until the pose is first held for a while: the time stays at
  /// zero and no warning is given. Only a pose whose definition asks for it
  /// has this (the chair pose is set up standing).
  entering,

  /// The time held runs while the pose is held.
  holding,

  /// A warning stopped the time; it runs again once the pose is held for a
  /// while.
  paused,

  /// The stage is over: see [HoldProgress.end].
  ended,
}

/// How a hold ended.
enum HoldEnd {
  /// The time held reached the third star.
  held,

  /// The second warning.
  warnings,
}

/// The hold as the screen shows it: an immutable snapshot.
class HoldProgress {
  const HoldProgress({
    this.state = HoldState.holding,
    this.held = Duration.zero,
    this.warnings = const [],
    this.fault,
    this.end,
  });

  final HoldState state;

  /// The time really held: none before GO, while entering or while paused.
  final Duration held;

  /// The fault of each warning given, in order.
  final List<HoldFault> warnings;

  /// While paused, what the camera box asks to fix: the warning's fault at
  /// first, then the latest one read. Null otherwise.
  final HoldFault? fault;

  /// Set once [state] is [HoldState.ended].
  final HoldEnd? end;

  int get warningCount => warnings.length;

  bool get ended => state == HoldState.ended;

  /// Whether the time is stopped by a warning: the clock reads 멈춤.
  bool get paused => state == HoldState.paused;

  @override
  String toString() =>
      'HoldProgress(${state.name}, ${held.inMilliseconds} ms, '
      '${warnings.map((f) => f.id).toList()}, fault: ${fault?.id}, '
      'end: ${end?.name})';
}
