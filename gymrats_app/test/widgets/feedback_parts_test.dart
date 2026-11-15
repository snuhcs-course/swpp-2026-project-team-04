import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/feedback_parts.dart';
import 'package:gymrats_app/widgets/form_fault_clip.dart';

Widget _host(Widget child, {double width = 320}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

BoxDecoration _decoration(WidgetTester tester, Finder of) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: of, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

const _reps = [
  RepRecord(
    index: 1,
    valid: true,
    at: Duration(seconds: 2),
    maxDepth: 1.21,
    minElbowAngle: 84,
  ),
  RepRecord(
    index: 2,
    valid: false,
    at: Duration(milliseconds: 6900),
    reason: RejectReason.insufficientDepth,
    maxDepth: 0.86,
    minElbowAngle: 98.4,
  ),
  RepRecord(index: 3, valid: true, at: Duration(seconds: 9)),
];

void main() {
  group('FeedbackPanel', () {
    testWidgets('a white card with the border, the card radius and 12 inside', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FeedbackPanel(child: Text('x'))));
      final box = _decoration(tester, find.byType(FeedbackPanel));
      expect(box.color, AppColors.card);
      expect(box.border, Border.all(color: AppColors.border));
      expect(
        box.borderRadius,
        const BorderRadius.all(Radius.circular(AppRadius.card)),
      );
      expect(
        tester
            .widget<Padding>(
              find.descendant(
                of: find.byType(FeedbackPanel),
                matching: find.byType(Padding),
              ),
            )
            .padding,
        const EdgeInsets.all(AppSpacing.s12),
      );
    });
  });

  group('FeedbackSectionTitle', () {
    testWidgets('the title on the left and its unit on the right, a header '
        'for a screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const FeedbackSectionTitle('머리 하강 깊이', detail: '어깨 너비 기준')),
      );
      final title = tester.getRect(find.text('머리 하강 깊이'));
      final detail = tester.getRect(find.text('어깨 너비 기준'));
      expect(title.left, 0);
      expect(detail.right, closeTo(320, 0.5));
      expect(detail.top, lessThan(title.bottom));
      expect(
        tester.widget<Text>(find.text('머리 하강 깊이')).style!.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester.widget<Text>(find.text('어깨 너비 기준')).style!.color,
        AppColors.textSecondary,
      );
      expect(
        tester.getSemantics(find.text('머리 하강 깊이')),
        isSemantics(label: '머리 하강 깊이\n어깨 너비 기준', isHeader: true),
      );
      semantics.dispose();
    });

    testWidgets('a unit that does not fit goes under the title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const FeedbackSectionTitle('앉은 깊이', detail: '서 있을 때 허벅지 길이 기준'),
          width: 150,
        ),
      );
      expect(
        tester.getRect(find.text('서 있을 때 허벅지 길이 기준')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('앉은 깊이')).bottom),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('FeedbackStat', () {
    testWidgets('the label, the number and its unit; a swatch only when '
        'given', (tester) async {
      await tester.pumpWidget(
        _host(
          const Row(
            children: [
              Expanded(
                child: FeedbackStat(label: '인정', value: '10', unit: '회'),
              ),
              Expanded(
                child: FeedbackStat(
                  label: '무효',
                  value: '2',
                  unit: '회',
                  swatch: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('인정'), findsOneWidget);
      expect(find.text('10회'), findsOneWidget);
      expect(find.text('2회'), findsOneWidget);
      expect(find.byType(FeedbackSwatch), findsOneWidget);
      expect(
        tester.widget<FeedbackSwatch>(find.byType(FeedbackSwatch)).color,
        AppColors.warning,
      );
      final number = tester.widget<Text>(find.text('10회')).textSpan!;
      expect(number.style!.fontSize, 24);
      expect(number.style!.fontFamily, AppFonts.number);
      expect(number.style!.color, AppColors.textPrimary);
    });

    testWidgets('a number too wide for its tile shrinks on one line', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _host(
          const FeedbackStat(label: '평균 깊이', value: '1.19', unit: '배'),
          width: 100,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text('1.19배')).maxLines, 1);
      expect(
        tester.getSize(find.byType(FittedBox)).width,
        lessThanOrEqualTo(100 - 2 * AppSpacing.s12),
      );
    });
  });

  group('FeedbackSwatch', () {
    testWidgets('is the palette B swatch, swatch-sized', (tester) async {
      await tester.pumpWidget(
        _host(const Align(child: FeedbackSwatch(AppColors.accent))),
      );
      expect(tester.getSize(find.byType(FeedbackSwatch)), const Size(10, 10));
      expect(
        _decoration(tester, find.byType(FeedbackSwatch)),
        AppHighlight.swatch(AppColors.accent),
      );
    });
  });

  group('FeedbackBadge', () {
    BoxDecoration badge(WidgetTester tester) =>
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(FeedbackBadge),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;

    testWidgets('a fix: an ink "!" on amber with an ink edge', (tester) async {
      await tester.pumpWidget(
        _host(const Align(child: FeedbackBadge(FindingKind.issue))),
      );
      expect(badge(tester).color, AppColors.warning);
      expect(
        badge(tester).border,
        Border.all(color: AppColors.ink, width: 1.5),
      );
      expect(badge(tester).shape, BoxShape.circle);
      expect(tester.widget<Text>(find.text('!')).style!.color, AppColors.ink);
      expect(tester.getSize(find.byType(FeedbackBadge)), const Size(24, 24));
    });

    testWidgets('a good point: an ink check on lime with an ink edge', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FeedbackBadge(FindingKind.good)));
      expect(badge(tester).color, AppColors.accent);
      expect(
        badge(tester).border,
        Border.all(color: AppColors.ink, width: 1.5),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.check_rounded);
      expect(icon.color, AppColors.ink);
    });

    testWidgets('a note: a gray "i" in a gray ring, no fill', (tester) async {
      await tester.pumpWidget(_host(const FeedbackBadge(FindingKind.note)));
      expect(badge(tester).color, isNull);
      expect(
        badge(tester).border,
        Border.all(color: AppColors.line, width: 1.5),
      );
      expect(
        tester.widget<Text>(find.text('i')).style!.color,
        AppColors.textMuted,
      );
    });

    testWidgets('a screen reader hears the kind, and the mark does not grow '
        'out of its circle', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final (kind, label) in [
        (FindingKind.issue, '고칠 점'),
        (FindingKind.good, '잘한 점'),
        (FindingKind.note, '참고'),
      ]) {
        await tester.pumpWidget(_host(FeedbackBadge(kind)));
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(
        tester.widget<Text>(find.text('i')).textScaler,
        TextScaler.noScaling,
      );
      semantics.dispose();
    });
  });

  group('FeedbackFindingCard', () {
    testWidgets('the title and the numbers in ink, the fix quieter, and the '
        'example when there is one', (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackFindingCard(
            finding: FormFinding(
              kind: FindingKind.issue,
              title: '깊이 부족 1회',
              detail: '가슴을 더 내려요',
              fix: '가슴이 바닥에 가까워질 때까지 내려가요.',
              demo: FormDemo.shallow,
            ),
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('깊이 부족 1회')).style!;
      expect(title.color, AppColors.textPrimary);
      expect(title.fontWeight, FontWeight.w700);
      expect(
        tester.widget<Text>(find.text('가슴을 더 내려요')).style!.color,
        AppColors.textPrimary,
      );
      expect(
        tester.widget<Text>(find.text('→ 가슴이 바닥에 가까워질 때까지 내려가요.')).style!.color,
        AppColors.textSecondary,
      );
      expect(find.byType(FormFaultClip), findsOneWidget);
      expect(find.byType(FeedbackBadge), findsOneWidget);
    });

    testWidgets('a good point has no fix line and no example', (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackFindingCard(
            finding: FormFinding(
              kind: FindingKind.good,
              title: '양팔 균형',
              detail: '고르게 밀었어요.',
            ),
          ),
        ),
      );
      expect(find.textContaining('→'), findsNothing);
      expect(find.byType(FormFaultClip), findsNothing);
    });
  });

  group('FeedbackChartPanel', () {
    testWidgets('the chart is one picture with its name, then the sentence '
        'and the legend', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const FeedbackChartPanel(
            label: '머리 하강 깊이 그래프',
            chart: Text('차트 안의 숫자'),
            caption: '깊이는 끝까지 유지됐어요.',
            legend: Text('범례'),
          ),
        ),
      );
      expect(find.bySemanticsLabel('머리 하강 깊이 그래프'), findsOneWidget);
      expect(find.bySemanticsLabel('차트 안의 숫자'), findsNothing);
      expect(find.text('깊이는 끝까지 유지됐어요.'), findsOneWidget);
      expect(
        tester.getRect(find.text('범례')).top,
        greaterThan(tester.getRect(find.text('깊이는 끝까지 유지됐어요.')).bottom),
      );
      semantics.dispose();
    });

    testWidgets('without a legend only the sentence follows', (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackChartPanel(
            label: '그래프',
            chart: SizedBox.shrink(),
            caption: '문장',
          ),
        ),
      );
      expect(find.byType(Center), findsNothing);
    });
  });

  group('FeedbackNote', () {
    testWidgets('a quiet line in a panel', (tester) async {
      await tester.pumpWidget(_host(const FeedbackNote('비었어요.')));
      expect(find.byType(FeedbackPanel), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('비었어요.')).style!.color,
        AppColors.textSecondary,
      );
    });
  });

  group('FeedbackRepTable', () {
    testWidgets('a row per rep: number, time, a swatch and ink verdict, '
        'depth, elbow', (tester) async {
      await tester.pumpWidget(_host(const FeedbackRepTable(reps: _reps)));
      for (final head in ['#', '시간', '판정', '깊이', '팔꿈치']) {
        expect(find.text(head), findsOneWidget, reason: head);
      }
      expect(find.text('2s'), findsOneWidget);
      expect(find.text('6s'), findsOneWidget);
      expect(find.text('1.21'), findsOneWidget);
      expect(find.text('84°'), findsOneWidget);
      expect(find.text('98°'), findsOneWidget);
      expect(find.text('무효 · 가슴을 더 내려요'), findsOneWidget);
      // Rep 3 has neither a depth nor an elbow angle.
      expect(find.text('—'), findsNWidgets(2));
      final swatches = tester
          .widgetList<FeedbackSwatch>(find.byType(FeedbackSwatch))
          .map((s) => s.color);
      expect(swatches, [AppColors.accent, AppColors.warning, AppColors.accent]);
      for (final verdict in ['인정', '무효 · 가슴을 더 내려요']) {
        final text = tester.widget<Text>(find.text(verdict).first);
        expect(text.style!.color, AppColors.textPrimary, reason: verdict);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      }
    });

    testWidgets('a squat has no elbow column', (tester) async {
      await tester.pumpWidget(
        _host(const FeedbackRepTable(reps: _reps, showElbow: false)),
      );
      expect(find.text('팔꿈치'), findsNothing);
      expect(find.text('84°'), findsNothing);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('1.21'), findsOneWidget);
    });

    testWidgets('with large text the number columns keep their widths and the '
        'whole reason wraps; nothing overflows', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_host(const FeedbackRepTable(reps: _reps)));
      expect(tester.takeException(), isNull);
      final number = find.ancestor(
        of: find.text('#'),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(number.first).width, 28);
      final reason = find.text('무효 · 가슴을 더 내려요');
      expect(tester.widget<Text>(reason).maxLines, isNull);
      expect(
        tester.renderObject<RenderParagraph>(reason).didExceedMaxLines,
        isFalse,
      );
      expect(tester.getSize(reason).height, greaterThan(28 * 1.5));
      // The two right-aligned heads keep a gap even when shrunk to fit.
      expect(
        tester.getRect(find.text('팔꿈치')).left -
            tester.getRect(find.text('깊이')).right,
        greaterThanOrEqualTo(AppSpacing.s8),
      );
      expect(
        tester.getRect(find.text('팔꿈치')).right,
        lessThanOrEqualTo(320 - AppSpacing.s12 + 0.01),
      );
    });
  });
}
