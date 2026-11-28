import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/hold_record.dart';
import 'package:gymrats_app/screens/hold_report_screen.dart';
import 'package:gymrats_app/services/feedback/hold_record_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';

import '../models/hold_record_test.dart' show holdRecord;
import '../widgets/battle_test_support.dart';

HoldRecord _earlier(int day, int heldMs) => holdRecord(
  endedAt: DateTime(2026, 11, day, 9),
  heldMs: heldMs,
  elapsedMs: heldMs,
  warnings: const [],
  pauses: const [],
  endedByWarnings: false,
);

void main() {
  setUpAll(loadBattleFonts);

  final record = holdRecord();

  Future<void> open(
    WidgetTester tester, {
    HoldRecordStore? store,
    double? weightKg,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => HoldReportScreen(
                    record: record,
                    store: store,
                    weightKg: weightKg,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final vertical = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(finder, 200, scrollable: vertical.first);

  group('the hold report (P13, design H-A)', () {
    testWidgets('REPORT, the date, the hold score, the pose, floor and stars', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('REPORT'), findsOneWidget);
      expect(find.text('26.11.26(목) 21:10'), findsOneWidget);
      expect(find.text('유지 점수'), findsOneWidget);
      expect(
        find.bySemanticsLabel('유지 점수 ${(100 * 0.7 * 24.6 / 26.7).round()}점'),
        findsOneWidget,
      );
      expect(find.text('STAGE 3 · 하이 플랭크 · 별 2/3'), findsOneWidget);
    });

    testWidgets('자세 분석: the time line, the cards and the most frequent '
        'warning', (tester) async {
      await open(tester);
      expect(find.text('경고 2 · 멈춤 2.1초'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^버틴 시간 흐름, 24.6초 버팀, 전체 26.7초')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('유지율 우수, 92%'), findsOneWidget);
      expect(find.bySemanticsLabel('경고 부족, 2회'), findsOneWidget);
      expect(find.bySemanticsLabel('목표 달성 표준, 24.6 / 30초'), findsOneWidget);
      expect(find.text('가장 많이 받은 경고'), findsOneWidget);
      expect(find.text('무릎 떼요'), findsOneWidget);
      expect(find.text('이번 기록'), findsOneWidget);
      expect(find.text('버틴 시간'), findsWidgets);
      expect(find.text('경고로 멈춤'), findsOneWidget);
    });

    testWidgets('운동 분석 without earlier holds: time held and calories on '
        '65 kg; no endurance index (user, 2026-11-26)', (tester) async {
      await open(tester);
      await scrollTo(tester, find.text('운동 분석'));
      expect(find.bySemanticsLabel('버틴 시간 24.6초'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^예상 소모 칼로리 1\.8kcal')),
        findsOneWidget,
      );
      expect(find.text('65 kg 기준 추정'), findsOneWidget);
      expect(find.text('근지구력 지수'), findsNothing);
      expect(find.textContaining('= 100'), findsNothing);
      expect(find.textContaining('들어 올린 무게'), findsNothing);
    });

    testWidgets('a given body weight is named', (tester) async {
      await open(tester, weightKg: 80);
      await scrollTo(tester, find.text('체중 80 kg 기준 추정'));
      expect(find.text('체중 80 kg 기준 추정'), findsOneWidget);
    });

    testWidgets('성과: the clean start and the next star; 변화 says 비교 '
        '기록 없음 without earlier holds; the coach line', (tester) async {
      await open(tester);
      await scrollTo(tester, find.text('코치 한마디'));
      expect(find.text('처음 12초 경고 없이'), findsOneWidget);
      expect(find.text('세 번째 별까지 5.4초'), findsOneWidget);
      expect(find.text('변화'), findsOneWidget);
      expect(find.text('하이 플랭크 버틴 시간'), findsOneWidget);
      expect(find.text(noEarlier), findsOneWidget);
      expect(
        find.text('12초쯤 "무릎 떼요" 경고가 나왔어요. 다음엔 그 순간을 넘겨 30초 별을 노려 봐요.'),
        findsOneWidget,
      );
    });

    testWidgets('with earlier holds: changes against the recent mean and 변화', (
      tester,
    ) async {
      final store = InMemoryHoldRecordStore();
      for (final (day, ms) in [(23, 22300), (24, 20100), (25, 23000)]) {
        await store.save(_earlier(day, ms));
      }
      await store.save(record);
      await open(tester, store: store);
      expect(find.bySemanticsLabel(RegExp('^최근 평균보다 .* 적음')), findsWidgets);
      expect(find.text('근지구력 지수'), findsNothing);
      await scrollTo(tester, find.text('변화'));
      expect(find.text('최근 4회 · 하이 플랭크 버틴 시간'), findsOneWidget);
      expect(
        find.bySemanticsLabel('최근 4회 하이 플랭크 버틴 시간: 22.3초, 20.1초, 23초, 24.6초'),
        findsOneWidget,
      );
      expect(find.text('오늘'), findsOneWidget);
      expect(find.text('개인 최고 기록'), findsOneWidget);
    });

    testWidgets('back returns', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('fits a 360 x 780 phone at ${scale}x text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = InMemoryHoldRecordStore();
        await store.save(_earlier(25, 23000));
        await store.save(record);
        await open(tester, store: store, size: const Size(360, 780));
        expect(tester.takeException(), isNull);
        await tester.drag(vertical.first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the time line', () {
    test('a star is reached later by each pause before it', () {
      expect(holdStarTimes(record), [
        const Duration(milliseconds: 17100),
        const Duration(milliseconds: 22100),
      ]);
      expect(holdStarTimes(holdRecord(stars: 0)), isEmpty);
    });

    test('with held spans a star sits where the time held reached it: a '
        "chair's 5 s entry moves the 10 s star to 15 s (PR #106 Codex "
        'review)', () {
      final chair = HoldRecord(
        endedAt: DateTime(2026, 11, 27, 9),
        pose: HoldPose.chair,
        stage: 5,
        held: const Duration(seconds: 17),
        elapsed: const Duration(seconds: 24),
        stars: 2,
        starSeconds: const [10, 15, 30],
        heldSpans: const [
          HoldRecordSpan(
            start: Duration(seconds: 5),
            end: Duration(seconds: 17),
          ),
          HoldRecordSpan(
            start: Duration(seconds: 19),
            end: Duration(seconds: 24),
          ),
        ],
      );
      // 10 s held at 15 s; 15 s held: 12 s in the first span, 3 s more at 22 s.
      expect(holdStarTimes(chair), const [
        Duration(seconds: 15),
        Duration(seconds: 22),
      ]);
      // Spans a frame short of the star: the last moment held.
      final short = HoldRecord(
        endedAt: DateTime(2026, 11, 27, 9),
        pose: HoldPose.chair,
        stage: 5,
        held: const Duration(seconds: 10),
        elapsed: const Duration(seconds: 12),
        stars: 1,
        starSeconds: const [10, 15, 30],
        heldSpans: const [
          HoldRecordSpan(
            start: Duration(seconds: 2),
            end: Duration(milliseconds: 11950),
          ),
        ],
      );
      expect(holdStarTimes(short), const [Duration(milliseconds: 11950)]);
    });

    test('a moment on the bar, from GO to the end', () {
      final painter = HoldTimelinePainter(
        record: record,
        starStyle: const TextStyle(),
        warningStyle: const TextStyle(),
        axisStyle: const TextStyle(),
      );
      expect(painter.xOf(Duration.zero, 267), 0);
      expect(painter.xOf(const Duration(seconds: 12), 267), closeTo(120, 0.01));
      expect(painter.xOf(const Duration(minutes: 1), 267), 267);
      expect(painter.shouldRepaint(painter), isFalse);
    });

    test('the bar fills only the held spans; a record kept before them '
        'fills all but the pauses (PR #106 Codex review)', () {
      List<Rect> rectsOf(HoldRecord r) {
        final canvas = _RecordingCanvas();
        HoldTimelinePainter(
          record: r,
          starStyle: const TextStyle(),
          warningStyle: const TextStyle(),
          axisStyle: const TextStyle(),
        ).paint(canvas, const Size(200, 80));
        return canvas.rects;
      }

      final spanned = HoldRecord(
        endedAt: DateTime(2026, 11, 27, 9),
        pose: HoldPose.chair,
        stage: 5,
        held: const Duration(seconds: 17),
        elapsed: const Duration(seconds: 20),
        stars: 1,
        starSeconds: const [15, 20, 30],
        heldSpans: const [
          HoldRecordSpan(
            start: Duration(seconds: 2),
            end: Duration(seconds: 12),
          ),
          HoldRecordSpan(
            start: Duration(seconds: 13),
            end: Duration(seconds: 20),
          ),
        ],
      );
      final held = rectsOf(spanned);
      expect(held.map((r) => (r.left, r.right)), [
        (20.0, 120.0),
        (130.0, 200.0),
      ]);
      final old = rectsOf(record);
      expect((old.first.left, old.first.right), (0.0, 200.0));
    });

    test('the words a screen reader hears', () {
      expect(
        HoldTimeline.words(record),
        '버틴 시간 흐름, 24.6초 버팀, 전체 26.7초, 17.1초에 15초 별, 22.1초에 20초 별, '
        '12초에 "무릎 떼요" 경고, 26.7초에 "머리 들어요" 경고, 2.1초 멈춤',
      );
    });

    test('the report date', () {
      expect(
        holdReportDate(DateTime(2026, 11, 26, 21, 10)),
        '26.11.26(목) 21:10',
      );
      expect(holdReportDate(DateTime(2027, 1, 4, 8, 5)), '27.01.04(월) 08:05');
    });
  });
}

/// Keeps the rectangles a painter draws; ignores everything else.
class _RecordingCanvas implements Canvas {
  final rects = <Rect>[];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
