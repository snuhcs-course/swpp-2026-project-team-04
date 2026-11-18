// From gymrats_app: flutter test ../tools/diagnose/knee_rule_eval_test.dart.
// Use PUSHUP_FRAME_KNEE=false for the disabled comparison.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/rep_event.dart';

import '../../gymrats_app/test/ai_eval/eval_scorer.dart' show align, EvalReport;
import '../../gymrats_app/test/ai_eval/eval_cases.dart'
    show loadEvalCases, scoreCase;
import '../../gymrats_app/test/support/pushup_case_loader.dart';

void main() {
  test('report labelled historical cases with explicit rejects and misses', () {
    final rows = <Map<String, Object?>>[];
    for (final source in loadPushUpCases()) {
      final recording = source.recording;
      final label = recording.label;
      final expected =
          label.perRep ??
          List<RejectReason?>.filled(label.reps, label.kind.reason);
      final result = replay(recording);
      var normal = 0, normalCounted = 0, cheat = 0;
      var acceptedCheat = 0, rejectedCheat = 0, missedCheat = 0;
      var rightReason = 0, extraValid = 0, extraInvalid = 0;
      for (final (want, got) in align(expected, result.verdicts)) {
        if (want == null) {
          if (got!.counted) {
            extraValid++;
          } else {
            extraInvalid++;
          }
        } else if (want.correct) {
          normal++;
          if (got != null && got.counted) normalCounted++;
        } else {
          cheat++;
          if (got == null) {
            missedCheat++;
          } else if (got.counted) {
            acceptedCheat++;
          } else {
            rejectedCheat++;
            if (got.reason == want.reason) rightReason++;
          }
        }
      }
      expect(normal + cheat, label.reps);
      rows.add({
        'id': source.id,
        'kind': label.kind.name,
        'label_source': label.perRep == null ? 'homogeneous_kind' : 'perRep',
        'normal': normal,
        'normal_counted': normalCounted,
        'cheat': cheat,
        'accepted_cheat': acceptedCheat,
        'rejected_cheat': rejectedCheat,
        'missed_cheat': missedCheat,
        'right_reason': rightReason,
        'extra_valid': extraValid,
        'extra_invalid': extraInvalid,
        'judged_valid': result.valid,
        'judged_invalid': result.events.length - result.valid,
        'reasons': {
          for (final e in result.rejected.entries) e.key.name: e.value,
        },
      });
    }
    final totals = <String, int>{};
    for (final row in rows) {
      for (final entry in row.entries) {
        if (entry.value is int) {
          totals.update(
            entry.key,
            (value) => value + (entry.value as int),
            ifAbsent: () => entry.value as int,
          );
        }
      }
    }
    final frozen = [for (final source in loadEvalCases()) scoreCase(source)];
    final frozenTally = EvalReport(frozen).overall;
    var frozenExplicitRejections = 0;
    var frozenMissedCheats = 0;
    for (final source in frozen) {
      for (final (want, got) in align(source.labelled, source.judged)) {
        if (want == null || want.correct) continue;
        if (got == null) {
          frozenMissedCheats++;
        } else if (!got.counted) {
          frozenExplicitRejections++;
        }
      }
    }
    expect(
      frozenExplicitRejections + frozenMissedCheats,
      frozenTally.incorrectNotCounted,
    );
    final output = {
      'cases': rows.length,
      'totals': totals,
      'rows': rows,
      'frozen': {
        'cases': frozen.length,
        'normal': frozenTally.normalReps,
        'normal_counted': frozenTally.normalCounted,
        'cheat': frozenTally.incorrectReps,
        'accepted_cheat':
            frozenTally.incorrectReps - frozenTally.incorrectNotCounted,
        'rejected_cheat': frozenExplicitRejections,
        'missed_cheat': frozenMissedCheats,
        'right_reason': frozenTally.incorrectRightReason,
        'extra_valid': frozenTally.extraCounted,
        'extra_invalid': frozenTally.extraRejected,
      },
      'alignment': 'Existing frozen scorer minimum-edit alignment',
      'labels': 'Existing recording labels; mixed perRep labels take priority',
    };
    final file = File('build/ai_eval/historical-knee-rule.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
    // ignore: avoid_print
    print(jsonEncode(output));
    expect(rows, hasLength(12));
  });
}
