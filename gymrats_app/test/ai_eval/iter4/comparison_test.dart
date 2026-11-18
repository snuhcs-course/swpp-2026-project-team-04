import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../eval_cases.dart' as frozen;
import '../eval_scorer.dart' as frozen;
import 'iter4_cases.dart';
import 'iter4_scorer.dart';

String metric(double? v) =>
    v == null ? 'N/A' : '${(v * 100).toStringAsFixed(1)}%';

void main() {
  test('fixed and Iteration4 sets are reported separately for this build mode', () {
    final enabled = RepJudge().useFrameKnee;
    final mode = enabled ? 'on' : 'off';
    final original = frozen.loadEvalCases();
    expect(original, hasLength(32));
    final fixed = frozen.EvalReport([
      for (final c in original) frozen.scoreCase(c),
    ]);
    final cases = loadIter4Cases();
    expect(cases, hasLength(16));
    final total = Iter4Tally();
    final byExercise = <String, Iter4Tally>{};
    final byPerson = <String, Iter4Tally>{};
    final rows = <Map<String, Object?>>[];
    for (final c in cases) {
      final events = replayIter4(c);
      final considered = events.where((e) => c.includes(e.at)).toList();
      final actual = [
        for (final e in considered)
          e.valid ? 'valid' : e.reason?.name ?? 'unexplainedReject',
      ];
      total.add(c.expected, actual);
      byExercise
          .putIfAbsent(c.exercise, Iter4Tally.new)
          .add(c.expected, actual);
      byPerson
          .putIfAbsent(c.participant, Iter4Tally.new)
          .add(c.expected, actual);
      rows.add({
        'id': c.id,
        'participant': c.participant,
        'exercise': c.exercise,
        'scenario': c.scenario,
        'labelStatus': c.labelled ? 'confirmed' : 'pending',
        'expected': c.expected,
        'predicted': actual,
        'frameCount': (c.data['frames'] as List).length,
        'windowProvided': c.data['evaluationWindowUs'] != null,
        'eventsOutsideWindow': events.length - considered.length,
        'events': [
          for (final e in events)
            {
              't': e.at.inMicroseconds,
              'valid': e.valid,
              'reason': e.reason?.name,
              'insideWindow': c.includes(e.at),
            },
        ],
      });
    }
    String git(List<String> args) {
      final result = Process.runSync('git', args);
      if (result.exitCode != 0) return 'unavailable';
      return (result.stdout as String).trim();
    }

    final revision = git(['rev-parse', 'HEAD']);
    final modified = git(['diff', '--name-only', '--', 'lib/services/pose']);
    final codeBlobs = {
      for (final file in [
        'lib/services/pose/pose_metrics.dart',
        'lib/services/pose/rep_judge.dart',
        'lib/services/pose/squat_rep_judge.dart',
        'test/ai_eval/eval_cases.dart',
        'test/ai_eval/eval_scorer.dart',
        'test/ai_eval/iter4/iter4_cases.dart',
        'test/ai_eval/iter4/iter4_scorer.dart',
        'test/ai_eval/iter4/comparison_test.dart',
        'test/ai_eval/cases_iter4/manifest.json',
      ])
        file: git(['hash-object', file]),
    };
    final f = fixed.overall;
    final data = {
      'runUtc': DateTime.now().toUtc().toIso8601String(),
      'revision': revision,
      'codeModified': modified.isNotEmpty,
      'sourceBlobs': codeBlobs,
      'frameKnee': enabled,
      'frozen': {
        'caseCount': fixed.caseCount,
        'm1': f.m1,
        'm2': f.m2,
        'm3': f.m3,
        'normal': f.normalReps,
        'normalCounted': f.normalCounted,
        'incorrect': f.incorrectReps,
        'incorrectNotCounted': f.incorrectNotCounted,
        'rightReason': f.incorrectRightReason,
        'extraCounted': f.extraCounted,
        'extraRejected': f.extraRejected,
      },
      'iter4': {
        'caseCount': cases.length,
        'overall': total.toJson(),
        'byExercise': {
          for (final e in byExercise.entries) e.key: e.value.toJson(),
        },
        'byParticipant': {
          for (final e in byPerson.entries) e.key: e.value.toJson(),
        },
        'cases': rows,
      },
      'defaultPolicy':
          'OFF until complete human labels and reviewed M1/M2 benefit',
      'chairPolicy': 'range_only: depth and full standing; chair use itself is allowed (user confirmed 2026-11-18)',
      'limitations': [
        'No source MP4s in repository.',
        'New expected counts/labels are not inferred from filenames or predictions.',
        'Pending cases have no M1/M2/M3 contribution; predictions are diagnostics only.',
        'No IMU, real camera scheduling, setup or person guard in offline replay.',
        'Hyunwoo push-up clips informed rule development; not an untouched holdout.',
      ],
    };
    final text = <String>[
      '# PR75 AI evaluation: knee rule $mode',
      '',
      'UTC run: ${data['runUtc']}; revision: `$revision`; modified code: ${modified.isNotEmpty}.',
      'Exact source blobs are recorded in the companion JSON. No MP4s are published.',
      '',
      '## Frozen push-up set (unchanged32 cases)',
      '',
      fixed.toMarkdown(),
      '',
      '## Iteration4 coordinate set (separate16 cases)',
      '',
      '| Group | Confirmed cases | Pending cases | M1 | M2 | M3 |',
      '|---|---:|---:|---:|---:|---:|',
      '| Overall |${total.scoredCases}|${total.pendingCases}|${metric(total.m1)}|${metric(total.m2)}|${metric(total.m3)}|',
      for (final e in {...byExercise, ...byPerson}.entries)
        '| ${e.key} |${e.value.scoredCases}|${e.value.pendingCases}|${metric(e.value.m1)}|${metric(e.value.m2)}|${metric(e.value.m3)}|',
      '',
      'Pending human labels are N/A, not zero accuracy and not a benefit claim.',
      'M2 includes incorrect repetitions with no verdict; explicit rejects, misses and extras are distinct in JSON.',
      'Default remains OFF until all per-rep labels are confirmed and benefit is reviewed.',
      '',
      '## Unscored prediction diagnostics',
      '',
      '| Case | Exercise | Label status | Accepted events | Rejected events |',
      '|---|---|---|---:|---:|',
      for (final r in rows)
        '| ${r['id']} | ${r['exercise']} | ${r['labelStatus']} |${(r['predicted'] as List).where((v) => v == 'valid').length}|${(r['predicted'] as List).where((v) => v != 'valid').length}|',
      '',
      'These event counts are not expected repetition counts. Approach/recovery events may be included unless a human exercise window is provided.',
      'See cases_iter4/README.md for independent label definitions and the agreed depth/full-standing squat criteria.',
      'No physical floor-contact accuracy, live-device performance or new-person generalization is established.',
      '',
    ].join('\n');
    final out = Directory('build/ai_eval_iter4')..createSync(recursive: true);
    File('${out.path}/comparison-$mode.md').writeAsStringSync(text);
    File('${out.path}/comparison-$mode.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    // ignore: avoid_print
    print(
      'fixed mode=$mode M1=${metric(f.m1)} M2=${metric(f.m2)} M3=${metric(f.m3)}; '
      'iter4 confirmed=${total.scoredCases} pending=${total.pendingCases}',
    );
    expect(f.normalReps, greaterThan(0));
    expect(f.incorrectReps, greaterThan(0));
    expect(total.scoredCases + total.pendingCases, 16);
  });
}
