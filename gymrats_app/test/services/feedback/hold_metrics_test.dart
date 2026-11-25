import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/hold_record.dart';
import 'package:gymrats_app/services/feedback/hold_metrics.dart';

import '../../models/hold_record_test.dart' show holdRecord;

HoldRecord _earlier(int day, int heldMs, {HoldPose pose = HoldPose.plank}) =>
    holdRecord(
      endedAt: DateTime(2026, 11, day, 9),
      pose: pose,
      heldMs: heldMs,
      elapsedMs: heldMs,
      warnings: const [],
      pauses: const [],
      endedByWarnings: false,
    );

void main() {
  group('one hold (P13, design H-A)', () {
    final record = holdRecord();
    final metrics = HoldMetrics.of(record);

    test('keep rate: the time held over the time from GO', () {
      expect(metrics.keepRate, closeTo(24.6 / 26.7, 0.0001));
      expect(metrics.keepStatus, HoldStatus.good);
    });

    test('score: keep rate 70 %, warnings 30 % (two warnings: 0)', () {
      expect(metrics.score, (100 * 0.7 * 24.6 / 26.7).round());
      expect(
        HoldMetrics.scoreOf(
          holdRecord(warnings: const [], heldMs: 20000, elapsedMs: 20000),
        ),
        100,
      );
      expect(
        HoldMetrics.scoreOf(
          holdRecord(
            heldMs: 20000,
            elapsedMs: 20000,
            warnings: [record.warnings.first],
          ),
        ),
        85,
      );
    });

    test('calories: MET 3.8 on 65 kg by default, over the time held', () {
      expect(metrics.kcal, closeTo(3.8 * 3.5 * 65 / 200 * 24.6 / 60, 0.0001));
      expect(metrics.weightAssumed, isTrue);
      final weighed = HoldMetrics.of(record, weightKg: 80);
      expect(weighed.kcal, closeTo(3.8 * 3.5 * 80 / 200 * 24.6 / 60, 0.0001));
      expect(weighed.weightAssumed, isFalse);
    });

    test('statuses: two warnings 부족, two of three stars 표준', () {
      expect(metrics.warningStatus, HoldStatus.poor);
      expect(metrics.goalStatus, HoldStatus.fair);
      expect(metrics.goalSeconds, 30);
      expect(HoldMetrics.of(holdRecord(stars: 3)).goalStatus, HoldStatus.good);
      expect(HoldMetrics.of(holdRecord(stars: 0)).goalStatus, HoldStatus.poor);
    });

    test('the next star and the clean start', () {
      expect(metrics.nextStar!.star, 3);
      expect(metrics.nextStar!.seconds, closeTo(5.4, 0.0001));
      expect(metrics.nextGoal, '세 번째 별까지 5.4초');
      expect(metrics.cleanStart, const Duration(seconds: 12));
      expect(HoldMetrics.of(holdRecord(stars: 3)).nextStar, isNull);
    });

    test('without earlier holds: no means, no endurance, not a best', () {
      expect(metrics.recentHeld, isNull);
      expect(metrics.endurance, isNull);
      expect(metrics.best, isFalse);
      expect(metrics.trend, [record]);
      expect(metrics.highlights, ['처음 12초 경고 없이']);
    });

    test('the coach names the first warning and the next star', () {
      expect(
        metrics.coachLine,
        '12초쯤 "무릎 떼요" 경고가 나왔어요. 다음엔 그 순간을 넘겨 30초 별을 노려 봐요.',
      );
      expect(
        HoldMetrics.of(
          holdRecord(warnings: const [], stars: 3, pauses: const []),
        ).coachLine,
        '경고 없이 모든 별을 받았어요. 다음 스테이지도 이 자세로 가요.',
      );
      expect(
        HoldMetrics.of(
          holdRecord(warnings: const [], stars: 1, pauses: const []),
        ).coachLine,
        '경고 없이 버텼어요. 두 번째 별은 20초예요.',
      );
    });
  });

  group('against earlier holds', () {
    final record = holdRecord();
    final kept = [
      _earlier(25, 23000),
      _earlier(24, 20100),
      _earlier(23, 22300),
      _earlier(22, 17400),
      _earlier(21, 18000),
      _earlier(20, 15200),
      // Another pose and a later hold are left out.
      _earlier(25, 40000, pose: HoldPose.chair),
      _earlier(27, 40000),
      record,
    ];
    final metrics = HoldMetrics.of(record, kept: kept);

    test('means of the five latest earlier holds of the pose', () {
      const mean = (23.0 + 20.1 + 22.3 + 17.4 + 18.0) / 5;
      expect(metrics.recentHeld, closeTo(mean, 0.0001));
      expect(metrics.endurance, closeTo(24.6 / mean * 100, 0.0001));
      expect(metrics.recentScore, 100);
    });

    test('a best, above the mean; 변화 keeps seven, oldest first', () {
      expect(metrics.best, isTrue);
      expect(metrics.highlights, [
        '처음 12초 경고 없이',
        '최근 평균보다 ${HoldMetrics.oneDecimal(24.6 - 20.16)}초 더',
        '개인 최고 기록',
      ]);
      expect(metrics.trend.map((r) => r.held.inMilliseconds), [
        15200,
        18000,
        17400,
        22300,
        20100,
        23000,
        24600,
      ]);
    });

    test('the most frequent warning over this hold and four earlier', () {
      final warned = [
        for (var day = 21; day <= 25; day++)
          holdRecord(
            endedAt: DateTime(2026, 11, day, 9),
            warnings: [
              HoldRecordWarning(
                at: const Duration(seconds: 3),
                faultId: day.isEven ? 'plank.armBent' : 'plank.kneeDown',
                words: day.isEven ? '팔 펴요' : '무릎 떼요',
              ),
            ],
          ),
      ];
      final common = HoldMetrics.of(record, kept: warned).commonWarning!;
      expect(common.words, '무릎 떼요');
      expect(common.holds, 3);
      expect(common.of, 5);
      expect(HoldMetrics.of(_earlier(26, 9000)).commonWarning, isNull);
    });

    test('a shorter hold is not a best and gets no above-mean line', () {
      final short = holdRecord(heldMs: 10000, elapsedMs: 10000);
      final m = HoldMetrics.of(short, kept: kept);
      expect(m.best, isFalse);
      expect(m.highlights.where((l) => l.startsWith('최근 평균')), isEmpty);
      expect(m.endurance, lessThan(100));
    });
  });

  test('a hold of no time: keep rate 0, endurance absent when the means '
      'are 0', () {
    final none = holdRecord(heldMs: 0, elapsedMs: 0, warnings: const []);
    expect(HoldMetrics.keepRateOf(none), 0);
    expect(HoldMetrics.keepRateOf(holdRecord(heldMs: 1000, elapsedMs: 0)), 1);
    expect(HoldMetrics.of(none, kept: [_earlier(1, 0)]).endurance, isNull);
  });

  test('one decimal, none when whole; the stars\' words', () {
    expect(HoldMetrics.oneDecimal(5.44), '5.4');
    expect(HoldMetrics.oneDecimal(5.0), '5');
    expect(HoldMetrics.starWords(1), '첫 번째 별');
    expect(HoldMetrics.starWords(3), '세 번째 별');
    expect(HoldStatus.values.map((s) => s.label), ['우수', '표준', '부족']);
  });
}
