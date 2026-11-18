import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/rep_event.dart';

import '../eval_scorer.dart' as frozen;
import 'iter4_scorer.dart';

void main() {
  test(
    'alignment is identical to frozen scorer for existing reason symbols',
    () {
      final random = Random(217);
      const symbols = <RejectReason?>[
        null,
        RejectReason.kneesDown,
        RejectReason.shallowSquat,
        RejectReason.standUpFully,
      ];
      for (var run = 0; run < 200; run++) {
        final expected = List.generate(
          random.nextInt(9),
          (_) => symbols[random.nextInt(4)],
        );
        final actual = List.generate(
          random.nextInt(9),
          (_) => symbols[random.nextInt(4)],
        );
        final reference = frozen
            .align(expected, actual)
            .map(
              (p) => (
                p.$1 == null ? null : p.$1!.reason?.name ?? 'valid',
                p.$2 == null ? null : p.$2!.reason?.name ?? 'valid',
              ),
            )
            .toList();
        expect(
          alignLabels(
            expected.map((e) => e?.name ?? 'valid').toList(),
            actual.map((e) => e?.name ?? 'valid').toList(),
          ),
          reference,
        );
      }
    },
  );

  test('M1 M2 M3 preserve misses wrong reasons and unmatched extras', () {
    final t = Iter4Tally()..add(['valid', 'valid'], ['valid']);
    t.add(['kneesDown', 'shallowSquat'], ['kneesDown', 'standUpFully']);
    t.add(['standUpFully'], []);
    t.add([], ['valid', 'kneesDown']);
    expect(t.m1, .5);
    expect(t.m2, 1);
    expect(t.m3, 1 / 3);
    expect(t.explicitRejected, 2);
    expect(t.missedIncorrect, 1);
    expect(t.extraCounted, 1);
    expect(t.extraRejected, 1);
  });

  test('pending labels do not turn predictions into ground truth', () {
    final t = Iter4Tally()..add(null, ['valid', 'kneesDown']);
    expect(t.pendingCases, 1);
    expect(t.scoredCases, 0);
    expect([t.m1, t.m2, t.m3], [null, null, null]);
    expect(t.extraCounted, 0);
  });

  test('chair squats are scored on depth and full standing', () {
    final t = Iter4Tally()
      ..add(
        ['valid', 'shallowSquat', 'standUpFully'],
        ['valid', 'shallowSquat', 'standUpFully'],
      );
    expect(t.m1, 1);
    expect(t.m2, 1);
    expect(t.m3, 1);
  });

  test('pending labels or primary metric regression cannot verify benefit', () {
    final off = Iter4Tally()
      ..add(['valid', 'kneesDown'], ['valid', 'kneesDown']);
    final pending = Iter4Tally()..add(null, ['valid']);
    expect(verifiedBenefit(off, pending), isFalse);
    final worse = Iter4Tally()..add(['valid', 'kneesDown'], ['valid', 'valid']);
    expect(verifiedBenefit(off, worse), isFalse);
    expect(verifiedBenefit(off, off), isFalse);
    final poorer = Iter4Tally()
      ..add(['valid', 'kneesDown'], ['kneesDown', 'kneesDown']);
    expect(verifiedBenefit(poorer, off), isTrue);
  });
}
