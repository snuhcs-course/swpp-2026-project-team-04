import 'dart:io';
import 'dart:math' as math;

import 'package:gymrats_app/demo/rep_judge_demo.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

/// Where the recorder's files go, relative to `gymrats_app/`.
const pushUpCaseFolder = 'test/fixtures/pushup_cases';

/// One recorded set and the file it came from.
class PushUpCase {
  const PushUpCase({required this.fileName, required this.recording});

  final String fileName;
  final PushUpRecording recording;

  String get id => recording.id;
}

/// Every `.json` recording in [folder], by file name. Other files, such as
/// the folder's README, are left out. A missing folder holds no cases.
List<PushUpCase> loadPushUpCases([String folder = pushUpCaseFolder]) {
  final dir = Directory(folder);
  if (!dir.existsSync()) return const [];
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      PushUpCase(
        fileName: file.uri.pathSegments.last,
        recording: _decode(file),
      ),
  ];
}

/// A broken file fails the load with its name, not only a stack trace.
PushUpRecording _decode(File file) {
  try {
    return PushUpRecording.decode(file.readAsStringSync());
  } on Object catch (e) {
    throw FormatException('${file.path}: $e');
  }
}

/// The reps a judge closed over one recording.
class CaseResult {
  const CaseResult(this.events);

  final List<RepEvent> events;

  int get valid => events.where((e) => e.valid).length;

  Map<RejectReason, int> get rejected {
    final counts = <RejectReason, int>{};
    for (final e in events) {
      final reason = e.reason;
      if (e.valid || reason == null) continue;
      counts[reason] = (counts[reason] ?? 0) + 1;
    }
    return counts;
  }

  /// The closed reps in order: null for a counted rep, else its reason.
  List<RejectReason?> get verdicts => [
    for (final e in events) e.valid ? null : e.reason,
  ];

  /// True when [errorTypes] finds nothing. An unlabelled set always
  /// matches; the replay test leaves it out.
  bool matches(RecordingLabel label) => errorTypes(label).isEmpty;

  /// How this result is wrong against [label], worst first.
  ///
  /// A false count is a rep counted that the label rejects, a missed rep is
  /// a labelled good rep not counted, and a wrong reason is any other
  /// difference in the rejected reps. With [RecordingLabel.perRep] the reps
  /// are compared in order (aligned by the fewest edits), so these cannot
  /// cancel out; otherwise only the totals in [RecordingLabel.expected] are.
  List<String> errorTypes(RecordingLabel label) {
    final perRep = label.perRep;
    if (perRep != null) return _inOrder(perRep);
    final expected = label.expected;
    if (expected == null) return const [];
    return [
      if (valid > expected.valid) 'false count',
      if (valid < expected.valid) 'missed rep',
      if (valid == expected.valid && !_sameCounts(rejected, expected.rejected))
        'wrong reason',
    ];
  }

  /// Lines the judged reps up with the labelled ones by the fewest edits,
  /// so one rep the judge never closed does not shift every later rep.
  List<String> _inOrder(List<RejectReason?> labelled) {
    final judged = verdicts;
    final n = labelled.length, m = judged.length;
    // cost[i][j]: edits to turn labelled[i..] into judged[j..].
    final cost = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (var i = n; i >= 0; i--) {
      for (var j = m; j >= 0; j--) {
        if (i == n || j == m) {
          cost[i][j] = (n - i) + (m - j);
        } else {
          final same = labelled[i] == judged[j] ? 0 : 1;
          cost[i][j] = math.min(
            cost[i + 1][j + 1] + same,
            math.min(cost[i + 1][j], cost[i][j + 1]) + 1,
          );
        }
      }
    }
    var falseCount = false, missed = false, wrongReason = false;
    var i = 0, j = 0;
    while (i < n || j < m) {
      final same = i < n && j < m && labelled[i] == judged[j] ? 0 : 1;
      if (i < n && j < m && cost[i][j] == cost[i + 1][j + 1] + same) {
        final want = labelled[i++], got = judged[j++];
        if (want == got) continue;
        if (got == null) {
          falseCount = true;
        } else if (want == null) {
          missed = true;
        } else {
          wrongReason = true;
        }
      } else if (i < n && cost[i][j] == cost[i + 1][j] + 1) {
        // A labelled rep the judge never closed.
        if (labelled[i++] == null) {
          missed = true;
        } else {
          wrongReason = true;
        }
      } else {
        // A rep the judge closed that is not in the label.
        if (judged[j++] == null) {
          falseCount = true;
        } else {
          wrongReason = true;
        }
      }
    }
    return [
      if (falseCount) 'false count',
      if (missed) 'missed rep',
      if (wrongReason) 'wrong reason',
    ];
  }

  @override
  String toString() =>
      CaseExpectation(valid: valid, rejected: rejected).toString();

  static bool _sameCounts(Map<RejectReason, int> a, Map<RejectReason, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

/// Feeds [recording] to a fresh [RepJudge] the way the counter did: each
/// frame at the time the judge read, an [FrameMark.abandon] where the
/// counter abandoned, and the phone check on each closed rep.
CaseResult replay(
  PushUpRecording recording, {
  RepJudgeConfig config = const RepJudgeConfig(),
}) {
  var now = Duration.zero;
  final judge = RepJudge(config: config, clock: () => now);
  final events = <RepEvent>[];
  for (final frame in recording.frames) {
    if (frame.mark == FrameMark.abandon) {
      judge.abandon();
      continue;
    }
    final pose = frame.pose;
    if (pose == null) continue;
    now = frame.at;
    final event = judge.update(pose).event;
    if (event != null) {
      events.add(rejectIfPhoneMoved(event, phoneMoved: frame.phoneMoved));
    }
  }
  return CaseResult(events);
}

/// The verdicts the judge gave while the set was filmed.
CaseResult liveResult(PushUpRecording recording) =>
    CaseResult(recording.liveEvents);

/// One line for a failed case: label, expected, replay, live, error types.
String describeCase(PushUpCase c, CaseResult result) {
  final r = c.recording;
  final expected = r.label.expected;
  return '${c.fileName}: ${r.label.kind.label} x${r.label.reps} '
      '(${r.setup.device}, ${r.setup.model.name}, ${r.setup.lighting}, '
      '${r.setup.placement}) | expected $expected | replay $result | '
      'live ${liveResult(r)}'
      '${expected == null && r.label.perRep == null ? '' : ' | ${result.errorTypes(r.label).join(', ')}'}';
}
