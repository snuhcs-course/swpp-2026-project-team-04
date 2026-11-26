import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/report_metrics.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/squat_rep_judge.dart';

/// A rep closed [ms] into the round.
RepRecord rep(
  int ms, {
  bool valid = true,
  double? depth,
  int? descentMs,
  RejectReason? reason,
}) => RepRecord(
  index: ms,
  valid: valid,
  at: Duration(milliseconds: ms),
  reason: valid ? null : (reason ?? RejectReason.insufficientDepth),
  maxDepth: depth,
  descent: descentMs == null ? null : Duration(milliseconds: descentMs),
);

/// [n] working samples with the two elbows [gap] degrees apart.
List<FormSample> elbows(double gap, {int n = 12}) => [
  for (var i = 0; i < n; i++)
    FormSample(
      at: Duration(milliseconds: i * 100),
      depth: 0.9,
      leftElbow: 90,
      rightElbow: 90 + gap,
    ),
];

FormReport report(
  List<RepRecord> reps, {
  ExerciseType exercise = ExerciseType.pushUp,
  List<FormSample> samples = const [],
  int endedMinute = 10,
  Duration round = const Duration(seconds: 30),
}) => FormReport(
  endedAt: DateTime(2026, 11, 23, 14, endedMinute),
  opponentName: 'RepBot',
  roundLength: round,
  reps: reps,
  samples: samples,
  exercise: exercise,
);

/// [n] counted reps spread over the first [untilMs] of the round.
List<RepRecord> counted(int n, {int fromMs = 0, int untilMs = 30000}) => [
  for (var i = 0; i < n; i++)
    rep(fromMs + (untilMs - fromMs) * i ~/ n, depth: 2.0, descentMs: 700),
];

void main() {
  group('the five axes', () {
    test('accuracy is counted over judged reps', () {
      final m = ReportMetrics.of(
        report([...counted(6), rep(29000, valid: false)]),
      );
      expect(m.axes[ReportAxis.accuracy], closeTo(6 / 7, 1e-9));
    });

    test('depth uses the game grades: excellent is full, good is 10 of 15', () {
      // Push-up pass depth 1.1: excellent from 1.76, good below it.
      final m = ReportMetrics.of(
        report([rep(1000, depth: 1.8), rep(2000, depth: 1.2)]),
      );
      expect(m.axes[ReportAxis.depth], closeTo((1 + 10 / 15) / 2, 1e-9));
      final squat = ReportMetrics.of(
        report([rep(1000, depth: 1.2)], exercise: ExerciseType.squat),
      );
      // Squat pass depth 0.75: 1.2 is excellent (1.6 x 0.75 = 1.2).
      expect(squat.axes[ReportAxis.depth], 1.0);
    });

    test('late hold is the second half against the first, at most 1', () {
      final fading = ReportMetrics.of(
        report([...counted(10, untilMs: 15000), ...counted(8, fromMs: 15000)]),
      );
      expect(fading.axes[ReportAxis.lateHold], closeTo(0.8, 1e-9));
      final rising = ReportMetrics.of(
        report([...counted(5, untilMs: 15000), ...counted(9, fromMs: 15000)]),
      );
      expect(rising.axes[ReportAxis.lateHold], 1.0);
    });

    test('balance: even arms 1, one arm deeper 0.5, unseen or a squat left '
        'out', () {
      expect(
        ReportMetrics.of(report(counted(4), samples: elbows(5)))
            .axes[ReportAxis.balance],
        1.0,
      );
      expect(
        ReportMetrics.of(report(counted(4), samples: elbows(30)))
            .axes[ReportAxis.balance],
        0.5,
      );
      expect(
        ReportMetrics.of(report(counted(4))).axes
            .containsKey(ReportAxis.balance),
        isFalse,
      );
      expect(
        ReportMetrics.of(
          report(counted(4), samples: elbows(5), exercise: ExerciseType.squat),
        ).axes.containsKey(ReportAxis.balance),
        isFalse,
      );
    });

    test(
      'tempo: a controlled descent is 1, a drop is 0, between is linear',
      () {
        double tempo(int ms) =>
            ReportMetrics.of(report([rep(1000, depth: 2, descentMs: ms)]))
                .axes[ReportAxis.tempo]!;
        expect(tempo(800), 1.0);
        expect(tempo(600), 1.0);
        expect(tempo(200), 0.0);
        expect(tempo(425), closeTo(0.5, 1e-9));
      },
    );

    test('a battle with no reps measures no axis and has no score', () {
      final m = ReportMetrics.of(report(const []));
      expect(m.axes, isEmpty);
      expect(m.score, isNull);
      expect(m.statusOf(ReportAxis.depth), isNull);
    });
  });

  group('the form score', () {
    test('is the weighted mean of the axes, out of 100', () {
      expect(
        ReportMetrics.scoreOf({
          ReportAxis.accuracy: 1,
          ReportAxis.depth: 1,
          ReportAxis.lateHold: 1,
          ReportAxis.balance: 1,
          ReportAxis.tempo: 1,
        }),
        100,
      );
      expect(
        ReportMetrics.scoreOf({
          ReportAxis.accuracy: 0.5,
          ReportAxis.depth: 1,
          ReportAxis.lateHold: 0,
          ReportAxis.balance: 1,
          ReportAxis.tempo: 1,
        }),
        // 0.3 x 0.5 + 0.25 + 0 + 0.15 + 0.1 = 0.65
        65,
      );
    });

    test('an axis that was not measured gives its weight to the others', () {
      expect(
        ReportMetrics.scoreOf({ReportAxis.accuracy: 1, ReportAxis.depth: 0}),
        // 0.3 / 0.55
        55,
      );
    });

    test('the weights add up to one', () {
      expect(
        ReportAxis.values.fold<double>(0, (a, b) => a + b.weight),
        closeTo(1, 1e-9),
      );
    });

    test('the status of an axis: 0.8 and up 우수, 0.5 and up 표준, else 부족', () {
      expect(ReportStatus.of(0.8), ReportStatus.high);
      expect(ReportStatus.of(0.79), ReportStatus.standard);
      expect(ReportStatus.of(0.5), ReportStatus.standard);
      expect(ReportStatus.of(0.49), ReportStatus.low);
      expect(ReportStatus.high.label, '우수');
    });
  });

  group('estimates', () {
    test('calories and lifted weight use the given body weight', () {
      final m = ReportMetrics.of(
        report([...counted(17), rep(30000, depth: 2)]),
        weightKg: 80,
      );
      // 8.0 x 3.5 x 80 / 200 x 0.5 min, the last rep at 30 s
      expect(m.activeTime, const Duration(seconds: 30));
      expect(m.kcal, closeTo(5.6, 1e-9));
      expect(m.liftedKg, closeTo(18 * 80 * 0.64, 1e-9));
      expect(m.weightKg, 80);
      expect(m.weightAssumed, isFalse);
    });

    test('without a body weight they use 65 kg and say it is assumed', () {
      final m = ReportMetrics.of(report([...counted(17), rep(30000)]));
      expect(m.kcal, closeTo(4.55, 1e-9));
      expect(m.liftedKg, closeTo(748.8, 1e-9));
      expect(m.weightAssumed, isTrue);
    });

    test('calories follow the time spent exercising: up to the last judged '
        'rep, none without a rep', () {
      final stoppedEarly = ReportMetrics.of(report(counted(6, untilMs: 10000)));
      final keptGoing = ReportMetrics.of(report(counted(6, untilMs: 20000)));
      // Last reps at 8.33 s and 16.67 s.
      expect(stoppedEarly.kcal, closeTo(9.1 * 8333 / 60000, 1e-9));
      expect(keptGoing.kcal, closeTo(9.1 * 16666 / 60000, 1e-9));
      expect(keptGoing.kcal, greaterThan(stoppedEarly.kcal));
      final idle = ReportMetrics.of(report(const []));
      expect(idle.activeTime, Duration.zero);
      expect(idle.kcal, 0);
      // A rep closing after the bell is not counted past the round.
      expect(
        ReportMetrics.of(report([rep(31500)])).activeTime,
        const Duration(seconds: 30),
      );
    });

    test('a squat lifts a larger share of the body', () {
      final m = ReportMetrics.of(
        report(counted(10), exercise: ExerciseType.squat),
      );
      expect(m.liftedKg, closeTo(10 * 65 * 0.85, 1e-9));
    });
  });

  group('endurance against recent battles', () {
    test('is counted reps against the mean of up to five earlier battles of '
        'the same exercise, as 100', () {
      final earlier = [
        for (var i = 0; i < 7; i++)
          report(counted(i < 5 ? 16 : 2), endedMinute: 9 - i),
      ];
      final m = ReportMetrics.of(report(counted(18)), earlier: earlier);
      expect(m.enduranceIndex, 113);
    });

    test(
      'other exercises, later battles and the battle itself do not count',
      () {
        final earlier = [
          report(counted(18), endedMinute: 10),
          report(counted(30), endedMinute: 20),
          report(counted(4), endedMinute: 5, exercise: ExerciseType.squat),
          report(counted(9), endedMinute: 1),
        ];
        final m = ReportMetrics.of(report(counted(18)), earlier: earlier);
        expect(m.enduranceIndex, 200);
      },
    );

    test('is absent without earlier battles or when they counted nothing', () {
      expect(ReportMetrics.of(report(counted(18))).enduranceIndex, isNull);
      expect(
        ReportMetrics.of(
          report(counted(18)),
          earlier: [report(const [], endedMinute: 1)],
        ).enduranceIndex,
        isNull,
      );
    });
  });

  group('pace over the thirds of the round', () {
    test('splits counted and rejected reps into thirds', () {
      final m = ReportMetrics.of(
        report([
          ...counted(7, untilMs: 10000),
          ...counted(6, fromMs: 10000, untilMs: 20000),
          rep(15000, valid: false),
          ...counted(5, fromMs: 20000),
          rep(25000, valid: false),
          rep(29999, valid: false),
        ]),
      );
      expect(m.splitValid, [7, 6, 5]);
      expect(m.splitInvalid, [0, 1, 2]);
      expect(m.validReps, 18);
      expect(m.pace, ReportPace.early);
      expect(m.pace.label, '초반 집중형');
    });

    test('early, steady and late', () {
      expect(ReportMetrics.paceOf([7, 6, 5]), ReportPace.early);
      expect(ReportMetrics.paceOf([6, 5, 5]), ReportPace.steady);
      expect(ReportMetrics.paceOf([5, 6, 6]), ReportPace.late);
      expect(ReportMetrics.paceOf([0, 0, 0]), ReportPace.steady);
    });

    test('a rep exactly at the round end falls in the last third', () {
      final m = ReportMetrics.of(report([rep(30000, depth: 2)]));
      expect(m.splitValid, [0, 0, 1]);
    });
  });

  group('history against recent battles', () {
    test('without an earlier battle there is nothing to compare, and the trend '
        'is the battle alone', () {
      final h = ReportHistory.of(report(counted(18)), const []);
      expect(h.hasHistory, isFalse);
      expect(h.meanScore, isNull);
      expect(h.bestValidReps, isNull);
      expect(h.trend.single.validReps, 18);
      expect(h.trend.single.score, isNotNull);
    });

    test('means use the five latest earlier battles of the exercise; the best '
        'uses every earlier one', () {
      final kept = [
        for (var i = 0; i < 8; i++)
          report(counted(i == 7 ? 25 : 10 + i), endedMinute: 9 - i),
        report(counted(40), endedMinute: 3, exercise: ExerciseType.squat),
        report(counted(50), endedMinute: 30),
      ];
      final h = ReportHistory.of(report(counted(18)), kept);
      expect(h.recentCount, 5);
      // Latest five: minutes 9..5 → 10, 11, 12, 13, 14 reps.
      expect(h.meanValidReps, 12);
      expect(h.bestValidReps, 25);
      final kcal = [for (var i = 0; i < 5; i++) ReportMetrics.of(kept[i]).kcal];
      expect(h.meanKcal, closeTo(kcal.reduce((a, b) => a + b) / 5, 1e-9));
      expect(h.meanLiftedKg, closeTo(12 * 65 * 0.64, 1e-9));
      expect(h.meanScore, isNotNull);
      expect(h.meanAxes[ReportAxis.accuracy], 1.0);
    });

    test(
      'the trend is up to seven battles, oldest first, ending with this one',
      () {
        final kept = [
          for (var i = 0; i < 9; i++)
            report(counted(10 + i), endedMinute: 9 - i),
        ];
        final h = ReportHistory.of(report(counted(30)), kept);
        expect(h.trend, hasLength(7));
        expect(h.trend.map((p) => p.validReps), [15, 14, 13, 12, 11, 10, 30]);
        expect(h.trend.last.endedAt, DateTime(2026, 11, 23, 14, 10));
      },
    );

    test(
      'earlier battles are taken newest first whatever order they come in',
      () {
        final kept = [
          report(counted(4), endedMinute: 1),
          report(counted(20), endedMinute: 9),
        ];
        expect(
          ReportMetrics.earlierOf(
            report(counted(1)),
            kept,
          ).map((r) => r.validReps),
          [20, 4],
        );
      },
    );
  });

  group('comparison on the report', () {
    test('the bar: the mean in the middle, 10 % off at the band edge', () {
      expect(ReportComparison.barShare(16, 16), 0.5);
      expect(ReportComparison.barShare(17.6, 16), closeTo(2 / 3, 1e-9));
      expect(ReportComparison.barShare(14.4, 16), closeTo(1 / 3, 1e-9));
      expect(ReportComparison.barShare(100, 16), 1.0);
      expect(ReportComparison.barShare(0, 16), 0.04);
      expect(ReportComparison.barShare(5, null), 0.5);
    });

    test('highlights: a clean first third, above the mean, the best within '
        'reach', () {
      final shown = report([
        ...counted(7, untilMs: 10000),
        ...counted(6, fromMs: 10000, untilMs: 20000),
        ...counted(5, fromMs: 20000),
      ]);
      final kept = [
        report(counted(16), endedMinute: 9),
        report(counted(19), endedMinute: 8),
        report(counted(13), endedMinute: 7),
      ];
      final h = ReportHistory.of(shown, kept);
      final lines = h.highlights(ReportMetrics.of(shown, earlier: kept));
      expect(lines.map((l) => l.text), [
        '첫 10초 무효 없이 7회',
        '최근 평균보다 2회 더',
        '개인 최고까지 2회',
      ]);
      expect(lines.map((l) => l.achieved), [true, true, false]);
    });

    test('a new best, and no highlight for a rejected rep up front or no '
        'history', () {
      final shown = report([rep(500, valid: false), ...counted(20)]);
      final h = ReportHistory.of(shown, [report(counted(18), endedMinute: 1)]);
      final lines = h.highlights(ReportMetrics.of(shown));
      expect(lines.map((l) => l.text), ['최근 평균보다 2회 더', '개인 최고 갱신']);
      expect(ReportHistory.none.highlights(ReportMetrics.of(shown)), isEmpty);
    });

    test('the score and axis changes are against the recent mean, none '
        'without one', () {
      final shown = report([...counted(6), rep(29000, valid: false)]);
      final kept = [
        report([...counted(4), rep(29000, valid: false)], endedMinute: 9),
      ];
      final h = ReportHistory.of(shown, kept);
      final m = ReportMetrics.of(shown, earlier: kept);
      expect(h.scoreChange(m), closeTo(m.score! - h.meanScore!, 1e-9));
      // Accuracy 6 of 7 against 4 of 5: 86 - 80.
      expect(h.axisChange(m, ReportAxis.accuracy), 6);
      // No arms seen in either battle.
      expect(h.axisChange(m, ReportAxis.balance), isNull);
      expect(ReportHistory.none.scoreChange(m), isNull);
      expect(ReportHistory.none.axisChange(m, ReportAxis.accuracy), isNull);
    });

    test('운동 분석 rows: change and bar only with a mean, endurance only with '
        'earlier battles', () {
      final shown = report([...counted(17), rep(30000)]);
      final alone = ReportHistory.none.rowsOf(ReportMetrics.of(shown));
      expect(alone.map((r) => r.kind), [
        ReportRowKind.validReps,
        ReportRowKind.kcal,
        ReportRowKind.liftedKg,
      ]);
      expect(alone.every((r) => r.change == null && r.bar == null), isTrue);
      expect(alone.first.value, 18);

      final kept = [report(counted(12), endedMinute: 9)];
      final m = ReportMetrics.of(shown, earlier: kept);
      final rows = ReportHistory.of(shown, kept).rowsOf(m);
      expect(rows.map((r) => r.kind), [...ReportRowKind.values]);
      expect(rows[0].change, 6);
      expect(rows[0].bar, 1.0);
      expect(
        rows[1].change,
        closeTo(m.kcal - ReportMetrics.of(kept[0]).kcal, 1e-9),
      );
      expect(rows[2].change, closeTo(6 * 65 * 0.64, 1e-9));
      expect(rows[3].value, 150);
      expect(rows[3].change, 50);
    });
  });

  group('a round cut short by a KO', () {
    final ko = Duration(seconds: 17);

    test('is compared only with battles of the same length; the endurance '
        'index compares every round by reps per second', () {
      final shown = report(counted(10, untilMs: 17000), round: ko);
      final kept = [
        report(counted(20), endedMinute: 9),
        report(counted(8, untilMs: 17000), round: ko, endedMinute: 8),
      ];
      expect(ReportMetrics.earlierOf(shown, kept).map((r) => r.validReps), [8]);
      // 10/17 per second against the mean of 20/30 and 8/17.
      expect(
        ReportMetrics.of(shown, earlier: kept).enduranceIndex,
        ((10 / 17) / ((20 / 30 + 8 / 17) / 2) * 100).round(),
      );
      final h = ReportHistory.of(shown, kept);
      expect(h.meanValidReps, 8);
      expect(h.bestValidReps, 8);
      expect(h.trend.map((p) => p.validReps), [8, 10]);
    });

    test('with no other KO round of that length the counts have nothing to '
        'compare, but the endurance index has the full round (PR #100, '
        'user 2026-11-26)', () {
      final shown = report(counted(10, untilMs: 17000), round: ko);
      final kept = [report(counted(20), endedMinute: 9)];
      expect(ReportHistory.of(shown, kept).hasHistory, isFalse);
      expect(
        ReportMetrics.of(shown, earlier: kept).enduranceIndex,
        ((10 / 17) / (20 / 30) * 100).round(),
      );
    });

    test('the rate of a round, none for a round of no length', () {
      expect(ReportMetrics.rateOf(report(counted(15))), 0.5);
      expect(
        ReportMetrics.rateOf(report(counted(3), round: Duration.zero)),
        isNull,
      );
    });

    test('is read in its own thirds, labelled by their real seconds', () {
      final shown = report([
        rep(2000),
        rep(5000),
        rep(7000),
        rep(12000, valid: false),
        rep(16000),
      ], round: ko);
      final m = ReportMetrics.of(shown);
      expect(m.splitBounds, [0, 6, 11, 17]);
      expect(m.splitValid, [2, 1, 1]);
      expect(m.splitInvalid, [0, 0, 1]);
      expect(ReportHistory.none.highlights(m).map((l) => l.text), [
        '첫 6초 무효 없이 2회',
      ]);
    });

    test('a full round is cut at 10 and 20 s', () {
      expect(ReportMetrics.of(report(const [])).splitBounds, [0, 10, 20, 30]);
    });

    test('reps are counted in the thirds the chart names (PR #100 Codex '
        'review): 5.8 s of a 17 s round is in 0–6초, 6.0 s in 6–11초', () {
      final m = ReportMetrics.of(
        report([rep(5800), rep(6000), rep(10900), rep(11000)], round: ko),
      );
      expect(m.splitBounds, [0, 6, 11, 17]);
      expect(m.splitValid, [1, 2, 1]);
      expect(ReportMetrics.splitOf(const Duration(seconds: 17), ko), 2);
      expect(
        ReportMetrics.splitOf(const Duration(seconds: 1), Duration.zero),
        0,
      );
    });
  });

  group('the evidence', () {
    test('reject reasons are counted, most often first', () {
      final m = ReportMetrics.of(
        report([
          rep(1000, valid: false, reason: RejectReason.insufficientDepth),
          rep(2000, valid: false, reason: RejectReason.incompleteExtension),
          rep(3000, valid: false, reason: RejectReason.incompleteExtension),
          rep(4000),
        ]),
      );
      expect(m.rejectCounts, [
        (RejectReason.incompleteExtension, 2),
        (RejectReason.insufficientDepth, 1),
      ]);
      expect(m.invalidReps, 3);
      expect(ReportMetrics.of(report(counted(3))).rejectCounts, isEmpty);
    });

    test('the depth axis uses the depth each judge itself passes', () {
      expect(
        ReportMetrics.passDepth(ExerciseType.pushUp),
        const RepJudgeConfig().bottomDepth,
      );
      expect(
        ReportMetrics.passDepth(ExerciseType.squat),
        SquatRepJudge().passDepth,
      );
    });
  });
}
