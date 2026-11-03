import 'dart:io';

import 'package:gymrats_app/demo/rep_judge_demo.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../support/pushup_case_loader.dart';
import 'eval_plan.dart';
import 'eval_scorer.dart';

/// Where the frozen set lives, relative to `gymrats_app/`: one folder per
/// recorder, named by their initials, with eight recordings each.
const evalCaseRoot = 'test/ai_eval/cases';

/// The set a recording belongs to, from what it shows and where the phone
/// stood. `placement` starts with the position letter of the recording
/// standard (`A, about 50cm, 67°`, `B`, `C-target-100cm-60to65deg`, ...),
/// and each position holds two sets that differ by kind. Set 4 was
/// recorded as "Free (no label)" because the app has no kind for it.
EvalSet evalSetFor(CaseKind kind, String placement) {
  // The position is one letter A-D on its own at the start: a word such as
  // "about 50cm" is not a position.
  final letter = _position.firstMatch(placement)?.group(1)?.toUpperCase();
  final set = switch ((kind, letter)) {
    (CaseKind.normal, 'A') => EvalSet.normalA,
    (CaseKind.knees, 'A') => EvalSet.kneelingBow,
    (CaseKind.halfRepHeadNod, 'B') => EvalSet.halfRepHeadNod,
    (CaseKind.unlabelled, 'B') => EvalSet.noLockout,
    (CaseKind.knees, 'C') => EvalSet.kneePushUp,
    (CaseKind.bellyDown, 'C') => EvalSet.bellyDown,
    (CaseKind.normal, 'D') => EvalSet.normalD,
    (CaseKind.armsStraight, 'D') => EvalSet.kneelingStraightArms,
    _ => null,
  };
  if (set == null) {
    throw FormatException(
      'no set of the recording standard shows ${kind.name} at position '
      '"$placement"',
    );
  }
  return set;
}

final _position = RegExp(r'^\s*([A-Da-d])(?=$|[\s,\-])');

/// One recording of the frozen set with the set it was made for.
class LoadedEvalCase {
  const LoadedEvalCase({
    required this.person,
    required this.file,
    required this.set,
  });

  /// The recorder's initials: the folder name.
  final String person;
  final PushUpCase file;
  final EvalSet set;

  PushUpRecording get recording => file.recording;
  String get id => file.id;

  /// What the person actually did, rep by rep, from the record sheet
  /// (`label.perRep`). Every case of the frozen set has it; a recording
  /// without it cannot be scored, so it is an error rather than a fallback
  /// to the set's plan.
  List<RejectReason?> get labelled {
    final perRep = recording.label.perRep;
    if (perRep == null) {
      throw FormatException('$id has no label.perRep; label it from its sheet');
    }
    return perRep;
  }
}

/// Every recording under [root], by person folder and then by file name.
/// A folder that is not a directory, such as a README, is skipped.
List<LoadedEvalCase> loadEvalCases([String root = evalCaseRoot]) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  final folders = dir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final folder in folders)
      for (final file in loadPushUpCases(folder.path))
        LoadedEvalCase(
          person: folder.uri.pathSegments.where((s) => s.isNotEmpty).last,
          file: file,
          set: evalSetFor(
            file.recording.label.kind,
            file.recording.setup.placement,
          ),
        ),
  ];
}

/// Replays [c] through the current judge and pairs it with its label.
EvalCase scoreCase(
  LoadedEvalCase c, {
  RepJudgeConfig config = const RepJudgeConfig(),
}) => EvalCase(
  id: c.id,
  person: c.person,
  set: c.set,
  labelled: c.labelled,
  judged: replay(c.recording, config: config).verdicts,
);

/// One Markdown row per case: what was labelled, what the judge closed in
/// the replay, what it closed while filming (`live`, possibly an older
/// judge), and how label and replay differ (`false count`, `missed rep`,
/// `wrong reason`, or `ok`).
String caseTable(Iterable<(LoadedEvalCase, EvalCase)> scored) {
  final rows = <String>[
    '| Case | Person | Set | Labelled | Replay | Live | Errors |',
    '|---|---|---|---|---|---|---|',
  ];
  for (final (loaded, c) in scored) {
    final errors = _errorTypes(c);
    rows.add(
      '| ${c.id} | ${c.person} | ${c.set.number} ${c.set.position.code} | '
      '${_verdicts(c.labelled)} | ${_verdicts(c.judged)} | '
      '${_verdicts(liveResult(loaded.recording).verdicts)} | '
      '${errors.isEmpty ? 'ok' : errors.join(', ')} |',
    );
  }
  return rows.join('\n');
}

/// How the judged reps of [c] differ from its label, worst first, read from
/// the same alignment the metrics use: a `false count` is a rep counted
/// that the label rejects, a `missed rep` a labelled good rep not counted,
/// a `wrong reason` any other difference in the rejected reps.
List<String> _errorTypes(EvalCase c) {
  var falseCount = false, missed = false, wrongReason = false;
  for (final (want, got) in align(c.labelled, c.judged)) {
    if (want?.reason == got?.reason && want != null && got != null) continue;
    if (got != null && got.counted && !(want?.counted ?? false)) {
      falseCount = true;
    } else if (want != null && want.counted) {
      missed = true;
    } else {
      wrongReason = true;
    }
  }
  return [
    if (falseCount) 'false count',
    if (missed) 'missed rep',
    if (wrongReason) 'wrong reason',
  ];
}

/// M1–M3 per set of the recording standard, over the cases of all four
/// people, so a failing motion shows up apart from a failing position.
String setTable(Iterable<EvalCase> cases) {
  final bySet = <EvalSet, EvalTally>{};
  for (final c in cases) {
    bySet.putIfAbsent(c.set, EvalTally.new).add(c);
  }
  return [
    '| Set | Motion | Position | M1 | M2 | M3 |',
    '|---|---|---|---|---|---|',
    for (final set in EvalSet.values)
      if (bySet[set] case final t?)
        '| ${set.number} | ${set.motion} | ${set.position.code} | '
            '${_pct(t.m1)} | ${_pct(t.m2)} | ${_pct(t.m3)} |',
  ].join('\n');
}

String _pct(double? v) => v == null ? '–' : '${(v * 100).toStringAsFixed(1)}%';

/// Reps as a short string: `ok` for a counted rep, else the reason, with
/// runs of the same verdict folded (`ok×10`, `kneesDown×4 ok`).
String _verdicts(List<RejectReason?> reps) {
  if (reps.isEmpty) return '(none)';
  final out = <String>[];
  var i = 0;
  while (i < reps.length) {
    var j = i;
    while (j < reps.length && reps[j] == reps[i]) {
      j++;
    }
    final name = reps[i]?.name ?? 'ok';
    out.add(j - i == 1 ? name : '$name×${j - i}');
    i = j;
  }
  return out.join(' ');
}
