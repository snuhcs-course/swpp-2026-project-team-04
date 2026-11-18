import 'dart:convert';
import 'dart:io';

import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/squat_rep_judge.dart';

const iter4CaseRoot = 'test/ai_eval/cases_iter4';

class Iter4Case {
  Iter4Case._(this.data, this.file);

  factory Iter4Case.fromJson(Map<String, dynamic> data, {String file = ''}) {
    void require(bool valid, String message) {
      if (!valid) throw FormatException('$file: $message');
    }

    require(
      data['format'] == 'gymrats-iter4-ai-eval' && data['version'] == 1,
      'unsupported coordinate format',
    );
    require(
      data['id'] is String && (data['id'] as String).isNotEmpty,
      'missing case id',
    );
    require(data['participant'] is String, 'missing participant');
    require(['pushUp', 'squat'].contains(data['exercise']), 'unknown exercise');
    final source = data['source'] as Map<String, dynamic>;
    require(
      source['width'] is num &&
          (source['width'] as num).isFinite &&
          (source['width'] as num) > 0 &&
          source['height'] is num &&
          (source['height'] as num).isFinite &&
          (source['height'] as num) > 0,
      'invalid image dimensions',
    );
    require(
      source['sha256'] is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(source['sha256'] as String),
      'missing original-video hash',
    );
    final landmarks = data['landmarks'] as List;
    require(
      landmarks.length == BodyLandmark.values.length &&
          List.generate(
            landmarks.length,
            (i) => landmarks[i] == BodyLandmark.values[i].name,
          ).every((v) => v),
      'landmark order mismatch',
    );
    final frames = data['frames'] as List;
    require(
      frames.isNotEmpty && frames.length == source['frameCount'],
      'frame count mismatch',
    );
    var previous = -1;
    for (final raw in frames) {
      final f = raw as Map<String, dynamic>;
      require(
        f['t'] is int && (f['t'] as int) >= 0 && (f['t'] as int) > previous,
        'timestamps must increase',
      );
      previous = f['t'] as int;
      final p = f['p'] as List?;
      require(p == null || p.length == 132, 'expected33x4 coordinates');
      if (p != null) {
        for (var i = 0; i < 132; i += 4) {
          final joint = p.sublist(i, i + 4);
          require(
            joint.every((v) => v == null) ||
                joint.every((v) => v is num && v.isFinite),
            'invalid joint',
          );
        }
      }
    }
    final window = data['evaluationWindowUs'] as List?;
    require(
      window == null ||
          window.length == 2 &&
              window.every((v) => v is int) &&
              (window[0] as int) >= 0 &&
              (window[0] as int) < (window[1] as int) &&
              (window[1] as int) <= previous,
      'invalid evaluation window',
    );
    final label = data['label'] as Map<String, dynamic>;
    require(
      ['pending', 'confirmed'].contains(label['status']),
      'unknown label status',
    );
    if (label['status'] == 'confirmed') {
      final count = label['actualReps'];
      final perRep = label['perRep'];
      require(
        count is int && count >= 0 && perRep is List && perRep.length == count,
        'confirmed labels need actualReps and one label per repetition',
      );
      require(
        label['confirmedBy'] is String &&
            (label['confirmedBy'] as String).trim().isNotEmpty,
        'missing label confirmer',
      );
      final allowed = <String>{
        'valid',
        ...RejectReason.forExercise(
          data['exercise'] == 'pushUp'
              ? ExerciseType.pushUp
              : ExerciseType.squat,
        ).map((r) => r.name),
      };
      require(
        (perRep as List).every((v) => v is String && allowed.contains(v)),
        'unknown per-rep label for exercise',
      );
      if (data['scenario'] == 'chair') {
        require(
          data['chairPolicy'] == 'range_only',
          'chair squats use the agreed depth/full-standing criterion',
        );
      }
    }
    return Iter4Case._(data, file);
  }

  final Map<String, dynamic> data;
  final String file;
  String get id => data['id'] as String;
  String get participant => data['participant'] as String;
  String get exercise => data['exercise'] as String;
  String get scenario => data['scenario'] as String;
  bool get labelled => data['label']['status'] == 'confirmed';
  List<String>? get expected =>
      labelled ? (data['label']['perRep'] as List).cast<String>() : null;

  Iterable<({Duration at, PoseFrame pose})> get frames sync* {
    final source = data['source'];
    for (final raw in data['frames'] as List) {
      final p = raw['p'] as List?;
      yield (
        at: Duration(microseconds: raw['t'] as int),
        pose: PoseFrame(
          imageWidth: (source['width'] as num).toDouble(),
          imageHeight: (source['height'] as num).toDouble(),
          keypoints: {
            if (p != null)
              for (var i = 0; i < 33; i++)
                if (p[i * 4] != null)
                  BodyLandmark.values[i]: Keypoint(
                    landmark: BodyLandmark.values[i],
                    x: (p[i * 4] as num).toDouble(),
                    y: (p[i * 4 + 1] as num).toDouble(),
                    z: (p[i * 4 + 2] as num).toDouble(),
                    likelihood: (p[i * 4 + 3] as num).toDouble(),
                  ),
          },
        ),
      );
    }
  }

  bool includes(Duration at) {
    final window = data['evaluationWindowUs'] as List?;
    return window == null ||
        at.inMicroseconds >= (window[0] as int) &&
            at.inMicroseconds <= (window[1] as int);
  }
}

List<Iter4Case> loadIter4Cases([String root = iter4CaseRoot]) {
  final files =
      Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.json') &&
                f.uri.pathSegments.last != 'manifest.json',
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final cases = [
    for (final file in files)
      Iter4Case.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        file: file.path,
      ),
  ];
  if (cases.map((c) => c.id).toSet().length != cases.length) {
    throw const FormatException('duplicate Iteration4 case id');
  }
  return cases;
}

List<RepEvent> replayIter4(Iter4Case c, {bool? frameKnee}) {
  var now = Duration.zero;
  final pushup = frameKnee == null
      ? RepJudge(clock: () => now)
      : RepJudge(clock: () => now, useFrameKnee: frameKnee);
  final squat = SquatRepJudge(clock: () => now);
  final events = <RepEvent>[];
  for (final f in c.frames) {
    now = f.at;
    // No recorded IMU: direct update is the actual no-gravity judge path.
    final result = c.exercise == 'pushUp'
        ? pushup.update(f.pose)
        : squat.update(f.pose);
    if (result.event != null) events.add(result.event!);
  }
  return events;
}
