import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import 'eval_cases.dart';
import 'eval_plan.dart';
import 'eval_scorer.dart';

/// The evaluation run of the frozen push-up set (P17): every recording
/// replayed through the current [RepJudge] with its default
/// [RepJudgeConfig], scored against the record-sheet labels, and reported
/// as M1–M3 against the thresholds declared in `eval_plan.dart`.
///
/// The run always prints the report and writes it to
/// `build/ai_eval/report.md` (git-ignored), so a normal `flutter test`
/// shows the numbers without failing the suite when the judge is below a
/// threshold. Run it with `--dart-define=AI_EVAL_STRICT=true` to make the
/// thresholds assertions, as for the results branch.
const strict = bool.fromEnvironment('AI_EVAL_STRICT');

void main() {
  test('frozen set: M1-M3 of the current judge against the thresholds', () {
    final loaded = loadEvalCases();
    expect(loaded.length, 32, reason: 'the frozen set has 32 cases');
    final scored = [for (final c in loaded) (c, scoreCase(c))];
    final report = EvalReport([for (final (_, c) in scored) c]);

    final config = const RepJudgeConfig();
    final text = [
      '# Push-up judge evaluation (frozen set)',
      '',
      'Run: ${DateTime.now().toIso8601String()} · judge config: '
          'minLikelihood ${config.minLikelihood}, '
          'bottomDepth ${config.bottomDepth}, '
          'minShoulderDrop ${config.minShoulderDrop}, '
          'maxTorsoDrop ${config.maxTorsoDrop} · '
          'cases: ${report.caseCount}',
      '',
      report.toMarkdown(),
      '',
      '## Per set',
      '',
      setTable([for (final (_, c) in scored) c]),
      '',
      '## Per case',
      '',
      caseTable(scored),
      '',
    ].join('\n');

    // ignore: avoid_print
    print(text);
    final out = File('build/ai_eval/report.md');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(text);

    final o = report.overall;
    expect(o.normalReps, greaterThan(0));
    expect(o.incorrectReps, greaterThan(0));
    if (strict) {
      expect(o.m1, greaterThanOrEqualTo(m1CountAccuracyThreshold));
      expect(o.m2, greaterThanOrEqualTo(m2RejectionRateThreshold));
      expect(o.m3, greaterThanOrEqualTo(m3RightReasonThreshold));
    }
  });
}
