import 'dart:math' as math;

import '../../models/hold_record.dart';

/// How a hold report rates a part: as the post-game report's cards do.
enum HoldStatus {
  good('우수'),
  fair('표준'),
  poor('부족');

  const HoldStatus(this.label);

  final String label;
}

/// Everything the hold report (P13, design H-A) shows of one played hold,
/// from the numbers [HoldRecord] kept; nothing is judged again.
///
/// - **Keep rate:** the time held over the time from GO to the end.
/// - **Hold score (0–100):** the keep rate 70 %, the warnings 30 % (none
///   30, one 15, two 0).
/// - **Calories:** MET [met] × 3.5 × body weight ÷ 200 × minutes held; a
///   hold is moderate calisthenics, lighter than push-ups (8.0).
/// - No lifted weight: a hold does not move the body.
class HoldMetrics {
  const HoldMetrics({
    required this.record,
    required this.keepRate,
    required this.score,
    required this.kcal,
    required this.weightKg,
    required this.weightAssumed,
    required this.earlier,
    this.recentHeld,
    this.recentScore,
    this.recentKcal,
    this.best = false,
    this.commonWarning,
  });

  final HoldRecord record;

  /// 0 to 1.
  final double keepRate;

  /// 0 to 100.
  final int score;
  final double kcal;
  final double weightKg;

  /// Whether [weightKg] is [defaultWeightKg] because none was given.
  final bool weightAssumed;

  /// Earlier holds of the same pose, newest first, up to [trendCount] - 1.
  final List<HoldRecord> earlier;

  /// The means of up to [recentCount] earlier holds of the same pose; null
  /// without one.
  final double? recentHeld;
  final double? recentScore;
  final double? recentKcal;

  /// Whether no earlier hold of the pose was held as long; false for the
  /// first.
  final bool best;

  /// The most frequent warning over this hold and up to [recentCount] - 1
  /// earlier ones, with how many of them had it; null without warnings.
  final ({String words, int holds, int of})? commonWarning;

  /// MET of moderate calisthenics (a plank, a wall sit).
  static const met = 3.8;

  /// Body weight used when the user gave none.
  static const defaultWeightKg = 65.0;

  /// How many earlier holds the means compare with.
  static const recentCount = 5;

  /// How many holds 변화 shows, this one included.
  static const trendCount = 7;

  static const _keepShare = 0.7;
  static const _warningShare = 0.3;

  /// Measures [record] against the holds [kept] on the phone (any order;
  /// only earlier ones of the same pose count), on [weightKg].
  static HoldMetrics of(
    HoldRecord record, {
    double? weightKg,
    List<HoldRecord> kept = const [],
  }) {
    final weight = weightKg ?? defaultWeightKg;
    final earlier = [
      for (final r in kept)
        if (r.pose == record.pose && r.endedAt.isBefore(record.endedAt)) r,
    ]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final recent = earlier.take(recentCount).toList();
    double? mean(double Function(HoldRecord) of) => recent.isEmpty
        ? null
        : recent.fold(0.0, (sum, r) => sum + of(r)) / recent.length;
    final held = seconds(record.held);
    return HoldMetrics(
      record: record,
      keepRate: keepRateOf(record),
      score: scoreOf(record),
      kcal: kcalOf(record, weight),
      weightKg: weight,
      weightAssumed: weightKg == null,
      earlier: earlier.take(trendCount - 1).toList(),
      recentHeld: mean((r) => seconds(r.held)),
      recentScore: mean((r) => scoreOf(r).toDouble()),
      recentKcal: mean((r) => kcalOf(r, weight)),
      best: earlier.isNotEmpty && earlier.every((r) => seconds(r.held) < held),
      commonWarning: _common([record, ...recent.take(recentCount - 1)]),
    );
  }

  static double seconds(Duration d) => d.inMilliseconds / 1000;

  static double keepRateOf(HoldRecord r) {
    final elapsed = r.elapsed.inMilliseconds;
    if (elapsed <= 0) return r.held > Duration.zero ? 1 : 0;
    return math.min(1, r.held.inMilliseconds / elapsed);
  }

  /// The warnings' part of the score: none 1, one 0.5, two or more 0.
  static double warningPart(HoldRecord r) => switch (r.warnings.length) {
    0 => 1,
    1 => 0.5,
    _ => 0,
  };

  static int scoreOf(HoldRecord r) =>
      (100 * (_keepShare * keepRateOf(r) + _warningShare * warningPart(r)))
          .round();

  static double kcalOf(HoldRecord r, double weightKg) =>
      met * 3.5 * weightKg / 200 * r.held.inMilliseconds / 60000;

  static ({String words, int holds, int of})? _common(List<HoldRecord> holds) {
    final counts = <String, int>{};
    for (final h in holds) {
      for (final words in {for (final w in h.warnings) w.words}) {
        counts[words] = (counts[words] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    // Most holds first; this hold's own warning first on a tie.
    final own = [for (final w in holds.first.warnings) w.words];
    final words = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        if (byCount != 0) return byCount;
        final ia = own.indexOf(a), ib = own.indexOf(b);
        return (ia < 0 ? own.length : ia).compareTo(ib < 0 ? own.length : ib);
      });
    return (words: words.first, holds: counts[words.first]!, of: holds.length);
  }

  /// The keep rate's status: 90 % and up 우수, 70 % and up 표준.
  HoldStatus get keepStatus => keepRate >= 0.9
      ? HoldStatus.good
      : keepRate >= 0.7
      ? HoldStatus.fair
      : HoldStatus.poor;

  /// No warning 우수, one 표준, two 부족.
  HoldStatus get warningStatus => switch (record.warnings.length) {
    0 => HoldStatus.good,
    1 => HoldStatus.fair,
    _ => HoldStatus.poor,
  };

  /// Every star 우수, some 표준, none 부족.
  HoldStatus get goalStatus => record.stars >= record.starSeconds.length
      ? HoldStatus.good
      : record.stars > 0
      ? HoldStatus.fair
      : HoldStatus.poor;

  /// The seconds the last star asks for.
  int get goalSeconds =>
      record.starSeconds.isEmpty ? 0 : record.starSeconds.last;

  /// The seconds to the next star, and which star it is (1-based); null
  /// with every star.
  ({int star, double seconds})? get nextStar {
    final stars = record.stars;
    if (stars >= record.starSeconds.length) return null;
    return (
      star: stars + 1,
      seconds: math.max(0, record.starSeconds[stars] - seconds(record.held)),
    );
  }

  /// From GO to the first warning, or the whole hold without one.
  Duration get cleanStart =>
      record.warnings.isEmpty ? record.elapsed : record.warnings.first.at;

  /// This hold and the earlier ones of 변화, oldest first.
  List<HoldRecord> get trend => [...earlier.reversed, record];

  static const _ordinal = ['첫', '두', '세', '네', '다섯'];

  /// "세 번째 별": the star's words.
  static String starWords(int star) =>
      '${star <= _ordinal.length ? _ordinal[star - 1] : '$star'} 번째 별';

  /// The reached lines of 이번 기록 성과, in order.
  List<String> get highlights {
    final lines = <String>[];
    final clean = cleanStart.inSeconds;
    if (clean >= 5) {
      lines.add(record.warnings.isEmpty ? '끝까지 경고 없이' : '처음 $clean초 경고 없이');
    }
    final mean = recentHeld;
    final held = seconds(record.held);
    if (mean != null && held > mean) {
      lines.add('최근 평균보다 ${oneDecimal(held - mean)}초 더');
    }
    if (best) lines.add('개인 최고 기록');
    return lines;
  }

  /// The next goal in grey: the next star's seconds, or null with all.
  String? get nextGoal {
    final next = nextStar;
    if (next == null) return null;
    return '${starWords(next.star)}까지 ${oneDecimal(next.seconds)}초';
  }

  /// The coach's line: what broke the hold and the next star, or praise.
  String get coachLine {
    final next = nextStar;
    final warnings = record.warnings;
    if (warnings.isEmpty) {
      return next == null
          ? '경고 없이 모든 별을 받았어요. 다음 스테이지도 이 자세로 가요.'
          : '경고 없이 버텼어요. ${starWords(next.star)}은 '
                '${record.starSeconds[next.star - 1]}초예요.';
    }
    final first = warnings.first;
    final goal = next == null
        ? '다음엔 경고 없이 끝까지 가 봐요.'
        : '다음엔 그 순간을 넘겨 ${record.starSeconds[next.star - 1]}초 별을 '
              '노려 봐요.';
    return '${first.at.inSeconds}초쯤 "${first.words}" 경고가 나왔어요. $goal';
  }

  /// "5.4", or "5" when whole.
  static String oneDecimal(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }
}
