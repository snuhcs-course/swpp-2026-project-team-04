// Run from gymrats_app with flutter test ../tools/diagnose/pushup_angle_fixtures_test.dart
// PUSHUP_FIXTURE_BASELINE points to previous shipping --fixtures JSONL.
// PUSHUP_ANGLE_REPORT points to a new JSON output file outside the repository.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/rep_event.dart';

import '../../gymrats_app/test/ai_eval/eval_cases.dart';
import '../../gymrats_app/test/ai_eval/eval_scorer.dart';
import '../../gymrats_app/test/support/pushup_case_loader.dart';

Map<String, Object> counts(EvalTally t, ({int normal, int invalid}) missing) =>
    {
      'normal': t.normalReps,
      'normalCounted': t.normalCounted,
      'normalRejected': t.normalReps - t.normalCounted - missing.normal,
      'normalNoVerdict': missing.normal,
      'incorrect': t.incorrectReps,
      'incorrectNotCounted': t.incorrectNotCounted,
      'incorrectExplicitlyRejected': t.incorrectNotCounted - missing.invalid,
      'incorrectCounted': t.incorrectReps - t.incorrectNotCounted,
      'incorrectNoVerdict': missing.invalid,
      'incorrectRightReason': t.incorrectRightReason,
      'extraCounted': t.extraCounted,
      'extraRejected': t.extraRejected,
    };

List<int> falseCritical(
  List<RejectReason?> labels,
  List<RejectReason?> predictions,
) {
  const critical = {
    RejectReason.bellyDown,
    RejectReason.incompleteExtension,
    RejectReason.kneesDown,
  };
  final indices = <int>[];
  var index = 0;
  for (final (truth, prediction) in align(labels, predictions)) {
    if (truth == null) continue;
    if (critical.contains(truth.reason) && prediction?.counted == true) {
      indices.add(index);
    }
    index++;
  }
  return indices;
}

void main() {
  test(
    'compare measured and missing phone pitch on the same recorded landmarks',
    () {
      final destination = File(Platform.environment['PUSHUP_ANGLE_REPORT']!);
      expect(
        destination.existsSync(),
        isFalse,
        reason: 'Use a new report path',
      );
      final baseline = <String, List<RejectReason?>>{};
      for (final line in File(
        Platform.environment['PUSHUP_FIXTURE_BASELINE']!,
      ).readAsLinesSync()) {
        final row = jsonDecode(line) as Map;
        final labels = row['events']['app_default'] as List;
        expect(baseline.containsKey(row['source_id']), isFalse);
        baseline[row['source_id'] as String] = [
          for (final e in labels)
            e.last == 'normal'
                ? null
                : RejectReason.values.byName(e.last as String),
        ];
      }
      final frozen = {for (final c in loadEvalCases()) c.id: c};
      final historic = loadPushUpCases();
      expect(frozen, hasLength(32));
      expect(historic, hasLength(12));
      final tallies = <String, EvalTally>{};
      final missing = <String, ({int normal, int invalid})>{};
      final rows = <Map<String, Object?>>[];
      for (final c in [...frozen.values.map((c) => c.file), ...historic]) {
        final r = c.recording;
        final gold = frozen[c.id];
        final angles = [
          for (final f in r.frames)
            if (f.phoneTilt case final double angle) angle,
        ]..sort();
        expect(angles, isNotEmpty, reason: c.id);
        final mid = angles.length ~/ 2;
        final median = (angles[mid] + angles[(angles.length - 1) ~/ 2]) / 2;
        final band = median < 70 ? '60' : '80';
        final baselineSequence = baseline.remove(c.id)!;
        final sequences = {
          'previous': baselineSequence,
          'noIMU': replay(r, useRecordedTilt: false).verdicts,
          'measured': replay(r).verdicts,
        };
        final criticalDiffs = <String, List<int>>{};
        final labels = r.label.perRep;
        final previousFalse = labels == null
            ? <int>[]
            : falseCritical(labels, baselineSequence);
        for (final e in sequences.entries) {
          if (labels != null) {
            criticalDiffs[e.key] = falseCritical(
              labels,
              e.value,
            ).where((i) => !previousFalse.contains(i)).toList();
          }
          if (gold != null) {
            final result = EvalCase(
              id: c.id,
              person: gold.person,
              set: gold.set,
              labelled: gold.labelled,
              judged: e.value,
            );
            final unmatched = align(
              result.labelled,
              result.judged,
            ).where((pair) => pair.$1 != null && pair.$2 == null);
            final missedNormal = unmatched.where((p) => p.$1!.correct).length;
            final missedInvalid = unmatched.length - missedNormal;
            for (final group in ['all', band]) {
              final key = '${e.key}/$group';
              (tallies[key] ??= EvalTally()).add(result);
              final soFar = missing[key] ?? (normal: 0, invalid: 0);
              missing[key] = (
                normal: soFar.normal + missedNormal,
                invalid: soFar.invalid + missedInvalid,
              );
            }
          }
        }
        rows.add({
          'id': c.id,
          'suite': gold == null ? 'historic' : 'frozen',
          'tiltCount': angles.length,
          'frameCount': r.frames.length,
          'medianTilt': median,
          'tiltBand': band,
          'minTilt': angles.first,
          'maxTilt': angles.last,
          'expected': r.label.expected?.toJson(),
          'newFalseCriticalLabelIndices': criticalDiffs,
          for (final e in sequences.entries)
            e.key: e.value.map((reason) => reason?.name ?? 'normal').toList(),
        });
      }
      expect(baseline, isEmpty);
      destination.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'stratification': 'Median measured screen angle from floor; 70 degrees separates bands. Judge sees only current and preceding frames.',
          'frozen': {
            for (final t in tallies.entries)
              t.key: counts(t.value, missing[t.key]!),
          },
          'recordings': rows,
        }),
      );
    },
  );
}
