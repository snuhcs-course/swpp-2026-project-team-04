import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/feedback/coach_script.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/coach_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/coach_parts.dart';
import 'package:gymrats_app/widgets/coach_stage.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }

  group('the marked text', () {
    test('a word joiner between the letters of each word, none at spaces', () {
      expect(CoachMarkedText.keepWords('가 나다'), '가 나⁠다');
      expect(CoachMarkedText.keepWords(''), '');
    });

    testWidgets('lines break only between words (word-break: keep-all)', (
      tester,
    ) async {
      const words = '처음부터 끝까지 고른 속도였어 좋다범 이번엔 목표 없이 편하게 해 보자';
      await show(
        tester,
        SizedBox(
          width: 120,
          child: CoachMarkedText(
            pieces: const [CoachPiece(words)],
            style: AppTheme.light.textTheme.coachLine,
          ),
        ),
      );
      final rich = tester.widget<RichText>(find.byType(RichText));
      final painter = TextPainter(
        text: rich.text,
        textDirection: TextDirection.ltr,
        textScaler: rich.textScaler,
      )..layout(maxWidth: tester.getSize(find.byType(RichText)).width);
      addTearDown(painter.dispose);
      final text = rich.text.toPlainText();
      // Every line ends at a space or the end, never inside a word.
      final ends = <int>[];
      var offset = 0;
      while (offset < text.length) {
        final line = painter.getLineBoundary(TextPosition(offset: offset));
        ends.add(line.end);
        offset = line.end + 1;
      }
      expect(ends.length, greaterThan(1));
      bool atSpace(String text, int end) =>
          end == text.length || text[end] == ' ' || text[end - 1] == ' ';
      for (final end in ends) {
        expect(atSpace(text, end), isTrue, reason: '$end');
      }
      // Without the joiners the same words break inside a word: Flutter
      // breaks between any two Hangul syllables.
      final plain = TextPainter(
        text: TextSpan(text: words, style: rich.text.style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: tester.getSize(find.byType(RichText)).width);
      addTearDown(plain.dispose);
      final plainEnds = <int>[];
      for (var at = 0; at < words.length;) {
        final line = plain.getLineBoundary(TextPosition(offset: at));
        plainEnds.add(line.end);
        at = line.end + 1;
      }
      expect(plainEnds.any((end) => !atSpace(words, end)), isTrue);
    });

    testWidgets('marked runs are bold; plain ones keep the style', (
      tester,
    ) async {
      await show(
        tester,
        CoachMarkedText(
          pieces: const [
            CoachPiece('이번 판 '),
            CoachPiece('18번', marked: true),
            CoachPiece(' 인정!'),
          ],
          style: AppTheme.light.textTheme.coachLine,
        ),
      );
      final marked = <TextSpan>[];
      tester.widget<RichText>(find.byType(RichText)).text.visitChildren((span) {
        if (span is TextSpan &&
            span.text != null &&
            span.style?.fontWeight == FontWeight.w700) {
          marked.add(span);
        }
        return true;
      });
      // The joiner that keeps "18번" with "이번 판 " is in it.
      expect(marked.single.text!.replaceAll('⁠', ''), '18번');
    });
  });

  group('small parts', () {
    testWidgets('the name tag, large and small', (tester) async {
      await show(tester, const CoachNameTag(name: '그루'));
      expect(tester.getSize(find.byType(CoachNameTag)).height, 40);
      await show(tester, const CoachNameTag(name: '그루', small: true));
      expect(tester.getSize(find.byType(CoachNameTag)).height, 28);
    });

    testWidgets('the dots: the page now wide and ink, the ones before gray', (
      tester,
    ) async {
      await show(tester, const CoachPageDots(count: 4, current: 1));
      Color colorOf(int i) =>
          (tester
                      .widget<Container>(find.byKey(ValueKey('coach-dot-$i')))
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(
        [for (var i = 0; i < 4; i++) colorOf(i)],
        [
          AppColors.textMuted,
          AppColors.ink,
          AppColors.border,
          AppColors.border,
        ],
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('coach-dot-1'))).width,
        20,
      );
    });

    testWidgets('a choice is one button with its title and line; 사양할래 '
        'is quieter and shorter', (tester) async {
      final semantics = tester.ensureSemantics();
      var picked = 0;
      await show(
        tester,
        SizedBox(
          width: 226,
          child: Column(
            children: [
              CoachChoiceButton(
                title: '스쿼트 20회 인정받기',
                subtitle: '이번 판 18회보다 2회 더',
                onPressed: () => picked++,
              ),
              CoachChoiceButton(title: '사양할래', decline: true, onPressed: () {}),
            ],
          ),
        ),
      );
      final label = find.bySemanticsLabel('스쿼트 20회 인정받기, 이번 판 18회보다 2회 더');
      expect(
        tester.getSemantics(label),
        isSemantics(isButton: true, hasTapAction: true),
      );
      // A screen reader's double tap picks it too.
      tester.semantics.tap(
        find.semantics.byLabel('스쿼트 20회 인정받기, 이번 판 18회보다 2회 더'),
      );
      expect(picked, 1);
      await tester.tap(find.text('스쿼트 20회 인정받기'));
      expect(picked, 2);
      final sizes = [
        for (final title in ['스쿼트 20회 인정받기', '사양할래'])
          tester.getSize(find.widgetWithText(InkWell, title)).height,
      ];
      expect(sizes.first, greaterThanOrEqualTo(58));
      expect(sizes.last, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    testWidgets('the target icon', (tester) async {
      await show(tester, const CoachTargetIcon(size: 24));
      expect(tester.getSize(find.byType(CoachTargetIcon)), const Size(24, 24));
    });
  });

  group('the stage', () {
    testWidgets('while the talk loads: a turning ring', (tester) async {
      await show(
        tester,
        SizedBox(
          width: 360,
          height: 700,
          child: CoachStage(
            state: const CoachState(),
            voice: CoachVoice.of('mouse'),
            summary: '',
            onTap: () {},
            onSkip: () {},
            onChoose: (_) {},
            onReport: () {},
            onLeave: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('the character\'s poses', () {
      expect(CoachPose.values.map(CoachStage.poseOf), [
        BattlePose.idle,
        BattlePose.win,
        BattlePose.hit,
      ]);
    });

    test('the box grows with the text past 1x: four lines\' worth', () {
      final line = AppTheme.light.textTheme.coachLine;
      expect(CoachStage.boxHeightAt(TextScaler.noScaling, line), 196);
      expect(
        CoachStage.boxHeightAt(const TextScaler.linear(1.5), line),
        closeTo(196 + 4 * 17.5 * 1.62 * 0.5, 0.01),
      );
    });
  });
}
