import '../../models/hold_progress.dart';
import '../../models/hold_reading.dart';
import '../../models/pose_frame.dart';
import 'hold_pose_definition.dart';
import 'rep_judge.dart';

/// The common part's times (arcade hold spec 3). They are the spec's
/// starting values; a change after the phone check is written in the
/// testing notes.
abstract final class HoldTiming {
  /// A broken pose for this long gives a warning and stops the time.
  static const warn = Duration(milliseconds: 500);

  /// A held pose for this long runs the time again after a warning, and
  /// starts it after an entry.
  static const resume = Duration(milliseconds: 600);

  /// An unknown pose for longer than this reads as off screen; until then
  /// the reading before it stands.
  static const unknownGrace = Duration(seconds: 1);

  /// The warning that ends the stage.
  static const maxWarnings = 2;

  /// The owner's start bubble after GO, for a pose held from GO (the hold
  /// effects spec 3). A pose with an entry keeps it until the time starts.
  static const startBubble = Duration(seconds: 2);

  /// The owner's cheer bubble and smile at the first and second star
  /// (effects spec 4).
  static const cheer = Duration(seconds: 1);

  /// A filled star's pop on the bar: bigger, then back (effects spec 4).
  static const starPop = Duration(milliseconds: 300);

  /// From a second warning to the result: the warning stays, the owner
  /// says "실패!" when no star was earned, and nothing is judged (effects
  /// spec 5).
  static const endShow = Duration(milliseconds: 1500);

  /// The "실패!" bubble's entrance: big, then in place (effects spec 5).
  static const failPop = Duration(milliseconds: 200);
}

/// The time and the warnings of one hold, from a stream of readings on a
/// clock given from outside (spec 3, "시간과 경고"). The same for every
/// pose; pure, so tests can run the clock as they like.
///
/// - The time held runs only while the pose is held: between a frame read
///   as held and the next one. Nothing before [start], while entering, or
///   while paused.
/// - A pose broken for [HoldTiming.warn] gives a warning and pauses. Its
///   fault is the one read most often in that run (the latest of a tie).
/// - Held again for [HoldTiming.resume], the time runs again. While paused
///   no warning is added, however long the pose stays broken.
/// - The [HoldTiming.maxWarnings]th warning ends the hold, as does the time
///   held reaching [endsAt].
/// - An unknown reading keeps the reading before it for
///   [HoldTiming.unknownGrace]; after that it is [HoldFault.offScreen].
/// - With [entry], the time stays at zero, with no warning, until the pose
///   is first held for [HoldTiming.resume].
class HoldTimeline {
  HoldTimeline({required this.endsAt, this.entry = false});

  /// The time held that ends the hold: the stage's third star.
  final Duration endsAt;

  /// Whether the pose is entered after GO.
  final bool entry;

  HoldState _state = HoldState.holding;
  bool _started = false;
  Duration _held = Duration.zero;
  final List<HoldFault> _warnings = [];
  HoldFault? _fault;
  HoldEnd? _end;

  /// When the last reading came.
  Duration? _lastAt;

  /// The reading in force since [_lastAt]: what an unknown reading keeps.
  HoldReading? _effective;

  /// When the unknown readings began; null after a known one.
  Duration? _unknownSince;

  /// The current run of held or broken readings, and when it began.
  HoldReadingKind? _runKind;
  Duration _runSince = Duration.zero;

  /// How often each fault was read in the current broken run, and when it
  /// was last read (a count of readings), for the warning's fault.
  final Map<HoldFault, int> _counts = {};
  final Map<HoldFault, int> _lastSeen = {};
  int _readings = 0;

  /// Whether [start] has been called.
  bool get started => _started;

  HoldProgress get progress => HoldProgress(
    state: _state,
    held: _held,
    warnings: List.unmodifiable(_warnings),
    fault: _state == HoldState.paused ? _fault : null,
    end: _end,
  );

  /// GO, at [at]: the hold begins.
  void start(Duration at) {
    if (_started) return;
    _started = true;
    _state = entry ? HoldState.entering : HoldState.holding;
    _lastAt = at;
  }

  /// The reading of a frame seen at [at]. Readings before [start] or after
  /// the end change nothing. A time before the last one is taken as the
  /// last one.
  HoldProgress update(HoldReading reading, Duration at) {
    if (!_started || _state == HoldState.ended) return progress;
    final last = _lastAt!;
    final now = at < last ? last : at;

    // The time between the last reading and this one was held if the pose
    // was held then and the time was running.
    if (_state == HoldState.holding && _effective?.kind == HoldReadingKind.ok) {
      _held += now - last;
      if (_held >= endsAt) {
        _held = endsAt;
        _lastAt = now;
        _finish(HoldEnd.held);
        return progress;
      }
    }
    _lastAt = now;
    _readings += 1;

    // An unknown reading keeps the one before it for a while, then is off
    // screen from the moment the grace ran out.
    var effective = reading;
    var runStart = now;
    if (reading.kind == HoldReadingKind.unknown) {
      final since = _unknownSince ??= now;
      if (now - since > HoldTiming.unknownGrace) {
        effective = const HoldReading.broken(HoldFault.offScreen);
        runStart = since + HoldTiming.unknownGrace;
      } else {
        effective = _effective ?? HoldReading.unknown;
      }
    } else {
      _unknownSince = null;
    }
    _effective = effective;

    switch (effective.kind) {
      case HoldReadingKind.ok:
        if (_runKind != HoldReadingKind.ok) {
          _runKind = HoldReadingKind.ok;
          _runSince = runStart;
          _clearCounts();
        }
      case HoldReadingKind.broken:
        if (_runKind != HoldReadingKind.broken) {
          _runKind = HoldReadingKind.broken;
          _runSince = runStart;
          _clearCounts();
        }
        final fault = effective.fault!;
        _counts[fault] = (_counts[fault] ?? 0) + 1;
        _lastSeen[fault] = _readings;
      case HoldReadingKind.unknown:
        // Nothing read yet since GO: no run.
        _runKind = null;
        _clearCounts();
    }

    final runFor = now - _runSince;
    switch (_state) {
      case HoldState.entering:
        if (_runKind == HoldReadingKind.ok && runFor >= HoldTiming.resume) {
          _state = HoldState.holding;
        }
      case HoldState.holding:
        if (_runKind == HoldReadingKind.broken && runFor >= HoldTiming.warn) {
          final fault = _mostRead();
          _warnings.add(fault);
          _fault = fault;
          _state = HoldState.paused;
          if (_warnings.length >= HoldTiming.maxWarnings) {
            _finish(HoldEnd.warnings);
          }
        }
      case HoldState.paused:
        if (_runKind == HoldReadingKind.ok) {
          if (runFor >= HoldTiming.resume) {
            _state = HoldState.holding;
            _fault = null;
          }
        } else if (effective.kind == HoldReadingKind.broken) {
          _fault = effective.fault;
        }
      case HoldState.ended:
        break;
    }
    return progress;
  }

  /// The fault read most often in the current broken run; of a tie, the
  /// one read last.
  HoldFault _mostRead() {
    HoldFault? best;
    for (final MapEntry(key: fault, value: count) in _counts.entries) {
      if (best == null ||
          count > _counts[best]! ||
          (count == _counts[best]! && _lastSeen[fault]! > _lastSeen[best]!)) {
        best = fault;
      }
    }
    return best!;
  }

  void _clearCounts() {
    _counts.clear();
    _lastSeen.clear();
  }

  void _finish(HoldEnd end) {
    _state = HoldState.ended;
    _end = end;
  }
}

/// One play of a hold stage: a pose's reader in front of the [HoldTimeline]
/// (spec 3). Frames of the 3·2·1 go to the reader only ([countdown]); from
/// [go] on each frame's reading goes on to the time and the warnings.
class HoldJudge {
  HoldJudge({required this.definition, required Duration endsAt})
    : _reader = definition.createReader(),
      _timeline = HoldTimeline(endsAt: endsAt, entry: definition.entry);

  final HoldPoseDefinition definition;
  final HoldPoseReader _reader;
  final HoldTimeline _timeline;
  HoldReading? _lastReading;

  HoldProgress get progress => _timeline.progress;

  /// Whether [go] has been called.
  bool get started => _timeline.started;

  /// What the reader made of the last frame after GO; null before one.
  HoldReading? get lastReading => _lastReading;

  /// Whether the reader gives the guide lines itself ([HoldGuideReader]).
  bool get readsGuide => _reader is HoldGuideReader;

  /// The guide lines' state from the reader after the last frame it read;
  /// null when the reader gives none.
  JudgeSnapshot? get guide => switch (_reader) {
    HoldGuideReader(:final guide) => guide,
    _ => null,
  };

  /// A frame of the 3·2·1, seen at [at]: read for the reader's baselines,
  /// and not used for the time or the warnings.
  void countdown(PoseFrame frame, Duration at) {
    if (started) return;
    _reader.read(frame, at: at, counting: true);
  }

  /// GO, at [at].
  void go(Duration at) => _timeline.start(at);

  /// A frame after GO, seen at [at].
  HoldProgress frame(PoseFrame frame, Duration at) {
    if (!started || progress.ended) return progress;
    final reading = _reader.read(frame, at: at);
    _lastReading = reading;
    return _timeline.update(reading, at);
  }

  /// No frame came by [at]: the pose is unknown then.
  HoldProgress missing(Duration at) {
    if (!started || progress.ended) return progress;
    return _timeline.update(HoldReading.unknown, at);
  }
}
