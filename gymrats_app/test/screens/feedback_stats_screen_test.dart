import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/screens/feedback_stats_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/feedback_stats_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';
import 'package:gymrats_app/widgets/feedback_stats_cards.dart';
import 'package:gymrats_app/widgets/feedback_stats_chart.dart';
import 'package:gymrats_app/widgets/feedback_stats_slots.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';

import '../support/feedback_fakes.dart';
import '../widgets/battle_test_support.dart';
import '../widgets/feedback_stats_golden.dart';

/// The mockup's today, Saturday 2026-11-14 (the cases end the day).
final _today = goldenDayEnd('2026-11-14');

void main() {
  // The app's fonts, so the screen measures as it does on a phone.
  setUpAll(loadBattleFonts);

  late FakeFeedbackStatsSource source;

  /// The statistics over a page, on a phone of [size] (tall by default, so
  /// both cards show without scrolling), with the mockup's 67 battles from
  /// [since] on and its clock at [now]. Returns before the battles arrive
  /// when [source]'s gate is set.
  Future<void> open(
    WidgetTester tester, {
    DateTime? since,
    DateTime? now,
    Size size = const Size(360, 2400),
    Completer<void>? gate,
    Exception? error,
    List<StatsPoint>? points,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    source = FakeFeedbackStatsSource(points ?? goldenStatsPoints(since: since))
      ..gate = gate
      ..error = error;
    final clock = now ?? _today;
    // A new app each time: a reused one keeps the route it opened first.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Text('archive')),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => FeedbackStatsScreen(
            createViewModel: () =>
                FeedbackStatsViewModel(source: source, now: () => clock),
            now: () => clock,
          ),
        ),
        initialRoute: '/stats',
      ),
    );
    // Not settle: the loading ring turns until the battles arrive.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  StatsChart chart(WidgetTester tester) =>
      tester.widget<FeedbackStatsChart>(find.byType(FeedbackStatsChart)).chart;

  /// Whether a screen reader hears [label]'s tab or chip as picked.
  bool picked(WidgetTester tester, String label) =>
      isSemantics(isSelected: true)
          .matches(tester.getSemantics(find.text(label)), {});

  group('opening', () {
    testWidgets('this week and both exercises are picked, with the '
        "mockup's week_both numbers", (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      expect(find.text('03 / STATS'), findsOneWidget);
      expect(find.text('기간별 통계'), findsOneWidget);
      expect(
        tester.widget<LobbyWatermark>(find.byType(LobbyWatermark)).word,
        'STATS',
      );
      expect(picked(tester, '이번 주'), isTrue);
      expect(picked(tester, '전체'), isFalse);
      expect(picked(tester, '둘 다'), isTrue);
      expect(picked(tester, '푸쉬업'), isFalse);
      expect(find.text('이번 주 · 11/9 월 ~ 11/15 일'), findsOneWidget);
      expect(find.text('13.8회'), findsOneWidget);
      expect(find.text('9판'), findsOneWidget);
      expect(find.text('124회'), findsOneWidget);
      expect(chart(tester).slots, hasLength(7));
      expect(find.text('경기 9판 중 자세 기록 8판 기준'), findsOneWidget);
      expect(find.text('가슴을 더 내려요'), findsOneWidget);
      expect(find.text('팔꿈치 벌어짐'), findsOneWidget);
      expect(source.calls, hasLength(1));
      semantics.dispose();
    });

    testWidgets('the tabs run 전체, 이번 달, 이번 주 and the chips 푸쉬업, '
        '스쿼트, 둘 다', (tester) async {
      await open(tester);
      double x(String label) => tester.getCenter(find.text(label)).dx;
      expect(x('전체'), lessThan(x('이번 달')));
      expect(x('이번 달'), lessThan(x('이번 주')));
      expect(x('푸쉬업'), lessThan(x('스쿼트')));
      expect(x('스쿼트'), lessThan(x('둘 다')));
    });

    testWidgets('back returns to the archive', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('archive'), findsOneWidget);
    });
  });

  testWidgets('tabs and chips switch the values without loading again', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, '이번 달');
    expect(find.text('이번 달 · 11/1 ~ 11/30'), findsOneWidget);
    expect(find.text('12.7회'), findsOneWidget);
    expect(find.text('19판'), findsOneWidget);
    await tap(tester, '푸쉬업');
    await tap(tester, '이번 주');
    expect(find.text('12.5회'), findsOneWidget);
    expect(find.text('6판'), findsOneWidget);
    await tap(tester, '스쿼트');
    expect(find.text('16.3회'), findsOneWidget);
    await tap(tester, '둘 다');
    await tap(tester, '전체');
    expect(find.text('전체 · 9/7 첫 경기부터'), findsOneWidget);
    expect(find.text('856회'), findsOneWidget);
    expect(source.calls, hasLength(1));
  });

  group('loading', () {
    testWidgets('gray boxes and 불러오는 중; a tab picked meanwhile stays '
        'picked once loaded', (tester) async {
      final gate = Completer<void>();
      await open(tester, gate: gate);
      expect(find.byType(FeedbackStatsLoadingCards), findsOneWidget);
      expect(find.text('불러오는 중'), findsOneWidget);
      expect(find.text('이번 주 · 11/9 월 ~ 11/15 일'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(chart(tester).slots.map((s) => s.look).toSet(), {
        StatsBarLook.skeleton,
      });

      await tester.tap(find.text('이번 달'));
      await tester.pump();
      expect(find.text('이번 달 · 11/1 ~ 11/30'), findsOneWidget);
      expect(chart(tester).slots, hasLength(30));
      await tester.tap(find.text('전체'));
      await tester.pump();
      expect(find.text('전체'), findsNWidgets(2));
      expect(chart(tester).slots, hasLength(10));
      await tester.tap(find.text('스쿼트'));
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackStatsLoadingCards), findsNothing);
      // Every record of squats: 30 battles.
      expect(find.text('30판'), findsOneWidget);
      expect(source.calls, hasLength(1));
    });

    testWidgets('a screen reader hears "통계를 불러오는 중" once, not the gray '
        'boxes', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, gate: Completer<void>());
      expect(find.bySemanticsLabel('통계를 불러오는 중'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('통계를 불러오는 중')),
        isSemantics(isLiveRegion: true),
      );
      expect(find.bySemanticsLabel(RegExp('자세 문제')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('인정 횟수')), findsNothing);
      semantics.dispose();
    });

    testWidgets('with reduced motion the ring holds still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester, gate: Completer<void>());
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, 0.25);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('fits a 360 x 780 phone without scrolling', (tester) async {
      await open(tester, gate: Completer<void>(), size: const Size(360, 780));
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('failed', () {
    testWidgets('the reason, 다시 시도 and the note; the tabs stay, and 다시 '
        '시도 loads again', (tester) async {
      await open(tester, error: const ApiException(ApiErrorKind.network));
      await tester.pumpAndSettle();
      expect(find.text('통계를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('서버에 연결하지 못했어요. 인터넷 연결을 확인해 주세요.'), findsOneWidget);
      expect(find.text('고른 기간과 종목은 그대로 남아요.'), findsOneWidget);
      expect(find.text('!'), findsOneWidget);
      await tap(tester, '이번 달');
      expect(find.text('통계를 불러오지 못했어요'), findsOneWidget);

      source.error = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(source.calls, hasLength(2));
      expect(find.text('통계를 불러오지 못했어요'), findsNothing);
      // The month picked while it had failed.
      expect(find.text('이번 달 · 11/1 ~ 11/30'), findsOneWidget);
    });

    testWidgets('a screen reader is told when it shows; 다시 시도 is a '
        'button', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, error: const ApiException(ApiErrorKind.network));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('통계를 불러오지 못했어요')),
        isSemantics(isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.text('다시 시도')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('any other failure says to try again later', (tester) async {
      await open(tester, error: Exception('boom'));
      await tester.pumpAndSettle();
      expect(find.text(genericErrorMessage), findsOneWidget);
    });
  });

  group('empty', () {
    testWidgets('this week without battles: the notice over the plot, the '
        'dashes, and the form card\'s one line', (tester) async {
      await open(tester, now: goldenDayEnd('2026-11-17'));
      await tester.pumpAndSettle();
      expect(find.text('이번 주 · 11/16 월 ~ 11/22 일'), findsOneWidget);
      expect(find.text('–'), findsOneWidget);
      expect(find.text('0판'), findsOneWidget);
      expect(find.text('0회'), findsOneWidget);
      expect(find.text('이번 주에는 아직 경기가 없어요'), findsOneWidget);
      expect(find.text('대결을 마치면 여기에 날짜별로 쌓여요.'), findsOneWidget);
      expect(find.text('경기를 마치면 자세 문제가 여기에 모여요.'), findsOneWidget);
      expect(find.text('거절된 이유'), findsNothing);
      // Over the plot: the notice's top is the graph's.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('feedback-stats-empty'))),
        tester.getTopLeft(find.byType(FeedbackStatsChart)),
      );
      expect(chart(tester).slots, hasLength(7));
    });

    testWidgets('a screen reader is told about the empty notice', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await open(tester, now: goldenDayEnd('2026-11-17'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const ValueKey('feedback-stats-empty'))),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('this month without squats names the exercise', (tester) async {
      await open(
        tester,
        since: DateTime(2026, 11, 15),
        now: goldenDayEnd('2026-11-17'),
      );
      await tester.pumpAndSettle();
      await tap(tester, '이번 달');
      await tap(tester, '스쿼트');
      expect(find.text('이번 달에는 아직 스쿼트 경기가 없어요'), findsOneWidget);
      expect(chart(tester).slots, hasLength(30));
    });

    testWidgets('every record without battles: the notice under the numbers, '
        'no graph', (tester) async {
      await open(tester, points: const []);
      await tester.pumpAndSettle();
      await tap(tester, '전체');
      expect(find.text('아직 경기 기록이 없어요'), findsOneWidget);
      expect(find.text('첫 대결을 마치면 여기에 날짜별로 쌓여요.'), findsOneWidget);
      expect(find.byType(FeedbackStatsChart), findsNothing);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('feedback-stats-empty')))
            .dy,
        greaterThan(tester.getBottomLeft(find.text('0판')).dy),
      );
    });

    testWidgets('battles without form records: the base and one line', (
      tester,
    ) async {
      await open(
        tester,
        since: DateTime(2026, 11, 13),
        now: goldenDayEnd('2026-11-13'),
      );
      await tester.pumpAndSettle();
      await tap(tester, '스쿼트');
      expect(find.text('16.0회'), findsOneWidget);
      expect(find.text('경기 1판 중 자세 기록 0판 기준'), findsOneWidget);
      expect(find.text('이 기간 경기에는 자세 기록이 없어요.'), findsOneWidget);
      expect(find.byKey(const ValueKey('feedback-stats-empty')), findsNothing);
    });
  });

  testWidgets('a group over five rows opens with "나머지 N개 더 보기" and '
      'closes when the period changes', (tester) async {
    await open(tester);
    await tap(tester, '전체');
    // 10 rejection reasons: five show.
    expect(find.text('나머지 5개 더 보기'), findsOneWidget);
    expect(find.text('어깨를 수평으로 맞춰요'), findsOneWidget);
    expect(find.text('무릎을 바닥에서 떼요'), findsNothing);
    await tap(tester, '나머지 5개 더 보기');
    expect(find.text('무릎을 바닥에서 떼요'), findsOneWidget);
    expect(find.text('바닥에서 푸시업해요'), findsOneWidget);
    expect(find.text('접기'), findsOneWidget);
    await tap(tester, '이번 달');
    await tap(tester, '전체');
    expect(find.text('나머지 5개 더 보기'), findsOneWidget);
    expect(find.text('무릎을 바닥에서 떼요'), findsNothing);
    // A new exercise closes them as well.
    await tap(tester, '나머지 5개 더 보기');
    expect(find.text('접기'), findsOneWidget);
    await tap(tester, '푸쉬업');
    await tap(tester, '둘 다');
    expect(find.text('나머지 5개 더 보기'), findsOneWidget);
    expect(find.text('접기'), findsNothing);
  });

  group('graph slots', () {
    testWidgets("this month: the month's days, today in ink, the rest "
        'dashed', (tester) async {
      await open(tester);
      await tap(tester, '이번 달');
      final slots = chart(tester).slots;
      expect(slots, hasLength(30));
      expect(slots[13].look, StatsBarLook.now);
      expect(
        slots.skip(14).every((s) => s.look == StatsBarLook.future),
        isTrue,
      );
    });

    testWidgets('every record: by week over 14 days, with the note', (
      tester,
    ) async {
      await open(tester);
      await tap(tester, '전체');
      expect(chart(tester).kind, StatsChartKind.week);
      expect(chart(tester).slots, hasLength(10));
      expect(
        find.text('경기한 날이 14일을 넘어서 한 주씩 묶었어요. 막대 하나가 월요일부터 일요일까지예요.'),
        findsOneWidget,
      );
    });

    testWidgets('every record: by day up to 14 days, no note', (tester) async {
      await open(tester, since: DateTime(2026, 11, 2));
      await tester.pumpAndSettle();
      await tap(tester, '전체');
      expect(chart(tester).kind, StatsChartKind.day);
      expect(chart(tester).slots, hasLength(10));
      expect(find.textContaining('한 주씩 묶었어요'), findsNothing);
    });
  });

  testWidgets('a screen reader hears the tabs, the summary, the graph and '
      'each issue row as one line', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(find.bySemanticsLabel('기간'), findsOneWidget);
    expect(find.bySemanticsLabel('종목'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '이번 주, 11월 9일 월요일부터 15일 일요일까지. 경기당 평균 인정 13.8회, '
        '경기 9판, 총 인정 124회',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '날짜별 인정 횟수. 월 27회, 화 0회, 수 10회, 목 43회, 금 16회, 토 28회, 일 아직',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('가슴을 더 내려요, 거절 7회'), findsOneWidget);
    expect(find.bySemanticsLabel('팔꿈치 벌어짐, 자세 기록 8판 중 3판'), findsOneWidget);
    expect(find.bySemanticsLabel('자세 문제'), findsOneWidget);
    // By week: each slot from its Monday, the dates spelled out.
    await tap(tester, '전체');
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^주별 인정 횟수\. 9월 7일부터 한 주 73회, 9월 14일부터 한 주 94회, .*'
          r'11월 9일부터 한 주 124회$',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the first 360 x 780 screen holds the summary card and four '
      'rejection rows', (tester) async {
    await open(tester, size: const Size(360, 780));
    expect(
      tester.getBottomLeft(find.byType(FeedbackStatsSummaryCard)).dy,
      lessThan(780),
    );
    expect(tester.getBottomLeft(find.text('무릎을 바닥에서 떼요')).dy, lessThan(780));
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('no overflow at ${scale}x text on a 360 wide phone, in '
        'every state', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final gate = Completer<void>();
      await open(tester, gate: gate, size: const Size(360, 780));
      expect(tester.takeException(), isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final tab in ['이번 달', '전체']) {
        await tap(tester, tab);
        expect(tester.takeException(), isNull);
      }
      await open(tester, error: Exception('x'), size: const Size(360, 780));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('통계를 불러오지 못했어요'), findsOneWidget);
      // The empty notice grows past the graph instead of being cut.
      await open(
        tester,
        now: goldenDayEnd('2026-11-17'),
        size: const Size(360, 780),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final notice = find.byKey(const ValueKey('feedback-stats-empty'));
      expect(
        tester.getBottomLeft(notice).dy,
        lessThanOrEqualTo(
          tester.getBottomLeft(find.byType(FeedbackStatsChart)).dy,
        ),
      );
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('대결을 마치면 여기에 날짜별로 쌓여요.'))
            .didExceedMaxLines,
        isFalse,
      );
    });
  }
}
