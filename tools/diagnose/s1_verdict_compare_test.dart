import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../gymrats_app/test/ai_eval/eval_cases.dart';
import '../../gymrats_app/test/support/pushup_case_loader.dart';

void main() {
  test('compare all frozen and historical event sequences', () {
    const before = RepJudgeConfig(topHold: Duration(milliseconds: 300));
    const after = RepJudgeConfig(topHold: Duration(milliseconds: 250));
    final frozen = loadEvalCases();
    final historical = loadPushUpCases();
    expect(frozen, isNotEmpty, reason: 'run from gymrats_app with frozen data');
    expect(historical, isNotEmpty, reason: 'historical fixtures are required');
    for (final c in frozen) {
      final a = replay(c.recording, config: before).verdicts;
      final b = replay(c.recording, config: after).verdicts;
      expect(b, orderedEquals(a), reason: 'frozen ${c.id}');
    }
    for (final c in historical) {
      final a = replay(c.recording, config: before).verdicts;
      final b = replay(c.recording, config: after).verdicts;
      expect(b, orderedEquals(a), reason: 'historical ${c.id}');
    }
  });
}
