import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_floor.dart';
import '../models/arcade_stage.dart';
import '../models/exercise_type.dart';
import '../models/hold_progress.dart';
import '../models/hold_reading.dart';
import '../models/hold_record.dart';
import '../models/pose_frame.dart';
import '../models/setup_silhouette_alignment.dart';
import '../models/setup_squat_silhouette_alignment.dart';
import '../services/arcade/arcade_progress_store.dart';
import '../services/arcade/arcade_star_judge.dart';
import '../services/feedback/hold_record_store.dart';
import '../services/pose/exercise_judge.dart';
import '../services/pose/hold_judge.dart';
import '../services/pose/hold_pose_definition.dart';
import '../services/pose/hold_poses.dart';
import '../services/pose/rep_judge.dart';
import '../services/pose/setup_checker.dart';
import 'setup_viewmodel.dart';

/// Where a hold stage is (arcade hold spec 2).
enum HoldStagePhase {
  /// The briefing card, before 자세 잡기.
  brief,

  /// The camera and the pose setup of the pose's exercise.
  setup,

  /// The setup holds: 3·2·1 before GO. A pose that breaks goes back to
  /// [setup].
  countdown,

  /// From GO: the pose is held, paused by warnings.
  hold,

  /// The hold ended: [HoldStageState.stars] tell clear or fail.
  result,
}

/// A moment the screen makes heard: a sound, and a short line for a screen
/// reader (spec 5, 8). [started] is the end of an entry: the time begins
/// to run (the chair pose's spec 6). [callout] is a bubble of the owner's
/// (the hold effects spec 6): its words are read as a warning's are.
enum HoldStageCueKind { warning, resumed, started, star, callout, ended }

class HoldStageCue {
  const HoldStageCue(
    this.kind, {
    this.count = 0,
    this.fault,
    this.seconds,
    this.words,
  });

  final HoldStageCueKind kind;

  /// A warning's number, a star's number, or the stars at the end.
  final int count;

  /// A warning's fault.
  final HoldFault? fault;

  /// A star's seconds.
  final int? seconds;

  /// A callout's words, its lines as one.
  final String? words;

  @override
  String toString() => 'HoldStageCue(${kind.name}, $count, ${fault?.id})';
}

/// What the floor's owner says over the stage besides "삐익!" (the hold
/// effects spec 3 to 5).
enum HoldCalloutKind {
  /// Right after GO: the pose's start words, in the whistle's white bubble.
  start,

  /// At the first or second star: a big lime bubble, with a smile.
  cheer,

  /// At a second warning that leaves no star: a big red bubble.
  fail,
}

/// One of the owner's bubbles: its kind and its lines.
class HoldCallout {
  const HoldCallout.start(this.lines) : kind = HoldCalloutKind.start, star = 0;

  HoldCallout.cheer(this.star)
    : kind = HoldCalloutKind.cheer,
      lines = [HoldWords.cheer(star)!];

  const HoldCallout.fail()
    : kind = HoldCalloutKind.fail,
      lines = const [HoldWords.fail],
      star = 0;

  final HoldCalloutKind kind;

  /// The bubble's lines.
  final List<String> lines;

  /// The star a cheer is for, 1 or 2; 0 for the others.
  final int star;

  /// The lines as one, for a screen reader.
  String get words => lines.join(' ');

  @override
  String toString() => 'HoldCallout(${kind.name}, $words)';
}

/// What the hold screen shows: an immutable snapshot.
class HoldStageState {
  const HoldStageState({
    this.phase = HoldStagePhase.brief,
    this.progress = const HoldProgress(),
    this.startIn,
    this.stars = ArcadeStars.none,
    this.guide = JudgeSnapshot.initial,
    this.callout,
    this.ending = false,
    this.record,
  });

  final HoldStagePhase phase;

  /// The time held and the warnings, from GO.
  final HoldProgress progress;

  /// In [HoldStagePhase.countdown], the time left before GO.
  final Duration? startIn;

  /// The stars of the play, at [HoldStagePhase.result].
  final ArcadeStars stars;

  /// The guide lines over the camera, from the frames from GO: the pose's
  /// reader's when it gives them ([HoldGuideReader]), else the setup
  /// exercise's judge's.
  final JudgeSnapshot guide;

  /// The owner's bubble over the stage, if any; a warning's "삐익!" is drawn
  /// from [progress] instead.
  final HoldCallout? callout;

  /// From a second warning to the result ([HoldTiming.endShow]): the hold
  /// ended, its last warning stays on screen, and nothing is judged.
  /// [stars] are the play's already.
  final bool ending;

  /// The play kept for its report and the archive (P13), from the end of the
  /// hold; null before it.
  final HoldRecord? record;

  /// Whether the clock stands and the warning shows: paused, or [ending].
  bool get stopped =>
      ending || (phase == HoldStagePhase.hold && progress.paused);

  /// The warning the camera box shows: the paused one, or while [ending]
  /// the last.
  HoldFault? get shownFault => ending
      ? (progress.warnings.isEmpty ? null : progress.warnings.last)
      : (progress.paused ? progress.fault : null);

  HoldStageState copyWith({
    HoldStagePhase? phase,
    HoldProgress? progress,
    Duration? startIn,
    bool clearStartIn = false,
    ArcadeStars? stars,
    JudgeSnapshot? guide,
    HoldCallout? callout,
    bool clearCallout = false,
    bool? ending,
    HoldRecord? record,
  }) => HoldStageState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    startIn: clearStartIn ? null : startIn ?? this.startIn,
    stars: stars ?? this.stars,
    guide: guide ?? this.guide,
    callout: clearCallout ? null : callout ?? this.callout,
    ending: ending ?? this.ending,
    record: record ?? this.record,
  );
}

/// One hold stage, from its briefing to its result (spec 2).
///
/// 자세 잡기 opens the camera on the battle's own pose setup for the pose
/// ([SetupViewModel] of [HoldPoseDefinition.setupExercise], unchanged): its
/// silhouette and cues, and its 3 s auto start as the 3·2·1. The frames of
/// the 3·2·1 go to the pose's reader for its baselines; at GO the hold
/// begins ([HoldJudge]), and every frame after it is read and timed.
///
/// The hold's clock is [clock] minus the time the camera was not running
/// (the app in the background, a camera switch or failure): that time is
/// neither held nor broken. While the camera runs and no frame has come for
/// [missingAfter], the pose is unknown.
///
/// When the hold ends the stars are counted from the time held
/// ([ArcadeStarJudge.hold]) and kept in [store] for [accountId], when both
/// are given; the camera is let go. Stages are not battles: nothing goes to
/// the match records (spec 10). The play itself (time held, warnings and
/// pauses from GO, stars) is kept in [records] for its report and the
/// archive (P13), on the phone only.
class HoldStageViewModel extends ChangeNotifier {
  HoldStageViewModel({
    required int stage,
    HoldPoseDefinition? definition,
    this.store,
    this.accountId,
    this.records,
    DateTime Function()? wallClock,
    SetupViewModel Function(
      ExerciseType exercise,
      bool Function(PoseFrame, Size, bool) guideMatcher,
    )?
    createSetup,
    ExerciseRepJudge Function(ExerciseType exercise)? createGuideJudge,
    Clock? clock,
    this.missingAfter = const Duration(milliseconds: 250),
    this.tick = const Duration(milliseconds: 100),
  }) : stage = _holdStage(stage),
       _createSetup = createSetup ?? _defaultSetup,
       _createGuideJudge = createGuideJudge ?? judgeFor,
       _clock = clock ?? _stopwatchClock(),
       _wallClock = wallClock ?? DateTime.now {
    floor = ArcadeCatalog.floorOf(this.stage);
    this.definition = definition ?? HoldPoses.of(this.stage.pose);
  }

  final ArcadeHoldStage stage;
  late final ArcadeFloor floor;

  /// The pose's bundle: `HoldPoses.of` the stage's pose unless one is
  /// given (tests, and a pose before its line in `HoldPoses`).
  late final HoldPoseDefinition definition;

  /// Where the stars are kept; null keeps none.
  final ArcadeProgressStore? store;
  final int? accountId;

  /// Where the plays are kept for their report (P13); null keeps none.
  final HoldRecordStore? records;
  final DateTime Function() _wallClock;

  /// From GO: when it was, the warnings and the pauses so far, and when the
  /// open pause began.
  Duration _goAt = Duration.zero;
  final List<HoldRecordWarning> _warnings = [];
  final List<HoldRecordPause> _pauses = [];
  Duration? _pausedAt;

  /// With the camera running, no frame for this long is an unknown pose.
  final Duration missingAfter;

  /// How often the missing frames are looked for.
  final Duration tick;

  final SetupViewModel Function(
    ExerciseType exercise,
    bool Function(PoseFrame, Size, bool) guideMatcher,
  )
  _createSetup;
  final ExerciseRepJudge Function(ExerciseType exercise) _createGuideJudge;
  final Clock _clock;

  final _cues = StreamController<HoldStageCue>.broadcast();

  HoldStageState _state = const HoldStageState();
  SetupViewModel? _setup;
  HoldJudge? _judge;
  ExerciseRepJudge? _guideJudge;
  PoseFrame? _seen;
  SetupCameraCrop? _crop;
  Timer? _ticker;

  /// Drops the owner's bubble when its time is up.
  Timer? _calloutTimer;

  /// Shows the result after a second warning's [HoldTiming.endShow].
  Timer? _endTimer;
  bool _disposed = false;

  /// The hold's clock: the time the camera was not running is left out.
  Duration _frozenTotal = Duration.zero;
  Duration? _frozenSince;
  Duration _lastFrameAt = Duration.zero;

  static ArcadeHoldStage _holdStage(int number) {
    final stage = ArcadeCatalog.stage(number);
    assert(stage is ArcadeHoldStage, 'Stage $number is not a hold stage.');
    return stage as ArcadeHoldStage;
  }

  static Clock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  static SetupViewModel _defaultSetup(
    ExerciseType exercise,
    bool Function(PoseFrame, Size, bool) guideMatcher,
  ) => SetupViewModel(exercise: exercise, guideMatcher: guideMatcher);

  HoldStageState get state => _state;

  /// The camera and the setup while there is one: from 자세 잡기 to the end.
  SetupViewModel? get setup => _setup;

  /// The moments to make heard, as they happen.
  Stream<HoldStageCue> get cues => _cues.stream;

  /// The frame the hold read last, for the guide lines.
  PoseFrame? get lastFrame => _seen;

  /// 자세 잡기: opens the camera on the pose's setup.
  Future<void> startPose() async {
    if (_disposed || _state.phase != HoldStagePhase.brief) return;
    final setup = _createSetup(definition.setupExercise, _matchesGuide);
    _setup = setup;
    _judge = HoldJudge(definition: definition, endsAt: stage.endsAt);
    _guideJudge = null;
    _seen = null;
    _frozenTotal = Duration.zero;
    _frozenSince = _clock();
    setup.addListener(_onSetup);
    _setState(const HoldStageState(phase: HoldStagePhase.setup));
    await setup.start();
  }

  /// Where the camera box drew the setup's push-up guide, for the setup's
  /// check: the battle's own alignment.
  void setGuideCrop(SetupCameraCrop crop) => _crop = crop;

  /// The camera box's size, for the setup's check.
  void setGuideViewport(Size size) => _setup?.setGuideViewport(size);

  bool _matchesGuide(PoseFrame frame, Size viewport, bool mirror) {
    final minLikelihood = const SetupConfig().minLikelihood;
    return switch (definition.setupExercise) {
      ExerciseType.pushUp => switch (_crop) {
        final crop? => SetupSilhouetteAlignment(
          minLikelihood: minLikelihood,
        ).matchesImageCrop(frame, crop, mirror: mirror),
        null => false,
      },
      ExerciseType.squat =>
        StandingSilhouetteAlignment(minLikelihood: minLikelihood).matches(
          frame,
          Size(frame.imageWidth, frame.imageHeight),
          mirror: mirror,
        ),
    };
  }

  /// The app went to the background: the camera, and the hold's clock,
  /// stop.
  Future<void> pause() async => _setup?.pause();

  /// The app came back.
  Future<void> resume() async => _setup?.resume();

  /// 다시 하기, 다시 도전: the briefing again, for a new play.
  void playAgain() {
    if (_disposed || _state.phase != HoldStagePhase.result) return;
    _closeSetup();
    _judge = null;
    _setState(const HoldStageState());
  }

  /// Leaving: the camera is let go, and nothing is kept.
  void leave() {
    if (_disposed) return;
    _ticker?.cancel();
    _ticker = null;
    _cancelTimers();
    final setup = _setup;
    if (setup != null) unawaited(setup.releaseCamera());
  }

  Duration _now() {
    final frozen = _frozenSince;
    return _clock() -
        _frozenTotal -
        (frozen == null ? Duration.zero : _clock() - frozen);
  }

  void _onSetup() {
    final setup = _setup;
    if (_disposed || setup == null) return;
    final setupState = setup.state;
    _followCamera(setupState.phase == SetupPhase.running);
    switch (_state.phase) {
      case HoldStagePhase.setup || HoldStagePhase.countdown:
        _setUp(setupState);
      case HoldStagePhase.hold:
        _hold(setupState.lastFrame);
      case HoldStagePhase.brief || HoldStagePhase.result:
        break;
    }
  }

  /// The hold's clock stands while the camera is not running.
  void _followCamera(bool running) {
    final frozen = _frozenSince;
    if (running && frozen != null) {
      _frozenTotal += _clock() - frozen;
      _frozenSince = null;
      _lastFrameAt = _now();
    } else if (!running && frozen == null) {
      _frozenSince = _clock();
    }
  }

  void _setUp(SetupState setupState) {
    if (setupState.autoStarted) {
      _go();
      return;
    }
    final left = setupState.autoStartIn;
    final frame = setupState.lastFrame;
    if (left != null) {
      if (frame != null && !identical(frame, _seen)) {
        _seen = frame;
        _judge!.countdown(frame, _now());
      }
      _setState(
        _state.copyWith(phase: HoldStagePhase.countdown, startIn: left),
      );
    } else {
      _setState(
        _state.copyWith(phase: HoldStagePhase.setup, clearStartIn: true),
      );
    }
  }

  /// GO: the hold begins now.
  void _go() {
    final judge = _judge!;
    final now = _now();
    judge.go(now);
    _lastFrameAt = now;
    _goAt = now;
    _warnings.clear();
    _pauses.clear();
    _pausedAt = null;
    _guideJudge = judge.readsGuide
        ? null
        : _createGuideJudge(definition.setupExercise);
    _ticker = Timer.periodic(tick, (_) => _lookForFrames());
    final words = definition.startWords;
    final callout = words.isEmpty ? null : HoldCallout.start(words);
    _setState(
      _state.copyWith(
        phase: HoldStagePhase.hold,
        progress: judge.progress,
        clearStartIn: true,
        callout: callout,
        clearCallout: callout == null,
      ),
    );
    if (callout != null) {
      _cue(HoldStageCue(HoldStageCueKind.callout, words: callout.words));
      // A pose with an entry keeps it until the time starts (in [_show]).
      if (!definition.entry) _dropLater(callout, HoldTiming.startBubble);
    }
  }

  void _hold(PoseFrame? frame) {
    if (frame == null ||
        identical(frame, _seen) ||
        _frozenSince != null ||
        _state.ending) {
      return;
    }
    _seen = frame;
    final now = _now();
    _lastFrameAt = now;
    final judge = _judge!;
    final progress = judge.frame(frame, now);
    _show(progress, guide: judge.guide ?? _guideJudge?.update(frame).snapshot);
  }

  void _lookForFrames() {
    final judge = _judge;
    if (_disposed ||
        judge == null ||
        _state.phase != HoldStagePhase.hold ||
        _state.ending ||
        _frozenSince != null) {
      return;
    }
    final now = _now();
    if (now - _lastFrameAt < missingAfter) return;
    _show(judge.missing(now));
  }

  /// Shows [progress], making its moments heard, and ends the stage when it
  /// ended.
  void _show(HoldProgress progress, {JudgeSnapshot? guide}) {
    final before = _state.progress;
    _log(before, progress);
    var callout = _state.callout;
    if (progress.warningCount > before.warningCount) {
      _cue(
        HoldStageCue(
          HoldStageCueKind.warning,
          count: progress.warningCount,
          fault: progress.warnings.last,
        ),
      );
      // A warning takes the owner's bubble (effects spec 3, 4).
      callout = null;
    } else if (before.paused && progress.state == HoldState.holding) {
      _cue(const HoldStageCue(HoldStageCueKind.resumed));
    } else if (before.state == HoldState.entering &&
        progress.state == HoldState.holding) {
      _cue(const HoldStageCue(HoldStageCueKind.started));
      if (callout?.kind == HoldCalloutKind.start) callout = null;
    }
    final times = stage.starSeconds;
    for (var i = 0; i < times.length; i++) {
      final at = Duration(seconds: times[i]);
      if (before.held < at && progress.held >= at) {
        _cue(
          HoldStageCue(HoldStageCueKind.star, count: i + 1, seconds: times[i]),
        );
        // The first two stars are cheered; the third ends it as a clear.
        if (!progress.ended && HoldWords.cheer(i + 1) != null) {
          callout = HoldCallout.cheer(i + 1);
          _dropLater(callout, HoldTiming.cheer);
        }
      }
    }
    if (!progress.ended) {
      _setState(
        _state.copyWith(
          progress: progress,
          guide: guide,
          callout: callout,
          clearCallout: callout == null,
        ),
      );
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    _calloutTimer?.cancel();
    _calloutTimer = null;
    final stars = ArcadeStarJudge.hold(stage, progress.held);
    final record = _record(progress, stars);
    if (progress.end != HoldEnd.warnings) {
      _setState(
        _state.copyWith(
          progress: progress,
          stars: stars,
          guide: guide,
          clearCallout: true,
          record: record,
        ),
      );
      _finish();
      return;
    }
    // The second warning stays for [HoldTiming.endShow] before the result,
    // with "실패!" when it leaves no star (effects spec 5).
    final fail = stars.count == 0 ? const HoldCallout.fail() : null;
    _setState(
      _state.copyWith(
        progress: progress,
        stars: stars,
        guide: guide,
        ending: true,
        callout: fail,
        clearCallout: fail == null,
        record: record,
      ),
    );
    if (fail != null) {
      _cue(HoldStageCue(HoldStageCueKind.callout, words: fail.words));
    }
    _endTimer = Timer(HoldTiming.endShow, () {
      _endTimer = null;
      _finish();
    });
  }

  /// The result: the stars of [HoldStageState.stars], kept; the camera let
  /// go.
  void _finish() {
    if (_disposed) return;
    final stars = _state.stars;
    _setState(
      _state.copyWith(
        phase: HoldStagePhase.result,
        ending: false,
        clearCallout: true,
      ),
    );
    _cue(HoldStageCue(HoldStageCueKind.ended, count: stars.count));
    final setup = _setup;
    if (setup != null) unawaited(setup.releaseCamera());
    unawaited(_save(stars));
  }

  /// Drops [callout] after [after], unless another took its place.
  void _dropLater(HoldCallout callout, Duration after) {
    _calloutTimer?.cancel();
    _calloutTimer = Timer(after, () {
      _calloutTimer = null;
      if (identical(_state.callout, callout)) {
        _setState(_state.copyWith(clearCallout: true));
      }
    });
  }

  void _cancelTimers() {
    _calloutTimer?.cancel();
    _calloutTimer = null;
    _endTimer?.cancel();
    _endTimer = null;
  }

  /// The warnings and pauses of the hold, from GO (P13).
  void _log(HoldProgress before, HoldProgress progress) {
    final at = _now() - _goAt;
    if (progress.warningCount > before.warningCount) {
      final fault = progress.warnings.last;
      _warnings.add(
        HoldRecordWarning(at: at, faultId: fault.id, words: fault.words),
      );
    }
    final pausedAt = _pausedAt;
    if (progress.paused && pausedAt == null) {
      _pausedAt = at;
    } else if (!progress.paused && pausedAt != null) {
      _pauses.add(HoldRecordPause(start: pausedAt, end: at));
      _pausedAt = null;
    }
  }

  /// The play as kept for its report: [progress] at its end.
  HoldRecord _record(HoldProgress progress, ArcadeStars stars) => HoldRecord(
    accountId: accountId,
    endedAt: _wallClock(),
    pose: stage.pose,
    stage: stage.number,
    held: progress.held,
    elapsed: _now() - _goAt,
    stars: stars.count,
    starSeconds: stage.starSeconds,
    warnings: List.unmodifiable(_warnings),
    pauses: List.unmodifiable(_pauses),
    endedByWarnings: progress.end == HoldEnd.warnings,
  );

  /// Keeps the play's stars: the store keeps a stage's most.
  Future<void> _save(ArcadeStars stars) async {
    final record = _state.record;
    final records = this.records;
    if (record != null && records != null) {
      try {
        await records.save(record);
      } on Object {
        // The report of this play is lost; the stars are kept below.
      }
    }
    final store = this.store;
    final account = accountId;
    if (store == null || account == null) return;
    try {
      await store.recordStage(account, stage.number, stars.count);
    } on Object {
      // The stars of this play are lost; the saved ones stay (A2's store
      // writes nothing when it cannot read).
    }
  }

  void _cue(HoldStageCue cue) {
    if (!_cues.isClosed) _cues.add(cue);
  }

  void _closeSetup() {
    _ticker?.cancel();
    _ticker = null;
    _cancelTimers();
    final setup = _setup;
    _setup = null;
    if (setup != null) {
      setup.removeListener(_onSetup);
      setup.dispose();
    }
  }

  void _setState(HoldStageState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _closeSetup();
    unawaited(_cues.close());
    super.dispose();
  }
}
