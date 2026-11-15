import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../gymrats_app/test/ai_eval/eval_cases.dart';
import '../../gymrats_app/test/ai_eval/eval_scorer.dart';
import '../../gymrats_app/test/support/pushup_case_loader.dart';

void main() {
  test('measure isolated push-up judge parameter candidates', () {
    final cases = loadEvalCases();
    final historic = loadPushUpCases();
    final configs = <String, RepJudgeConfig>{
      'baseline': const RepJudgeConfig(
        topHold: Duration(milliseconds: 300),
        smoothingTau: Duration(milliseconds: 65),
      ),
      'topHold200': const RepJudgeConfig(topHold: Duration(milliseconds: 200)),
      'topHold150': const RepJudgeConfig(topHold: Duration(milliseconds: 150)),
      'topHold100': const RepJudgeConfig(topHold: Duration(milliseconds: 100)),
      'lockout170': const RepJudgeConfig(
        topHold: Duration(milliseconds: 300),
        lockoutArmAngle: 170,
      ),
      'lockout168': const RepJudgeConfig(
        topHold: Duration(milliseconds: 300),
        lockoutArmAngle: 168,
      ),
      'smooth45': const RepJudgeConfig(
        topHold: Duration(milliseconds: 300),
        smoothingTau: Duration(milliseconds: 45),
      ),
      'smooth35': const RepJudgeConfig(
        topHold: Duration(milliseconds: 300),
        smoothingTau: Duration(milliseconds: 35),
      ),
      'noise75': const RepJudgeConfig(
        topHold: Duration(milliseconds: 300),
        noiseFloor: Duration(milliseconds: 75),
      ),
    };
    final historicBaseline = {
      for (final c in historic)
        c.id: replay(c.recording, config: configs['baseline']!).valid,
    };
    final frozenBaseline = {
      for (final c in cases) c.id: scoreCase(c, config: configs['baseline']!),
    };
    for (final entry in configs.entries) {
      final report = EvalReport([
        for (final c in cases) scoreCase(c, config: entry.value),
      ]);
      final tally = report.overall;
      final regressions = <String>[];
      final frozenRegressions = <String>[];
      for (final c in cases) {
        final previous = EvalTally()..add(frozenBaseline[c.id]!);
        final current = EvalTally()..add(scoreCase(c, config: entry.value));
        if (current.incorrectNotCounted < previous.incorrectNotCounted ||
            current.extraCounted > previous.extraCounted) {
          frozenRegressions.add(
            '${c.id}: rejected ${previous.incorrectNotCounted}->${current.incorrectNotCounted}, extra ${previous.extraCounted}->${current.extraCounted}',
          );
        }
      }
      for (final c in historic) {
        final kind = c.recording.label.kind.name;
        if (!['knees', 'bellyDown'].contains(kind)) continue;
        final valid = replay(c.recording, config: entry.value).valid;
        final previous = historicBaseline[c.id]!;
        if (valid > previous) regressions.add('${c.id}: $previous -> $valid');
      }
      // ignore: avoid_print
      print(
        '${entry.key}: M1 ${tally.normalCounted}/${tally.normalReps}, M2 ${tally.incorrectNotCounted}/${tally.incorrectReps}, M3 ${tally.incorrectRightReason}/${tally.incorrectReps}; historical knee/belly extra valid: $regressions',
      );
      // ignore: avoid_print
      print('  frozen case regressions: $frozenRegressions');
    }
  });
}
