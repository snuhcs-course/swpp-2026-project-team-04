import '../../models/battle_rules.dart';
import '../../models/exercise_type.dart';
import '../../models/form_report.dart';
import '../../models/rep_event.dart';
import '../game/rep_grade.dart';
import '../pose/rep_judge.dart';
import '../pose/squat_rep_judge.dart';
import 'form_analyzer.dart';

/// The five parts of the form score on the post-game report (P14), in the
/// order the pentagon draws them, clockwise from the top.
enum ReportAxis {
  depth('깊이'),
  accuracy('정확도'),
  tempo('템포'),
  lateHold('후반 유지력'),
  balance('좌우 균형');

  const ReportAxis(this.label);

  /// The name the report shows.
  final String label;

  /// The axis's share of the form score when every axis was measured.
  double get weight => switch (this) {
    accuracy => 0.30,
    depth => 0.25,
    lateHold => 0.20,
    balance => 0.15,
    tempo => 0.10,
  };
}

/// Where an axis value falls, as the report's status cards say it.
enum ReportStatus {
  low('부족'),
  standard('표준'),
  high('우수');

  const ReportStatus(this.label);

  final String label;

  /// 0.8 and up is 우수, 0.5 and up 표준, below that 부족.
  static ReportStatus of(double value) => value >= 0.8
      ? high
      : value >= 0.5
      ? standard
      : low;
}

/// How the counted reps were spread over the round.
enum ReportPace {
  early('초반 집중형'),
  steady('꾸준형'),
  late('후반 강세형');

  const ReportPace(this.label);

  final String label;
}

/// Everything the post-game report measures of one battle (P14): the form
/// score from five axes, the estimated calories and lifted weight, and how
/// the reps were spread. Comparisons with recent battles are by counts
/// (user, 2026-11-26: no endurance index).
///
/// The numbers come from the reps the judge already kept; nothing here
/// judges a rep again. Axes that could not be measured are left out of the
/// score, and the others share their weight.
class ReportMetrics {
  const ReportMetrics({
    required this.exercise,
    required this.roundLength,
    required this.axes,
    required this.score,
    required this.activeTime,
    required this.kcal,
    required this.liftedKg,
    required this.weightKg,
    required this.weightAssumed,
    required this.splitValid,
    required this.splitInvalid,
    required this.rejectCounts,
    required this.pace,
  });

  /// Body weight used when the user gave none.
  static const defaultWeightKg = 65.0;

  /// MET of vigorous calisthenics (push-ups, squats): the calorie estimate.
  static const met = 8.0;

  /// The share of body weight one counted rep lifts: about 64 % in a
  /// push-up, and about 85 % in a bodyweight squat (the body above the
  /// knees). Estimates, so the report calls the result 추정.
  static double liftShare(ExerciseType exercise) => switch (exercise) {
    ExerciseType.pushUp => 0.64,
    ExerciseType.squat => 0.85,
  };

  /// The depth a counted rep must reach, read from the judge of [exercise]
  /// so the depth axis follows it when the judge is tuned.
  static double passDepth(ExerciseType exercise) => switch (exercise) {
    ExerciseType.pushUp => const RepJudgeConfig().bottomDepth,
    ExerciseType.squat => SquatRepJudge().passDepth,
  };

  /// A mean descent of this or longer is a controlled rep (tempo 1).
  static const steadyDescent = Duration(milliseconds: 600);

  /// A mean descent of this or shorter is a drop, not a rep (tempo 0).
  static const dropDescent = Duration(milliseconds: 250);

  /// How many earlier battles of the same exercise the means compare with.
  static const recentCount = 5;

  /// The round is cut into this many equal parts for the pace.
  static const splits = 3;

  final ExerciseType exercise;

  /// The round's length: the whole battle, or up to a KO.
  final Duration roundLength;

  /// Each measured axis from 0 to 1; an axis that could not be measured is
  /// absent.
  final Map<ReportAxis, double> axes;

  /// The form score from 0 to 100; null when no axis was measured.
  final int? score;

  /// From the start of the round to the last judged rep: the time the user
  /// was exercising, which the calorie estimate uses. Zero without a rep.
  final Duration activeTime;

  final double kcal;
  final double liftedKg;

  /// The body weight [kcal] and [liftedKg] use, and whether it is the
  /// [defaultWeightKg] because the user gave none.
  final double weightKg;
  final bool weightAssumed;

  /// Counted and rejected reps in each third of the round.
  final List<int> splitValid;
  final List<int> splitInvalid;

  /// Each reason a rep was turned down and how often, most often first.
  final List<(RejectReason, int)> rejectCounts;

  final ReportPace pace;

  int get validReps => splitValid.fold(0, (a, b) => a + b);
  int get invalidReps => splitInvalid.fold(0, (a, b) => a + b);

  ReportStatus? statusOf(ReportAxis axis) {
    final value = axes[axis];
    return value == null ? null : ReportStatus.of(value);
  }

  /// The whole seconds where the thirds of the round begin and end, e.g.
  /// 0, 10, 20, 30, or 0, 6, 11, 17 for a 17 s round cut short by a KO.
  List<int> get splitBounds => boundsOf(roundLength);

  /// [splitBounds] of a round of [roundLength].
  static List<int> boundsOf(Duration roundLength) => [
    for (var i = 0; i <= splits; i++)
      (roundLength.inMilliseconds * i / splits / 1000).round(),
  ];

  /// The third a rep at [at] counts in: by the whole-second bounds the
  /// chart names, so a rep at 5.8 s of a 17 s round is in 0–6초. A rep at
  /// or past the end is in the last third.
  static int splitOf(Duration at, Duration roundLength) {
    if (roundLength <= Duration.zero) return 0;
    final bounds = boundsOf(roundLength);
    for (var i = 1; i < splits; i++) {
      if (at.inMilliseconds < bounds[i] * 1000) return i - 1;
    }
    return splits - 1;
  }

  /// Measures [report]. [weightKg] is the user's body weight, null when not
  /// known.
  factory ReportMetrics.of(
    FormReport report, {
    double? weightKg,
    FormAnalyzer analyzer = const FormAnalyzer(),
    BattleRules rules = battleRules,
  }) {
    final weight = weightKg ?? defaultWeightKg;
    final axes = axesOf(report, analyzer: analyzer, rules: rules);
    final valid = report.validReps;

    final splitValid = List.filled(splits, 0);
    final splitInvalid = List.filled(splits, 0);
    final reasons = <RejectReason, int>{};
    var last = Duration.zero;
    for (final rep in report.reps) {
      final i = splitOf(rep.at, report.roundLength);
      if (rep.valid) {
        splitValid[i]++;
      } else {
        splitInvalid[i]++;
        final reason = rep.reason;
        if (reason != null) reasons[reason] = (reasons[reason] ?? 0) + 1;
      }
      if (rep.at > last) last = rep.at;
    }
    final active = last > report.roundLength ? report.roundLength : last;

    return ReportMetrics(
      exercise: report.exercise,
      roundLength: report.roundLength,
      axes: axes,
      score: scoreOf(axes),
      activeTime: active,
      kcal: met * 3.5 * weight / 200 * active.inMilliseconds / 60000,
      liftedKg: valid * weight * liftShare(report.exercise),
      weightKg: weight,
      weightAssumed: weightKg == null,
      splitValid: List.unmodifiable(splitValid),
      splitInvalid: List.unmodifiable(splitInvalid),
      rejectCounts: List.unmodifiable(
        reasons.entries.map((e) => (e.key, e.value)).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2)),
      ),
      pace: paceOf(splitValid),
    );
  }

  /// The measured axes of [report], each from 0 to 1.
  static Map<ReportAxis, double> axesOf(
    FormReport report, {
    FormAnalyzer analyzer = const FormAnalyzer(),
    BattleRules rules = battleRules,
  }) {
    final axes = <ReportAxis, double>{};
    final judged = report.reps.length;
    final valid = report.validReps;
    if (judged > 0) axes[ReportAxis.accuracy] = valid / judged;

    if (valid > 0) {
      // The game's own grades: an excellent rep is full depth, a good one
      // earns 10 of 15 points.
      final grades = GameGradeCounts.ofReps(
        report.reps.where((r) => r.valid),
        passDepth: passDepth(report.exercise),
        rules: rules,
      );
      final goodShare = rules.goodPoints / rules.excellentPoints;
      axes[ReportAxis.depth] =
          (grades.excellent + goodShare * grades.good) / valid;
    }

    final half = report.roundLength ~/ 2;
    final first = report.reps.where((r) => r.valid && r.at < half).length;
    final second = report.reps.where((r) => r.valid && r.at >= half).length;
    if (first > 0) axes[ReportAxis.lateHold] = (second / first).clamp(0.0, 1.0);

    if (report.exercise == ExerciseType.pushUp) {
      final balance = switch (analyzer.armBalance(report)) {
        ArmBalance.even => 1.0,
        ArmBalance.leftDeeper || ArmBalance.rightDeeper => 0.5,
        ArmBalance.unknown => null,
      };
      if (balance != null) axes[ReportAxis.balance] = balance;
    }

    final descents = [
      for (final r in report.reps)
        if (r.valid && r.descent != null) r.descent!.inMicroseconds,
    ];
    if (descents.isNotEmpty) {
      final mean = descents.reduce((a, b) => a + b) / descents.length;
      final low = dropDescent.inMicroseconds;
      final high = steadyDescent.inMicroseconds;
      axes[ReportAxis.tempo] = ((mean - low) / (high - low)).clamp(0.0, 1.0);
    }
    return axes;
  }

  /// The weighted mean of the measured [axes] as 0 to 100; null when none.
  static int? scoreOf(Map<ReportAxis, double> axes) {
    if (axes.isEmpty) return null;
    var weights = 0.0, sum = 0.0;
    for (final e in axes.entries) {
      weights += e.key.weight;
      sum += e.key.weight * e.value;
    }
    return (sum / weights * 100).round();
  }

  /// Earlier battles that [report] is compared with, newest first, from
  /// [kept] (the phone's reports in any order): the same exercise, ended
  /// before [report], of any round length, so a round cut short by a KO is
  /// compared too (user, 2026-11-26).
  static List<FormReport> earlierOf(FormReport report, List<FormReport> kept) {
    final earlier = [
      for (final r in kept)
        if (r.exercise == report.exercise && r.endedAt.isBefore(report.endedAt))
          r,
    ]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return earlier;
  }

  /// Late when the last third counted at least one more than the first,
  /// early when it counted at least two fewer, steady otherwise.
  static ReportPace paceOf(List<int> splitValid) {
    final first = splitValid.first, last = splitValid.last;
    if (last >= first + 1) return ReportPace.late;
    if (first >= last + 2) return ReportPace.early;
    return ReportPace.steady;
  }
}

/// One battle in the report's trend: when it ended, its counted reps and
/// its form score.
class ReportTrendPoint {
  const ReportTrendPoint({
    required this.endedAt,
    required this.validReps,
    this.score,
    this.roundLength = Duration.zero,
  });

  final DateTime endedAt;
  final int validReps;
  final int? score;

  /// How long the round lasted: rounds of any length are compared, so the
  /// trend shows it beside the counts.
  final Duration roundLength;
}

/// The rows of the report's 운동 분석.
enum ReportRowKind { validReps, kcal, liftedKg }

/// One row of 운동 분석: its value, the change from the recent mean and the
/// share of the 평균 이하 · 평균 · 평균 이상 bar; no change and no bar without
/// a mean to compare with.
class ReportRow {
  const ReportRow(this.kind, this.value, {this.change, this.bar});

  final ReportRowKind kind;
  final double value;
  final double? change;
  final double? bar;
}

/// The report's battle against the user's recent battles of the same
/// exercise kept on the phone, of any round length (P14): the means the
/// changes and the dashed average use, the personal best, and the last
/// battles for the trend.
class ReportHistory {
  const ReportHistory({
    required this.recentCount,
    required this.trend,
    this.meanScore,
    this.meanAxes = const {},
    this.meanValidReps,
    this.meanKcal,
    this.meanLiftedKg,
    this.bestValidReps,
  });

  /// No earlier battle: nothing to compare with.
  static const none = ReportHistory(recentCount: 0, trend: []);

  /// How many battles the trend shows, the report's own included.
  static const trendLength = 7;

  /// Compares [report] with [kept] (the phone's reports). The means use the
  /// [ReportMetrics.recentCount] latest comparable battles
  /// ([ReportMetrics.earlierOf]); the best uses every comparable one kept.
  factory ReportHistory.of(
    FormReport report,
    List<FormReport> kept, {
    double? weightKg,
    FormAnalyzer analyzer = const FormAnalyzer(),
    BattleRules rules = battleRules,
  }) {
    final earlier = ReportMetrics.earlierOf(report, kept);
    if (earlier.isEmpty) {
      return ReportHistory(
        recentCount: 0,
        trend: [
          ReportTrendPoint(
            endedAt: report.endedAt,
            validReps: report.validReps,
            roundLength: report.roundLength,
            score: ReportMetrics.scoreOf(
              ReportMetrics.axesOf(report, analyzer: analyzer, rules: rules),
            ),
          ),
        ],
      );
    }
    final recent = earlier.take(ReportMetrics.recentCount).toList();
    final metrics = [
      for (final r in recent)
        ReportMetrics.of(
          r,
          weightKg: weightKg,
          analyzer: analyzer,
          rules: rules,
        ),
    ];
    double mean(Iterable<double> values) =>
        values.reduce((a, b) => a + b) / values.length;

    final scores = [
      for (final m in metrics)
        if (m.score != null) m.score!,
    ];
    final meanAxes = <ReportAxis, double>{};
    for (final axis in ReportAxis.values) {
      final values = [
        for (final m in metrics)
          if (m.axes[axis] != null) m.axes[axis]!,
      ];
      if (values.isNotEmpty) meanAxes[axis] = mean(values);
    }

    final trendReports = [
      ...earlier.take(trendLength - 1).toList().reversed,
      report,
    ];
    return ReportHistory(
      recentCount: recent.length,
      meanScore: scores.isEmpty ? null : mean(scores.map((s) => s.toDouble())),
      meanAxes: meanAxes,
      meanValidReps: mean(recent.map((r) => r.validReps.toDouble())),
      meanKcal: mean(metrics.map((m) => m.kcal)),
      meanLiftedKg: mean(metrics.map((m) => m.liftedKg)),
      bestValidReps: earlier
          .map((r) => r.validReps)
          .reduce((a, b) => a > b ? a : b),
      trend: [
        for (final r in trendReports)
          ReportTrendPoint(
            endedAt: r.endedAt,
            validReps: r.validReps,
            roundLength: r.roundLength,
            score: ReportMetrics.scoreOf(
              ReportMetrics.axesOf(r, analyzer: analyzer, rules: rules),
            ),
          ),
      ],
    );
  }

  /// How many earlier battles the means use (0 to [ReportMetrics.recentCount]).
  final int recentCount;

  final double? meanScore;
  final Map<ReportAxis, double> meanAxes;
  final double? meanValidReps;
  final double? meanKcal;
  final double? meanLiftedKg;

  /// Most counted reps in one comparable earlier battle; null without one.
  final int? bestValidReps;

  /// Up to [trendLength] battles, oldest first, ending with the report's own.
  final List<ReportTrendPoint> trend;

  bool get hasHistory => recentCount > 0;
}

/// One line of the report's 이번 경기 성과: done ([achieved]) or the next
/// one to reach.
class ReportHighlight {
  const ReportHighlight(this.text, {required this.achieved});

  final String text;
  final bool achieved;
}

/// What the report draws against the recent battles: the changes, where a
/// value sits on the 평균 이하 · 평균 · 평균 이상 bar, and the highlights.
extension ReportComparison on ReportHistory {
  /// The share of the bar up to [value]: the middle third is the average
  /// band, a value at the mean sits in its middle, 10 % off the mean reaches
  /// its edge. Half the bar without a mean.
  static double barShare(double value, double? mean) {
    if (mean == null || mean <= 0) return 0.5;
    final ratio = value / mean;
    return (0.5 + (ratio - 1) / 0.1 / 6).clamp(0.04, 1.0);
  }

  /// The form score's change from the recent mean; null without one.
  double? scoreChange(ReportMetrics metrics) {
    final score = metrics.score, mean = meanScore;
    return score == null || mean == null ? null : score - mean;
  }

  /// [axis]'s change from the recent mean in points of 100; null when either
  /// side was not measured.
  int? axisChange(ReportMetrics metrics, ReportAxis axis) {
    final value = metrics.axes[axis], mean = meanAxes[axis];
    return value == null || mean == null
        ? null
        : ((value - mean) * 100).round();
  }

  /// The 운동 분석 rows of [metrics]: the counted reps, the estimated
  /// calories and lifted weight.
  List<ReportRow> rowsOf(ReportMetrics metrics) {
    ReportRow row(ReportRowKind kind, double value, double? mean) => ReportRow(
      kind,
      value,
      change: mean == null ? null : value - mean,
      bar: mean == null ? null : barShare(value, mean),
    );
    return [
      row(ReportRowKind.validReps, metrics.validReps.toDouble(), meanValidReps),
      row(ReportRowKind.kcal, metrics.kcal, meanKcal),
      row(ReportRowKind.liftedKg, metrics.liftedKg, meanLiftedKg),
    ];
  }

  /// The highlights of [metrics]: a clean first third, more than the recent
  /// mean, and a new or nearly reached personal best.
  List<ReportHighlight> highlights(ReportMetrics metrics) {
    final lines = <ReportHighlight>[];
    final third = metrics.splitBounds[1];
    final first = metrics.splitValid.first;
    if (first > 0 && metrics.splitInvalid.first == 0) {
      lines.add(ReportHighlight('첫 $third초 무효 없이 $first회', achieved: true));
    }
    final valid = metrics.validReps;
    final mean = meanValidReps;
    if (mean != null && valid > mean) {
      final more = (valid - mean).round();
      if (more > 0) {
        lines.add(ReportHighlight('최근 평균보다 $more회 더', achieved: true));
      }
    }
    final best = bestValidReps;
    if (best != null) {
      lines.add(
        valid > best
            ? const ReportHighlight('개인 최고 갱신', achieved: true)
            : ReportHighlight('개인 최고까지 ${best - valid + 1}회', achieved: false),
      );
    }
    return lines;
  }
}
