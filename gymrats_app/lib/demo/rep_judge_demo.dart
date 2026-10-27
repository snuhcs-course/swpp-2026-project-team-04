// Standalone push-up rep judge demo and error-case recorder.
//
// Run from gymrats_app/ (the commit goes into each recording):
//   flutter run -t lib/demo/rep_judge_demo.dart -d <device-id> \
//     --dart-define=GIT_COMMIT=$(git rev-parse --short HEAD)
//
// Needs no login, server, or battle screen. Pick what the set will show
// (normal push-ups, knees on the floor, ...), the setup, and the ML Kit
// model. Setup runs first, then the round counter. Stop, or the end of the
// round, shows the result and saves the recording: every judged frame's 33
// landmarks, the phone sensor values, the image brightness, and the live
// verdicts, plus every setup frame with the setup check's result, as JSON
// in the app's own files folder. No camera image is stored.
//
// Copy the recordings to the repo with
//   powershell tools/diagnose/Pull-PushupCases.ps1      (Windows)
//   bash tools/diagnose/pull_pushup_cases.sh            (macOS, Linux)
// They land in test/fixtures/pushup_cases/, where
// test/services/pose/pushup_error_cases_test.dart replays them.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/pose_frame.dart';
import '../models/rep_event.dart';
import '../screens/setup_screen.dart';
import '../services/device/phone_tilt.dart';
import '../services/pose/camera_service.dart';
import '../services/pose/pose_estimator.dart';
import '../services/pose/rep_judge.dart';
import '../services/pose/setup_checker.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../viewmodels/setup_viewmodel.dart';
import '../widgets/pose_avatar_toggle_view.dart';

/// Keys the widget tests look up.
const validRepsKey = Key('validReps');
const invalidRepsKey = Key('invalidReps');
const repPhaseKey = Key('repPhase');
const repFlashKey = Key('repFlash');
const stopRoundKey = Key('stopRound');
const roundResultKey = Key('roundResult');
const remainingTimeKey = Key('remainingTime');
const caseKindKey = Key('caseKind');
const repsFieldKey = Key('repsField');
const personFieldKey = Key('personField');
const heightFieldKey = Key('heightField');
const deviceFieldKey = Key('deviceField');
const placementFieldKey = Key('placementField');
const noteFieldKey = Key('noteField');
const armFieldKey = Key('armField');
const shoulderFieldKey = Key('shoulderField');
const recordSwitchKey = Key('recordSwitch');
const startRecordingKey = Key('startRecording');
const saveStatusKey = Key('saveStatus');
const expectedResultKey = Key('expectedResult');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const RepJudgeDemoApp());
}

/// What a recorded set is meant to show. Each kind that is a cheat names
/// the reason every rep of the set should be rejected with.
enum CaseKind {
  normal('Normal push-ups'),
  knees('Knees on the floor', RejectReason.kneesDown),
  halfRepHeadNod('Half rep + head nod', RejectReason.insufficientDepth),
  bellyDown('Belly on the floor', RejectReason.bellyDown),
  armsStraight('Straight arms, head dips', RejectReason.armsStraight),
  notFloor('Standing or wall', RejectReason.notFloorPushUp),
  shouldersTilted('Shoulders tilted', RejectReason.shouldersNotLevel),
  phoneMoved('Phone moved', RejectReason.phoneMoved),

  /// Kept for analysis only. The replay test does not check it.
  unlabelled('Free (no label)');

  const CaseKind(this.label, [this.reason]);

  final String label;
  final RejectReason? reason;
}

/// The result a set should get: how many reps count, and how many are
/// rejected with each reason.
class CaseExpectation {
  const CaseExpectation({required this.valid, this.rejected = const {}});

  /// [reps] of [kind], all counted or all rejected with its reason. Null
  /// for [CaseKind.unlabelled].
  static CaseExpectation? of(CaseKind kind, int reps) {
    if (kind == CaseKind.unlabelled) return null;
    final reason = kind.reason;
    return reason == null
        ? CaseExpectation(valid: reps)
        : CaseExpectation(valid: 0, rejected: {reason: reps});
  }

  final int valid;
  final Map<RejectReason, int> rejected;

  Map<String, Object?> toJson() => {
    'valid': valid,
    'rejected': {for (final e in rejected.entries) e.key.name: e.value},
  };

  static CaseExpectation fromJson(Map<String, Object?> json) => CaseExpectation(
    valid: json['valid']! as int,
    rejected: {
      for (final e in (json['rejected'] as Map? ?? const {}).entries)
        RejectReason.values.byName(e.key as String): e.value as int,
    },
  );

  @override
  String toString() => [
    if (valid > 0 || rejected.isEmpty) '$valid valid',
    for (final e in rejected.entries) '${e.value} × ${e.key.message}',
  ].join(', ');
}

/// The user's label for a set. [expected] is stored, not derived, so a
/// mixed set can be fixed by hand in the JSON.
class RecordingLabel {
  const RecordingLabel({
    required this.kind,
    required this.reps,
    required this.expected,
    this.perRep,
    this.note = '',
  });

  RecordingLabel.of(this.kind, this.reps, {this.note = ''})
    : expected = CaseExpectation.of(kind, reps),
      perRep = null;

  final CaseKind kind;
  final int reps;
  final CaseExpectation? expected;

  /// Each rep's verdict in order, null for a counted rep. Written by hand
  /// for a mixed set, so a false count and a missed rep cannot cancel out
  /// in the totals. Null when only [expected] is labelled.
  final List<RejectReason?>? perRep;
  final String note;

  /// How [perRep] writes a counted rep.
  static const validRep = 'valid';

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'reps': reps,
    'expected': expected?.toJson(),
    if (perRep case final reps?)
      'perRep': [for (final r in reps) r?.name ?? validRep],
    'note': note,
  };

  static RecordingLabel fromJson(Map<String, Object?> json) => RecordingLabel(
    kind: CaseKind.values.byName(json['kind']! as String),
    reps: json['reps']! as int,
    expected: switch (json['expected']) {
      final Map<String, Object?> e => CaseExpectation.fromJson(e),
      _ => null,
    },
    perRep: switch (json['perRep']) {
      final List reps => [
        for (final r in reps)
          r == validRep ? null : RejectReason.values.byName(r as String),
      ],
      _ => null,
    },
    note: json['note'] as String? ?? '',
  );
}

/// How the set was filmed.
class RecordingSetup {
  const RecordingSetup({
    this.person = '',
    this.heightCm,
    this.armCm,
    this.shoulderCm,
    this.device = '',
    this.placement = '',
    this.lighting = 'bright',
    this.model = PoseDetectionModel.accurate,
    this.roundLength = battleDuration,
  });

  static const lightings = ['bright', 'dim', 'backlit'];

  /// Who did the set, as initials or a nickname.
  final String person;
  final int? heightCm;

  /// Shoulder to wrist, and shoulder to shoulder, measured on the person.
  final int? armCm;
  final int? shoulderCm;
  final String device;

  /// Free text: phone distance, height, and angle to the user.
  final String placement;
  final String lighting;
  final PoseDetectionModel model;
  final Duration roundLength;

  RecordingSetup copyWith({
    String? person,
    int? heightCm,
    bool clearHeight = false,
    int? armCm,
    bool clearArm = false,
    int? shoulderCm,
    bool clearShoulder = false,
    String? device,
    String? placement,
    String? lighting,
    PoseDetectionModel? model,
    Duration? roundLength,
  }) => RecordingSetup(
    person: person ?? this.person,
    heightCm: clearHeight ? null : heightCm ?? this.heightCm,
    armCm: clearArm ? null : armCm ?? this.armCm,
    shoulderCm: clearShoulder ? null : shoulderCm ?? this.shoulderCm,
    device: device ?? this.device,
    placement: placement ?? this.placement,
    lighting: lighting ?? this.lighting,
    model: model ?? this.model,
    roundLength: roundLength ?? this.roundLength,
  );

  Map<String, Object?> toJson() => {
    'person': person,
    'heightCm': heightCm,
    'armCm': armCm,
    'shoulderCm': shoulderCm,
    'device': device,
    'placement': placement,
    'lighting': lighting,
    'model': model.name,
    'roundSeconds': roundLength.inSeconds,
  };

  static RecordingSetup fromJson(Map<String, Object?> json) => RecordingSetup(
    person: json['person'] as String? ?? '',
    heightCm: json['heightCm'] as int?,
    armCm: json['armCm'] as int?,
    shoulderCm: json['shoulderCm'] as int?,
    device: json['device'] as String? ?? '',
    placement: json['placement'] as String? ?? '',
    lighting: json['lighting'] as String? ?? 'bright',
    model: PoseDetectionModel.values.byName(json['model']! as String),
    roundLength: Duration(seconds: json['roundSeconds']! as int),
  );
}

/// Something the counter did to the judge between two frames.
enum FrameMark {
  /// The judge dropped the attempt in progress (camera switch, screen
  /// rotation, or pose detection failing).
  abandon,
}

/// One entry of a recording: a frame the judge saw, at the time the judge
/// read, with the phone sensors at that moment. Or a [mark].
class RecordedFrame {
  const RecordedFrame({
    required this.at,
    this.pose,
    this.phoneTilt,
    this.gyro,
    this.phoneMoved = false,
    this.fps,
    this.gravity,
    this.luma,
    this.mark,
  });

  final Duration at;

  /// Null only for a [mark].
  final PoseFrame? pose;

  /// Degrees from lying flat. Null until the sensor reported.
  final double? phoneTilt;

  /// Rad/s. Null until the gyro reported.
  final double? gyro;

  /// The phone had leaned or shaken, so a valid rep closing on this frame
  /// was turned into [RejectReason.phoneMoved].
  final bool phoneMoved;

  /// Frames the counter processed in the second before this one.
  final int? fps;

  /// The phone's raw gravity (x, y, z in m/s², Android axes), for the
  /// screen-plane roll that [phoneTilt] leaves out.
  final List<double>? gravity;

  /// Mean image brightness, 0 dark to 255 bright: see [meanLuma].
  final double? luma;
  final FrameMark? mark;
}

/// One frame the setup check saw before the round, with its verdict, so
/// setup thresholds can be set from the same data as the judge's.
class SetupFrame {
  const SetupFrame({
    required this.at,
    required this.pose,
    required this.reason,
    this.ready = false,
    this.progress = 0,
    this.missing = const [],
    this.phoneTilt,
    this.gyro,
    this.gravity,
    this.fps,
  });

  /// Time since setup opened.
  final Duration at;
  final PoseFrame pose;

  /// The check's result for this frame alone.
  final SetupReason reason;

  /// The stable Ready state, and the progress towards it, 0 to 1.
  final bool ready;
  final double progress;
  final List<BodyPart> missing;
  final double? phoneTilt;
  final double? gyro;
  final List<double>? gravity;
  final int? fps;
}

/// Collects the frames setup checked from the setup view model's states.
class SetupRecorder {
  final List<SetupFrame> _frames = [];
  PoseFrame? _last;

  List<SetupFrame> get frames => List.unmodifiable(_frames);

  /// Takes [state]'s frame when it is one setup has not checked before.
  void observe(
    SetupState state, {
    required Duration at,
    PhoneTiltMonitor? phoneTilt,
  }) {
    final pose = state.lastFrame;
    if (pose == null || identical(pose, _last)) return;
    _last = pose;
    final status = state.status;
    _frames.add(
      SetupFrame(
        at: at,
        pose: pose,
        reason: status.reason,
        ready: status.isReady,
        progress: status.readyProgress,
        missing: status.missingParts,
        phoneTilt: phoneTilt?.tiltDegrees,
        gyro: phoneTilt?.gyroSpeed,
        gravity: switch (phoneTilt?.lastSample) {
          final g? => [g.x, g.y, g.z],
          null => null,
        },
        fps: state.fps,
      ),
    );
  }
}

/// A recorded set, as saved to and read from one JSON file.
///
/// Landmark values are rounded (0.1 px, likelihood to 4 places) to keep
/// files small. A replay therefore can, very rarely, land on the other side
/// of a threshold than the live judge did.
class PushUpRecording {
  const PushUpRecording({
    required this.id,
    required this.recordedAt,
    required this.label,
    required this.setup,
    required this.frames,
    required this.liveEvents,
    this.setupFrames = const [],
    this.frontCamera = true,
    this.frameRotation = 0,
    this.judge = const {},
  });

  static const format = 'gymrats-pushup-case';
  static const version = 1;

  final String id;
  final DateTime recordedAt;
  final RecordingLabel label;
  final RecordingSetup setup;
  final bool frontCamera;

  /// Rotation, in degrees, that pose detection applied to the camera image.
  /// Landmarks are already in the upright image.
  final int frameRotation;
  final List<RecordedFrame> frames;

  /// What the judge decided while the set was filmed.
  final List<RepEvent> liveEvents;

  /// The setup check's frames before the round. Empty in recordings made
  /// before setup was recorded.
  final List<SetupFrame> setupFrames;

  /// The judge that made [liveEvents]: see [describeJudge].
  final Map<String, Object?> judge;

  String get fileName => '$id.json';

  /// Pretty metadata, then one frame per line.
  String encode() {
    const placeholder = '__frames__';
    const setupPlaceholder = '__setupFrames__';
    final head = const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'id': id,
      'recordedAt': recordedAt.toIso8601String(),
      'label': label.toJson(),
      'setup': setup.toJson(),
      'frontCamera': frontCamera,
      'frameRotation': frameRotation,
      'landmarks': [for (final l in BodyLandmark.values) l.name],
      'judge': judge,
      'live': [for (final e in liveEvents) _eventToJson(e)],
      'setupFrames': setupPlaceholder,
      'frames': placeholder,
    });
    String lines(Iterable<Map<String, Object?>> items) {
      final all = [for (final i in items) '    ${jsonEncode(i)}'];
      return all.isEmpty ? '[]' : '[\n${all.join(',\n')}\n  ]';
    }

    return head
        .replaceFirst(
          '"$setupPlaceholder"',
          lines(setupFrames.map(_setupFrameToJson)),
        )
        .replaceFirst('"$placeholder"', lines(frames.map(_frameToJson)));
  }

  /// Reads [encode]'s output. Throws [FormatException] for another format
  /// or version.
  static PushUpRecording decode(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, Object?> ||
        json['format'] != format ||
        json['version'] != version) {
      throw const FormatException('Not a version 1 push-up case');
    }
    final names = (json['landmarks']! as List).cast<String>();
    final landmarks = [for (final n in names) BodyLandmark.values.byName(n)];
    return PushUpRecording(
      id: json['id']! as String,
      recordedAt: DateTime.parse(json['recordedAt']! as String),
      label: RecordingLabel.fromJson(json['label']! as Map<String, Object?>),
      setup: RecordingSetup.fromJson(json['setup']! as Map<String, Object?>),
      frontCamera: json['frontCamera'] as bool? ?? true,
      frameRotation: json['frameRotation'] as int? ?? 0,
      judge: json['judge'] as Map<String, Object?>? ?? const {},
      liveEvents: [
        for (final e in json['live']! as List)
          _eventFromJson(e as Map<String, Object?>),
      ],
      setupFrames: [
        for (final f in json['setupFrames'] as List? ?? const [])
          _setupFrameFromJson(f as Map<String, Object?>, landmarks),
      ],
      frames: [
        for (final f in json['frames']! as List)
          _frameFromJson(f as Map<String, Object?>, landmarks),
      ],
    );
  }

  /// Image size and, per landmark in [BodyLandmark] order, x, y, z, and
  /// likelihood; four nulls for a landmark the frame does not have.
  static Map<String, Object?> _poseToJson(PoseFrame pose) => {
    'w': pose.imageWidth,
    'h': pose.imageHeight,
    'p': [
      for (final l in BodyLandmark.values)
        ...switch (pose[l]) {
          final k? => [
            _round(k.x, 1),
            _round(k.y, 1),
            _round(k.z, 1),
            _round(k.likelihood, 4),
          ],
          null => const [null, null, null, null],
        },
    ],
  };

  static PoseFrame _poseFromJson(
    Map<String, Object?> json,
    List<Object?> values,
    List<BodyLandmark> landmarks,
  ) {
    final keypoints = <BodyLandmark, Keypoint>{};
    for (var i = 0; i < landmarks.length; i++) {
      final x = values[i * 4] as num?;
      if (x == null) continue;
      keypoints[landmarks[i]] = Keypoint(
        landmark: landmarks[i],
        x: x.toDouble(),
        y: (values[i * 4 + 1] as num).toDouble(),
        z: (values[i * 4 + 2] as num).toDouble(),
        likelihood: (values[i * 4 + 3] as num).toDouble(),
      );
    }
    return PoseFrame(
      imageWidth: (json['w']! as num).toDouble(),
      imageHeight: (json['h']! as num).toDouble(),
      keypoints: keypoints,
    );
  }

  static List<double>? _gravityFromJson(Object? json) => switch (json) {
    final List g => [for (final v in g) (v as num).toDouble()],
    _ => null,
  };

  static Map<String, Object?> _setupFrameToJson(SetupFrame f) => {
    't': f.at.inMicroseconds,
    ..._poseToJson(f.pose),
    'reason': f.reason.name,
    if (f.ready) 'ready': true,
    'progress': _round(f.progress, 2),
    if (f.missing.isNotEmpty) 'missing': [for (final m in f.missing) m.name],
    if (f.phoneTilt != null) 'tilt': _round(f.phoneTilt!, 2),
    if (f.gyro != null) 'gyro': _round(f.gyro!, 3),
    if (f.gravity case final g?) 'g': [for (final v in g) _round(v, 3)],
    if (f.fps != null) 'fps': f.fps,
  };

  static SetupFrame _setupFrameFromJson(
    Map<String, Object?> json,
    List<BodyLandmark> landmarks,
  ) => SetupFrame(
    at: Duration(microseconds: json['t']! as int),
    pose: _poseFromJson(json, json['p']! as List, landmarks),
    reason: SetupReason.values.byName(json['reason']! as String),
    ready: json['ready'] as bool? ?? false,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    missing: [
      for (final m in json['missing'] as List? ?? const [])
        BodyPart.values.byName(m as String),
    ],
    phoneTilt: (json['tilt'] as num?)?.toDouble(),
    gyro: (json['gyro'] as num?)?.toDouble(),
    gravity: _gravityFromJson(json['g']),
    fps: json['fps'] as int?,
  );

  static Map<String, Object?> _frameToJson(RecordedFrame f) {
    final pose = f.pose;
    return {
      't': f.at.inMicroseconds,
      if (f.mark != null) 'mark': f.mark!.name,
      if (pose != null) ..._poseToJson(pose),
      if (f.phoneTilt != null) 'tilt': _round(f.phoneTilt!, 2),
      if (f.gyro != null) 'gyro': _round(f.gyro!, 3),
      if (f.phoneMoved) 'moved': true,
      if (f.fps != null) 'fps': f.fps,
      if (f.gravity case final g?) 'g': [for (final v in g) _round(v, 3)],
      if (f.luma != null) 'luma': _round(f.luma!, 1),
    };
  }

  static RecordedFrame _frameFromJson(
    Map<String, Object?> json,
    List<BodyLandmark> landmarks,
  ) {
    final at = Duration(microseconds: json['t']! as int);
    final mark = json['mark'];
    final pose = switch (json['p']) {
      final List values => _poseFromJson(json, values, landmarks),
      _ => null,
    };
    return RecordedFrame(
      at: at,
      pose: pose,
      phoneTilt: (json['tilt'] as num?)?.toDouble(),
      gyro: (json['gyro'] as num?)?.toDouble(),
      phoneMoved: json['moved'] as bool? ?? false,
      fps: json['fps'] as int?,
      gravity: _gravityFromJson(json['g']),
      luma: (json['luma'] as num?)?.toDouble(),
      mark: mark == null ? null : FrameMark.values.byName(mark as String),
    );
  }

  static Map<String, Object?> _eventToJson(RepEvent e) => {
    'index': e.index,
    'valid': e.valid,
    'reason': e.reason?.name,
    't': e.at.inMicroseconds,
    'maxDepth': e.maxDepth,
    'minElbowAngle': e.minElbowAngle,
    'maxTilt': e.maxTilt,
    'descent': e.descent?.inMicroseconds,
  };

  static RepEvent _eventFromJson(Map<String, Object?> json) => RepEvent(
    index: json['index']! as int,
    valid: json['valid']! as bool,
    reason: switch (json['reason']) {
      final String name => RejectReason.values.byName(name),
      _ => null,
    },
    at: Duration(microseconds: json['t']! as int),
    maxDepth: (json['maxDepth'] as num?)?.toDouble(),
    minElbowAngle: (json['minElbowAngle'] as num?)?.toDouble(),
    maxTilt: (json['maxTilt'] as num?)?.toDouble(),
    descent: switch (json['descent']) {
      final int us => Duration(microseconds: us),
      _ => null,
    },
  );

  static double _round(double value, int digits) =>
      double.parse(value.toStringAsFixed(digits));
}

/// Collects the frames the judge sees from the counter's state changes.
class PushUpRecorder {
  final List<RecordedFrame> _frames = [];
  PoseFrame? _last;
  bool _lostMarked = false;

  List<RecordedFrame> get frames => List.unmodifiable(_frames);

  bool get isEmpty => !_frames.any((f) => f.pose != null);

  /// Takes [state]'s pose when it is a frame the judge has not had yet.
  /// [judgedAt] is the time the judge read for it.
  ///
  /// The counter reports failing pose detection with this exact snapshot
  /// after abandoning the attempt, so it becomes an [FrameMark.abandon].
  void observe(
    RepCounterState state, {
    required Duration judgedAt,
    PhoneTiltMonitor? phoneTilt,
    double? luma,
  }) {
    final pose = state.lastFrame;
    if (pose != null && !identical(pose, _last)) {
      _last = pose;
      _lostMarked = false;
      _frames.add(
        RecordedFrame(
          at: judgedAt,
          pose: pose,
          phoneTilt: phoneTilt?.tiltDegrees,
          gyro: phoneTilt?.gyroSpeed,
          phoneMoved: phoneTilt?.isDisturbed ?? false,
          fps: state.fps,
          gravity: switch (phoneTilt?.lastSample) {
            final g? => [g.x, g.y, g.z],
            null => null,
          },
          luma: luma,
        ),
      );
    } else if (identical(state.snapshot, _detectorLost) && !_lostMarked) {
      _lostMarked = true;
      markAbandon(judgedAt);
    }
  }

  static const _detectorLost = JudgeSnapshot(phase: RepPhase.lost);

  /// The counter is about to abandon the judge's attempt.
  void markAbandon(Duration at) =>
      _frames.add(RecordedFrame(at: at, mark: FrameMark.abandon));

  /// Forgets everything so far, for a reset judge. The frame on screen is
  /// not taken again.
  void restart() {
    _frames.clear();
    _lostMarked = false;
  }

  PushUpRecording build({
    required String id,
    required DateTime recordedAt,
    required RecordingLabel label,
    required RecordingSetup setup,
    required List<RepEvent> liveEvents,
    List<SetupFrame> setupFrames = const [],
    bool frontCamera = true,
    int frameRotation = 0,
    Map<String, Object?> judge = const {},
  }) => PushUpRecording(
    id: id,
    recordedAt: recordedAt,
    label: label,
    setup: setup,
    setupFrames: setupFrames,
    frontCamera: frontCamera,
    frameRotation: frameRotation,
    frames: frames,
    liveEvents: liveEvents,
    judge: judge,
  );
}

/// The build's commit, from
/// `flutter run --dart-define=GIT_COMMIT=$(git rev-parse --short HEAD) ...`.
const _gitCommit = String.fromEnvironment('GIT_COMMIT');

/// The commit and thresholds of the judge that made a recording's live
/// verdicts, so a later replay difference can be traced to a judge change.
/// Lists every [RepJudgeConfig] field by hand: a new field goes here too.
Map<String, Object?> describeJudge(RepJudgeConfig c) => {
  'commit': _gitCommit.isEmpty ? null : _gitCommit,
  'config': {
    'minLikelihood': c.minLikelihood,
    'topAngle': c.topAngle,
    'topHoldMs': c.topHold.inMilliseconds,
    'enterDepth': c.enterDepth,
    'topDepth': c.topDepth,
    'shallowDepth': c.shallowDepth,
    'bottomDepth': c.bottomDepth,
    'partialDepth': c.partialDepth,
    'reDescentDepth': c.reDescentDepth,
    'noiseFloorMs': c.noiseFloor.inMilliseconds,
    'maxShoulderTilt': c.maxShoulderTilt,
    'maxFrameGapMs': c.maxFrameGap.inMilliseconds,
    'maxAttemptMs': c.maxAttempt.inMilliseconds,
    'smoothingTauMs': c.smoothingTau.inMilliseconds,
    'baselineTauMs': c.baselineTau.inMilliseconds,
    'minCheatFrames': c.minCheatFrames,
    'maxTorsoDrop': c.maxTorsoDrop,
    'kneeBentAngle': c.kneeBentAngle,
    'adoptHipAngle': c.adoptHipAngle,
    'defaultKneeHip': c.defaultKneeHip,
    'hipFoldWide': c.hipFoldWide,
    'baselineFrames': c.baselineFrames,
    'hipFoldFromSetup': c.hipFoldFromSetup,
    'straightArmAngle': c.straightArmAngle,
    'minKneeHandGap': c.minKneeHandGap,
    'maxKneeHandGap': c.maxKneeHandGap,
    'maxHipHandGap': c.maxHipHandGap,
    'minHipOnFloorGap': c.minHipOnFloorGap,
    'minBellyTorsoDrop': c.minBellyTorsoDrop,
    'minShoulderDrop': c.minShoulderDrop,
    'bowHipHandGap': c.bowHipHandGap,
    'bowTorsoDrop': c.bowTorsoDrop,
    'maxShinLiftGap': c.maxShinLiftGap,
  },
};

/// `<yyyyMMdd-HHmmss>_<device>_<kind>`, safe as a file name.
String recordingId(DateTime at, String device, CaseKind kind) {
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}';
  final safeDevice = device.trim().replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '-');
  return [stamp, if (safeDevice.isNotEmpty) safeDevice, kind.name].join('_');
}

/// Writes a recording into the app's own files folder and returns its path.
/// Copied off the phone with `adb shell run-as` (debug builds only).
Future<String> saveToAppFiles(String fileName, String contents) async {
  final dir = Directory('${_appFilesDir()}/pushup_cases');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(contents, flush: true);
  return file.path;
}

String _appFilesDir() {
  if (Platform.isAndroid) {
    // The main process is named after the package.
    final name = File('/proc/self/cmdline').readAsStringSync().split('\x00');
    if (name.first.isNotEmpty) return '/data/data/${name.first}/files';
  }
  return Directory.systemTemp.path;
}

/// Mean of the luma (Y) bytes of [image], 0 dark to 255 bright, from every
/// [step]th pixel of each row. NV21 and the YUV formats start with the full
/// Y plane; padding at the end of a row is skipped. Null for an image
/// without pixels.
double? meanLuma(CameraImage image, {int step = 16}) {
  if (image.planes.isEmpty) return null;
  final plane = image.planes.first;
  final bytes = plane.bytes;
  final rowStride = plane.bytesPerRow > 0 ? plane.bytesPerRow : image.width;
  var sum = 0, n = 0;
  for (var y = 0; y < image.height; y++) {
    final row = y * rowStride;
    for (var x = 0; x < image.width && row + x < bytes.length; x += step) {
      sum += bytes[row + x];
      n++;
    }
  }
  return n == 0 ? null : sum / n;
}

/// The brightness of the latest camera frame. Only the number is kept.
class LumaMeter {
  double? latest;

  void measure(CameraImage image) => latest = meanLuma(image) ?? latest;
}

/// A camera that measures each frame's brightness on its way to the
/// counter.
class MeteredCamera implements CameraService {
  MeteredCamera(this._camera, this._meter);

  final CameraService _camera;
  final LumaMeter _meter;

  @override
  CameraLensDirection get preferredLens => _camera.preferredLens;

  @override
  CameraController? get controller => _camera.controller;

  @override
  bool get isFrontCamera => _camera.isFrontCamera;

  @override
  bool get canSwitchCamera => _camera.canSwitchCamera;

  @override
  int get rotationDegrees => _camera.rotationDegrees;

  @override
  Future<CameraPermission> requestPermission() => _camera.requestPermission();

  @override
  Future<bool> openSettings() => _camera.openSettings();

  @override
  Future<void> start(void Function(CameraImage image) onImage) =>
      _camera.start((image) {
        _meter.measure(image);
        onImage(image);
      });

  @override
  void selectNextCamera() => _camera.selectNextCamera();

  @override
  Future<void> stop() => _camera.stop();
}

/// What the demo hands to [RepJudgeDemoApp.createCounter].
class CounterArgs {
  const CounterArgs({
    required this.judge,
    required this.phoneTilt,
    required this.clock,
    required this.setup,
    required this.meter,
  });

  /// Judge whose clock reads are the frame times in the recording.
  final RepJudge judge;
  final PhoneTiltMonitor phoneTilt;
  final RepClock clock;
  final RecordingSetup setup;

  /// Wrap the counter's camera in a [MeteredCamera] with this meter for
  /// the brightness to be recorded.
  final LumaMeter meter;
}

typedef SaveRecording = Future<String> Function(
  String fileName,
  String contents,
);

class RepJudgeDemoApp extends StatelessWidget {
  const RepJudgeDemoApp({
    super.key,
    this.createSetup,
    this.createCounter,
    this.phoneTilt,
    this.clock,
    this.judgeConfig = const RepJudgeConfig(),
    this.save = saveToAppFiles,
    this.now = DateTime.now,
  });

  /// Builds the setup view model; replaces the default one in tests.
  final SetupViewModel Function(ExerciseType exercise)? createSetup;

  /// Builds the rep counter; replaces the default one in tests.
  final RepCounterViewModel Function(CounterArgs args)? createCounter;

  /// Defaults to the platform monitor, the one setup uses.
  final PhoneTiltMonitor? phoneTilt;
  final RepClock? clock;
  final RepJudgeConfig judgeConfig;
  final SaveRecording save;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Push-up rep judge',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _RecorderForm(app: this),
    );
  }
}

/// Label and setup of the next set. The values stay for the next set.
class _RecorderForm extends StatefulWidget {
  const _RecorderForm({required this.app});

  final RepJudgeDemoApp app;

  @override
  State<_RecorderForm> createState() => _RecorderFormState();
}

class _RecorderFormState extends State<_RecorderForm> {
  CaseKind _kind = CaseKind.normal;
  RecordingSetup _setup = const RecordingSetup();
  bool _record = true;
  final _reps = TextEditingController(text: '10');
  final _person = TextEditingController();
  final _height = TextEditingController();
  final _arm = TextEditingController();
  final _shoulder = TextEditingController();
  final _device = TextEditingController();
  final _placement = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _reps,
      _person,
      _height,
      _arm,
      _shoulder,
      _device,
      _placement,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    final app = widget.app;
    final label = RecordingLabel.of(
      _kind,
      int.tryParse(_reps.text.trim()) ?? 0,
      note: _note.text.trim(),
    );
    final height = int.tryParse(_height.text.trim());
    final arm = int.tryParse(_arm.text.trim());
    final shoulder = int.tryParse(_shoulder.text.trim());
    final setup = _setup.copyWith(
      person: _person.text.trim(),
      heightCm: height,
      clearHeight: height == null,
      armCm: arm,
      clearArm: arm == null,
      shoulderCm: shoulder,
      clearShoulder: shoulder == null,
      device: _device.text.trim(),
      placement: _placement.text.trim(),
    );
    const exercise = ExerciseType.pushUp;
    final setupRecorder = SetupRecorder();
    final phoneTilt = app.phoneTilt ?? PhoneTiltMonitor.platform();
    final stopwatch = Stopwatch()..start();
    final clock = app.clock ?? () => stopwatch.elapsed;
    final setupStart = clock();
    SetupViewModel createSetup() {
      final viewModel =
          app.createSetup?.call(exercise) ??
          SetupViewModel(
            exercise: exercise,
            estimator: PoseEstimator(
              detector: PoseDetector(
                options: PoseDetectorOptions(
                  mode: PoseDetectionMode.stream,
                  model: setup.model,
                ),
              ),
            ),
            phoneTilt: phoneTilt,
          );
      viewModel.addListener(
        () => setupRecorder.observe(
          viewModel.state,
          at: clock() - setupStart,
          phoneTilt: phoneTilt,
        ),
      );
      return viewModel;
    }

    final result = await Navigator.push<ExerciseType>(
      context,
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          exercise: exercise,
          showDebugTools: true,
          // The phone stays where setup placed it.
          exitOrientations: SetupScreen.orientations,
          createViewModel: createSetup,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _CounterPage(
          app: app,
          label: label,
          setup: setup,
          record: _record,
          setupFrames: setupRecorder.frames,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget field(
      Key key,
      TextEditingController controller,
      String label, {
      bool number = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Push-up recorder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('This set shows', style: TextStyle(fontSize: 16)),
            DropdownButton<CaseKind>(
              key: caseKindKey,
              isExpanded: true,
              value: _kind,
              items: [
                for (final kind in CaseKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: (kind) => setState(() => _kind = kind ?? _kind),
            ),
            const SizedBox(height: 12),
            field(repsFieldKey, _reps, 'Reps you will do', number: true),
            field(personFieldKey, _person, 'Person (initials)'),
            field(heightFieldKey, _height, 'Height (cm)', number: true),
            field(armFieldKey, _arm, 'Arm length (cm, optional)', number: true),
            field(
              shoulderFieldKey,
              _shoulder,
              'Shoulder width (cm, optional)',
              number: true,
            ),
            field(deviceFieldKey, _device, 'Device (e.g. S22)'),
            field(placementFieldKey, _placement, 'Phone placement'),
            field(noteFieldKey, _note, 'Note'),
            const Text('Lighting'),
            SegmentedButton<String>(
              segments: [
                for (final l in RecordingSetup.lightings)
                  ButtonSegment(value: l, label: Text(l)),
              ],
              selected: {_setup.lighting},
              onSelectionChanged: (v) =>
                  setState(() => _setup = _setup.copyWith(lighting: v.first)),
            ),
            const SizedBox(height: 12),
            const Text('ML Kit model'),
            SegmentedButton<PoseDetectionModel>(
              segments: [
                for (final m in PoseDetectionModel.values)
                  ButtonSegment(value: m, label: Text(m.name)),
              ],
              selected: {_setup.model},
              onSelectionChanged: (v) =>
                  setState(() => _setup = _setup.copyWith(model: v.first)),
            ),
            const SizedBox(height: 12),
            const Text('Round'),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('30 s')),
                ButtonSegment(value: 60, label: Text('60 s')),
              ],
              selected: {_setup.roundLength.inSeconds},
              onSelectionChanged: (v) => setState(
                () => _setup = _setup.copyWith(
                  roundLength: Duration(seconds: v.first),
                ),
              ),
            ),
            SwitchListTile(
              key: recordSwitchKey,
              contentPadding: EdgeInsets.zero,
              title: const Text('Save the recording'),
              value: _record,
              onChanged: (v) => setState(() => _record = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: startRecordingKey,
              onPressed: _start,
              child: const Text('Start set'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads the base clock and keeps the value, so the recorder stamps each
/// frame with the exact time the judge used.
class _TappedClock {
  _TappedClock(this._base);

  final RepClock _base;
  Duration last = Duration.zero;

  Duration call() => last = _base();
}

class _CounterPage extends StatefulWidget {
  const _CounterPage({
    required this.app,
    required this.label,
    required this.setup,
    required this.record,
    this.setupFrames = const [],
  });

  final RepJudgeDemoApp app;
  final RecordingLabel label;
  final RecordingSetup setup;
  final bool record;

  /// What setup checked before this round; saved with the recording.
  final List<SetupFrame> setupFrames;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage>
    with WidgetsBindingObserver {
  late final RepCounterViewModel _viewModel;
  late final RepClock _clock;
  late final _TappedClock _judgeClock;
  late final PhoneTiltMonitor _phoneTilt;
  final _meter = LumaMeter();
  PushUpRecorder? _recorder;
  bool _saveStarted = false;
  String? _saveStatus;
  Timer? _flashTimer;
  String? _flash;
  bool _flashValid = false;
  final Stopwatch _sinceLog = Stopwatch();
  String? _lastLogKey;
  Orientation? _orientation;

  @override
  void initState() {
    super.initState();
    final app = widget.app;
    _clock = app.clock ?? _stopwatchClock();
    _judgeClock = _TappedClock(_clock);
    _phoneTilt = app.phoneTilt ?? PhoneTiltMonitor.platform();
    final args = CounterArgs(
      judge: RepJudge(config: app.judgeConfig, clock: _judgeClock.call),
      phoneTilt: _phoneTilt,
      clock: _clock,
      setup: widget.setup,
      meter: _meter,
    );
    _viewModel = app.createCounter?.call(args) ?? _defaultCounter(args);
    if (widget.record) _recorder = PushUpRecorder();
    WidgetsBinding.instance.addObserver(this);
    _viewModel.addListener(_onViewModel);
    SystemChrome.setPreferredOrientations(SetupScreen.orientations);
    _viewModel.start();
  }

  static RepClock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  static RepCounterViewModel _defaultCounter(CounterArgs args) =>
      RepCounterViewModel(
        camera: MeteredCamera(CameraService(), args.meter),
        estimator: PoseEstimator(
          detector: PoseDetector(
            options: PoseDetectorOptions(
              mode: PoseDetectionMode.stream,
              model: args.setup.model,
            ),
          ),
        ),
        judge: args.judge,
        phoneTilt: args.phoneTilt,
        clock: args.clock,
        roundLength: args.setup.roundLength,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (_orientation != null && _orientation != orientation) {
      _recorder?.markAbandon(_clock());
      _viewModel.onScreenRotated();
    }
    _orientation = orientation;
  }

  void _switchCamera() {
    _recorder?.markAbandon(_clock());
    _viewModel.switchCamera();
  }

  void _reset() {
    _viewModel.reset();
    _recorder?.restart();
  }

  /// Retry starts a new round, so the recording starts over too.
  void _retry() {
    _recorder?.restart();
    _viewModel.retry();
  }

  void _onViewModel() {
    _recorder?.observe(
      _viewModel.state,
      judgedAt: _judgeClock.last,
      phoneTilt: _phoneTilt,
      luma: _meter.latest,
    );
    final phase = _viewModel.state.phase;
    if (phase != _loggedPhase) {
      _loggedPhase = phase;
      final value = _viewModel.cameraController?.value;
      debugPrint(
        'rep_judge camera | phase=${phase.name} '
        'device=${value?.deviceOrientation.name} '
        'frameRotation=${_viewModel.frameRotation} '
        'error=${_viewModel.state.errorMessage ?? '-'}',
      );
    }
    if (phase == CounterPhase.finished && !_saveStarted) {
      _saveStarted = true;
      unawaited(_save());
    }
    final event = _viewModel.state.lastEvent;
    if (event == null || event.at == _shownAt) {
      _log(false);
      return;
    }
    _shownAt = event.at;
    _log(true);
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() {
      _flash = event.valid ? '+1' : event.reason!.message;
      _flashValid = event.valid;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _save() async {
    final recorder = _recorder;
    if (recorder == null) return;
    String status;
    if (recorder.isEmpty) {
      status = 'Nothing recorded';
    } else {
      final recordedAt = widget.app.now();
      final recording = recorder.build(
        id: recordingId(recordedAt, widget.setup.device, widget.label.kind),
        recordedAt: recordedAt,
        label: widget.label,
        setup: widget.setup,
        liveEvents: _viewModel.history,
        setupFrames: widget.setupFrames,
        frontCamera: _viewModel.isFrontCamera,
        frameRotation: _viewModel.frameRotation,
        judge: describeJudge(widget.app.judgeConfig),
      );
      try {
        final path = await widget.app.save(
          recording.fileName,
          recording.encode(),
        );
        status = 'Saved $path';
      } catch (e) {
        status = 'Not saved: $e';
      }
    }
    debugPrint('rep_judge recording | $status');
    if (mounted) setState(() => _saveStatus = status);
  }

  Duration? _shownAt;
  CounterPhase? _loggedPhase;

  /// Logs the live judge values when they change, at most every 250 ms.
  void _log(bool freshRep) {
    final state = _viewModel.state;
    if (state.phase != CounterPhase.running) return;
    final snap = state.snapshot;
    final key = '${snap.phase.name} ${state.validReps} ${state.invalidReps}';
    final elapsed = _sinceLog.elapsedMilliseconds;
    final due =
        !_sinceLog.isRunning ||
        elapsed >= 1000 ||
        (key != _lastLogKey && elapsed >= 250);
    if (due) {
      _lastLogKey = key;
      _sinceLog
        ..reset()
        ..start();
      debugPrint(
        'rep_judge | phase=${snap.phase.name} '
        'depth=${_n(snap.depth, 2)} elbow=${_n(snap.elbowAngle)} '
        'tilt=${_n(snap.tilt)} fps=${state.fps} '
        'valid=${state.validReps} invalid=${state.invalidReps}',
      );
    }
    final event = state.lastEvent;
    if (freshRep && event != null) {
      debugPrint(
        'rep_judge rep | #${event.index} '
        'valid=${event.valid} reason=${event.reason?.name ?? '-'} '
        'maxDepth=${_n(event.maxDepth, 2)} '
        'minElbow=${_n(event.minElbowAngle)} maxTilt=${_n(event.maxTilt)}',
      );
    }
  }

  static String _n(double? value, [int digits = 1]) =>
      value?.toStringAsFixed(digits) ?? '-';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _viewModel.pause();
      case AppLifecycleState.resumed:
        _viewModel.resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModel);
    _viewModel.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        final running = state.phase == CounterPhase.running;
        final finished = state.phase == CounterPhase.finished;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (finished)
                _RoundResult(
                  state: state,
                  history: _viewModel.history,
                  expected: widget.label.expected,
                  saveStatus: _saveStatus,
                )
              else if (running)
                PoseAvatarToggleView(
                  controller: _viewModel.cameraController,
                  frame: state.lastFrame,
                  mirror: _viewModel.isFrontCamera,
                  showLandmarks: true,
                  isVisible: (keypoint, _) => _viewModel.isVisible(keypoint),
                )
              else
                _CounterMessage(viewModel: _viewModel, onRetry: _retry),
              SafeArea(
                child: Column(
                  children: [
                    _CounterTopBar(
                      title: widget.label.kind.label,
                      onBack: () => Navigator.maybePop(context),
                      onReset: running ? _reset : null,
                      onStop: running
                          ? () => _viewModel.finish(stoppedByUser: true)
                          : null,
                      onSwitch: running && _viewModel.canSwitchCamera
                          ? _switchCamera
                          : null,
                    ),
                    if (!finished) _Scoreboard(state: state),
                    const Spacer(),
                    if (_flash != null && !finished)
                      _Flash(text: _flash!, valid: _flashValid),
                    if (running) _DebugPanel(state: state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.state});

  final RepCounterState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${state.validReps}',
            key: validRepsKey,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 64,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _formatRoundTime(state.remaining),
            key: remainingTimeKey,
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
          Text(
            'Invalid ${state.invalidReps}',
            key: invalidRepsKey,
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _Flash extends StatelessWidget {
  const _Flash({required this.text, required this.valid});

  final String text;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        key: repFlashKey,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: valid ? Colors.greenAccent : Colors.redAccent,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.state});

  final RepCounterState state;

  @override
  Widget build(BuildContext context) {
    final snap = state.snapshot;
    String n(double? value) => value?.toStringAsFixed(0) ?? '-';
    return Container(
      width: double.infinity,
      color: Colors.black54,
      padding: const EdgeInsets.all(12),
      child: Text(
        '${_phaseLabel(snap.phase)}  '
        'depth ${snap.depth?.toStringAsFixed(2) ?? '-'}  '
        'elbow ${n(snap.elbowAngle)}°  '
        'tilt ${n(snap.tilt)}°  '
        '${state.fps} fps',
        key: repPhaseKey,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class _CounterTopBar extends StatelessWidget {
  const _CounterTopBar({
    required this.title,
    required this.onBack,
    required this.onReset,
    required this.onStop,
    required this.onSwitch,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onReset;
  final VoidCallback? onStop;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final style = IconButton.styleFrom(backgroundColor: Colors.black45);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back',
            style: style,
            onPressed: onBack,
          ),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          TextButton(onPressed: onReset, child: const Text('Reset')),
          if (onStop != null)
            TextButton(
              key: stopRoundKey,
              onPressed: onStop,
              child: const Text('Stop'),
            ),
          if (onSwitch != null)
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              tooltip: 'Switch camera',
              style: style,
              onPressed: onSwitch,
            ),
        ],
      ),
    );
  }
}

class _CounterMessage extends StatelessWidget {
  const _CounterMessage({required this.viewModel, required this.onRetry});

  final RepCounterViewModel viewModel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final (title, body, actions) = switch (state.phase) {
      CounterPhase.permissionDenied => (
        'Camera access needed',
        state.permanentlyDenied
            ? 'Camera access is turned off. Allow it in Settings.'
            : 'GymRats uses the camera to count push-ups. '
                  'The video never leaves your phone.',
        [
          FilledButton(
            onPressed: viewModel.openSettings,
            child: const Text('Open settings'),
          ),
          if (!state.permanentlyDenied)
            TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
      CounterPhase.cameraError => (
        'Could not start the camera.',
        state.errorMessage ?? '',
        [FilledButton(onPressed: onRetry, child: const Text('Retry'))],
      ),
      CounterPhase.detectorError => (
        'Pose detection stopped working.',
        state.errorMessage ?? '',
        [FilledButton(onPressed: onRetry, child: const Text('Retry'))],
      ),
      CounterPhase.starting ||
      CounterPhase.paused ||
      CounterPhase.running ||
      CounterPhase.finished => (null, null, const <Widget>[]),
    };
    if (title == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _RoundResult extends StatelessWidget {
  const _RoundResult({
    required this.state,
    required this.history,
    this.expected,
    this.saveStatus,
  });

  final RepCounterState state;
  final List<RepEvent> history;
  final CaseExpectation? expected;
  final String? saveStatus;

  @override
  Widget build(BuildContext context) {
    final reasons = <RejectReason, int>{};
    for (final event in history) {
      final reason = event.reason;
      if (event.valid || reason == null) continue;
      reasons[reason] = (reasons[reason] ?? 0) + 1;
    }
    final title = state.roundEnd == RoundEnd.stopped ? 'Stopped' : "Time's up";
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
          key: roundResultKey,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.validReps}',
              key: validRepsKey,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'valid',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Text(
              'Invalid ${state.invalidReps}',
              key: invalidRepsKey,
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 12),
            if (reasons.isEmpty)
              const Text(
                'No rejected reps',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              )
            else
              for (final reason in RejectReason.values)
                if (reasons[reason] case final count?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${reason.message} × $count',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 18,
                      ),
                    ),
                  ),
            if (expected case final expected?) ...[
              const SizedBox(height: 24),
              Text(
                'Expected: $expected',
                key: expectedResultKey,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
            if (saveStatus case final status?) ...[
              const SizedBox(height: 12),
              Text(
                status,
                key: saveStatusKey,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatRoundTime(Duration duration) {
  final seconds = duration.inSeconds;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '${seconds ~/ 60}:$rest';
}

String _phaseLabel(RepPhase phase) => switch (phase) {
  RepPhase.idle => 'IDLE',
  RepPhase.up => 'UP',
  RepPhase.descending || RepPhase.bottom => 'DOWN',
  RepPhase.lost => 'LOST',
};
