// Use python tools/diagnose/run_pushup_nine.py from the repository root.
// This same reader and scorer drives both frozen candidates and shipping code.
import 'dart:convert';
import 'dart:io';

import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../gymrats_app/test/ai_eval/eval_scorer.dart' show align;

import 'pushup_nine_presets.dart';

enum FeatureMode { none, summary, attempt }

class StreamReplay {
  StreamReplay(Map<String, RepJudgeConfig> configs, this.featureMode) {
    for (final e in configs.entries) {
      judges[e.key] = newReplayJudge(
        e.value,
        () => now,
        featureMode == FeatureMode.attempt
            ? (values) => features[e.key]!.add(List<double?>.of(values))
            : null,
      );
      events[e.key] = [];
      if (featureMode != FeatureMode.none) features[e.key] = [];
    }
  }
  Duration now = Duration.zero;
  final FeatureMode featureMode;
  final judges = <String, RepJudge>{};
  final events = <String, List<List<Object>>>{};
  final features = <String, List<List<double?>>>{};

  void add(int frameIndex, Duration at, PoseFrame pose, {bool moved = false}) {
    now = at;
    for (final e in judges.entries) {
      final event = e.value.update(pose).event;
      if (featureMode == FeatureMode.attempt &&
          features[e.key]!.length !=
              events[e.key]!.length + (event == null ? 0 : 1)) {
        throw StateError(
          'Unpaired attempt evidence on frame $frameIndex, preset ${e.key}',
        );
      }
      if (event == null) continue;
      // Same valid-event override as rejectIfPhoneMoved; video-only sources
      // have no device IMU. Real ML Kit recordings contain the moved flag.
      final label = event.valid
          ? (moved ? 'phoneMoved' : 'normal')
          : event.reason!.name;
      events[e.key]!.add([frameIndex, label]);
      if (featureMode == FeatureMode.summary)
        features[e.key]!.add([
          event.maxDepth,
          event.minElbowAngle,
          event.maxTilt,
        ]);
    }
  }

  void abandon() {
    for (final judge in judges.values) {
      judge.abandon();
    }
  }
}

Map<String, Object?> videoEvents(
  Map<String, dynamic> source,
  Map<String, RepJudgeConfig> configs,
  FeatureMode featureMode,
) {
  final replay = StreamReplay(configs, featureMode);
  final width = (source['width'] as num).toDouble();
  final height = (source['height'] as num).toDouble();
  if (width <= 0 || height <= 0) {
    throw const FormatException('Invalid image dimensions');
  }
  var lastFrame = -1, lastTime = -1;
  // Units, splits and labels are deliberately never read by this function.
  for (final frame in source['frames'] as List) {
    final index = frame[0] as int, time = frame[1] as int;
    if (index <= lastFrame || time <= lastTime) {
      throw FormatException(
        'Non-increasing frame/time at frame $index, $time ms',
      );
    }
    lastFrame = index;
    lastTime = time;
    final points = <BodyLandmark, Keypoint>{};
    final lm = frame[2] as List?;
    if (lm != null) {
      if (lm.length != BodyLandmark.values.length) {
        throw const FormatException('Expected 33 landmarks');
      }
      for (var i = 0; i < lm.length; i++) {
        final p = lm[i] as List?;
        if (p == null) continue;
        final joint = BodyLandmark.values[i];
        points[joint] = Keypoint(
          landmark: joint,
          x: (p[0] as num).toDouble(),
          y: (p[1] as num).toDouble(),
          likelihood: (p[2] as num).toDouble(),
        );
      }
    }
    replay.add(
      index,
      Duration(milliseconds: time),
      PoseFrame(imageWidth: width, imageHeight: height, keypoints: points),
    );
  }
  return {
    'source_id': source['source_id'],
    'events': replay.events,
    if (featureMode != FeatureMode.none) 'features': replay.features,
  };
}

const critical = {
  RejectReason.incompleteExtension,
  RejectReason.kneesDown,
  RejectReason.bellyDown,
};

({List<int> falseCritical, Map<String, int> tally}) compareLabels(
  List<RejectReason?> labelled,
  List<RejectReason?> judged,
) {
  var labelIndex = 0;
  final counted = <int>[];
  var normal = 0, normalCounted = 0;
  var incorrect = 0, notCounted = 0, rightReason = 0;
  var extraCounted = 0, extraRejected = 0;
  for (final (want, got) in align(labelled, judged)) {
    if (want == null) {
      if (got?.counted == true) {
        extraCounted++;
      } else if (got != null) {
        extraRejected++;
      }
      continue;
    }
    if (want.correct) {
      normal++;
      if (got?.counted == true) normalCounted++;
    } else {
      incorrect++;
      if (got?.counted != true) notCounted++;
      if (got?.reason == want.reason) rightReason++;
      if (critical.contains(want.reason) && got?.counted == true) {
        counted.add(labelIndex);
      }
    }
    labelIndex++;
  }
  return (
    falseCritical: counted,
    tally: {
      'normalReps': normal,
      'normalCounted': normalCounted,
      'incorrectReps': incorrect,
      'incorrectNotCounted': notCounted,
      'incorrectRightReason': rightReason,
      'extraCounted': extraCounted,
      'extraRejected': extraRejected,
    },
  );
}

List<RejectReason?> verdicts(List<List<Object>> events) => [
  for (final e in events)
    e.last == 'normal' ? null : RejectReason.values.byName(e.last as String),
];

Map<String, Object?> fixtureEvents(
  File file,
  String suite,
  Map<String, RepJudgeConfig> configs,
  FeatureMode featureMode,
) {
  final doc = jsonDecode(file.readAsStringSync()) as Map;
  final labels = doc['label'] as Map;
  final names = [
    for (final n in doc['landmarks'] as List)
      BodyLandmark.values.byName(n as String),
  ];
  final replay = StreamReplay(configs, featureMode);
  final frames = doc['frames'] as List;
  for (var i = 0; i < frames.length; i++) {
    final f = frames[i] as Map;
    if (f['mark'] == 'abandon') {
      replay.abandon();
      continue;
    }
    final p = f['p'] as List?;
    if (p == null) continue;
    final points = <BodyLandmark, Keypoint>{};
    for (var j = 0; j < names.length; j++) {
      final x = p[4 * j] as num?;
      if (x == null) continue;
      final n = names[j];
      points[n] = Keypoint(
        landmark: n,
        x: x.toDouble(),
        y: (p[4 * j + 1] as num).toDouble(),
        z: (p[4 * j + 2] as num).toDouble(),
        likelihood: (p[4 * j + 3] as num).toDouble(),
      );
    }
    replay.add(
      i,
      Duration(microseconds: f['t'] as int),
      PoseFrame(
        imageWidth: (f['w'] as num).toDouble(),
        imageHeight: (f['h'] as num).toDouble(),
        keypoints: points,
      ),
      moved: f['moved'] == true,
    );
  }
  final perRep = labels['perRep'] as List?;
  final expected = labels['expected'] as Map?;
  final baseEvents = replay.events['baseline'];
  final judgedBaseline = baseEvents == null ? null : verdicts(baseEvents);
  final labelled = perRep == null
      ? null
      : <RejectReason?>[
          for (final s in perRep)
            s == 'valid' ? null : RejectReason.values.byName(s as String),
        ];
  final baseline = labelled == null || judgedBaseline == null
      ? null
      : compareLabels(labelled, judgedBaseline);
  final safety = <String, Object>{};
  final tally = <String, Map<String, int>>{};
  for (final e in replay.events.entries) {
    final judged = verdicts(e.value);
    final compared = labelled == null ? null : compareLabels(labelled, judged);
    if (compared != null) tally[e.key] = compared.tally;
    if (judgedBaseline == null) continue;
    final pureCritical =
        expected?['valid'] == 0 &&
        (expected?['rejected'] as Map?)?.keys.any(
              (name) => critical.any((r) => r.name == name),
            ) ==
            true;
    safety[e.key] = {
      if (compared != null)
        'new_critical_false_accept_indices': compared.falseCritical
            .where((i) => !baseline!.falseCritical.contains(i))
            .toList(),
      if (compared != null)
        'additional_unmatched_valid':
            compared.tally['extraCounted']! - baseline!.tally['extraCounted']!,
      if (compared != null)
        'additional_counted_bad':
            baseline!.tally['incorrectNotCounted']! -
            compared.tally['incorrectNotCounted']!,
      if (pureCritical)
        'additional_valid_on_critical_recording':
            judged.where((v) => v == null).length -
            judgedBaseline.where((v) => v == null).length,
    };
  }
  return {
    'source_id': doc['id'],
    'suite': suite,
    'kind': labels['kind'],
    'expected': expected,
    'labelled': perRep,
    'events': replay.events,
    if (featureMode != FeatureMode.none) 'features': replay.features,
    'safety': safety,
    'tally': tally,
  };
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Expected <input.jsonl | --fixtures> <output.jsonl> [--features | --attempt-evidence] [preset ...]',
    );
  }
  final options = args.skip(2).toList();
  final featureMode = options.remove('--attempt-evidence')
      ? FeatureMode.attempt
      : options.remove('--features')
      ? FeatureMode.summary
      : FeatureMode.none;
  final configs = options.isEmpty
      ? presets
      : {
          for (final k in options)
            k: presets[k] ?? (throw ArgumentError('Unknown preset $k')),
        };
  final fixture = args[0] == '--fixtures';
  final out = File(args[1]).absolute;
  if (out.existsSync() ||
      (!fixture && File(args[0]).absolute.path == out.path)) {
    throw StateError('Use a fresh output path: ${out.path}');
  }
  final tmp = File('${out.path}.$pid.tmp');
  final sink = tmp.openWrite();
  var n = 0;
  try {
    if (fixture) {
      for (final folder in [
        'test/ai_eval/cases',
        'test/fixtures/pushup_cases',
      ]) {
        final files =
            Directory(folder)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.json'))
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));
        if (files.isEmpty) {
          throw StateError('No fixtures in $folder. Run from gymrats_app/.');
        }
        for (final f in files) {
          sink.writeln(
            jsonEncode(fixtureEvents(f, folder, configs, featureMode)),
          );
          n++;
        }
      }
    } else {
      final seen = <String>{};
      await for (final line in File(
        args[0],
      ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
        final source = jsonDecode(line) as Map<String, dynamic>;
        final id = source['source_id'] as String;
        if (!seen.add(id)) throw FormatException('Duplicate source $id');
        try {
          sink.writeln(jsonEncode(videoEvents(source, configs, featureMode)));
        } catch (e) {
          throw FormatException('$id: $e');
        }
        n++;
      }
    }
    if (n == 0) throw StateError('No sources');
    await sink.flush();
    await sink.close();
    await tmp.rename(out.path);
    stdout.writeln(
      'Replayed $n sources, ${configs.length} preset(s) to ${out.path}',
    );
  } catch (_) {
    await sink.close();
    if (await tmp.exists()) await tmp.delete();
    rethrow;
  }
}
