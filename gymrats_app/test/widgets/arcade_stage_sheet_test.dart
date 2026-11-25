import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/arcade_stage_sheet.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/gym_background.dart';

void main() {
  late List<String> taps;

  Future<void> show(WidgetTester tester, int number, {int best = 0}) async {
    taps = [];
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ArcadeStageSheet.show(
                context,
                stage: ArcadeCatalog.stage(number) as ArcadeFightStage,
                best: best,
                onChallenge: () => taps.add('challenge'),
              ),
              child: const Text('map'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('map'));
    await tester.pumpAndSettle();
  }

  testWidgets('STAGE 8 (design ArcMap sheet): the floor\'s gym with the '
      'opponent, the chips and the star conditions', (tester) async {
    await show(tester, 8);
    expect(find.text('STAGE 8'), findsOneWidget);
    expect(find.text('2F · AI LV 6'), findsOneWidget);
    expect(find.text('물렁범'), findsOneWidget);
    expect(find.text('스쿼트 · 30초'), findsOneWidget);
    expect(find.text('피버 15초부터'), findsOneWidget);
    expect(find.text('별 조건'), findsOneWidget);
    final stage = ArcadeCatalog.stage(8);
    for (final star in stage.stars) {
      expect(find.text(star.label), findsOneWidget);
    }
    expect(tester.widget<GymBackground>(find.byType(GymBackground)).floor, 2);
    expect(
      tester
          .widgetList<CharacterFigure>(find.byType(CharacterFigure))
          .map((figure) => figure.characterId)
          .toSet(),
      {'seal'},
    );
    expect(find.text('닫기'), findsOneWidget);
    expect(find.text('도전'), findsOneWidget);
  });

  testWidgets('1F has no rule chip', (tester) async {
    await show(tester, 2);
    expect(find.text('1F · AI LV 2'), findsOneWidget);
    expect(find.text('스쿼트 · 30초'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ArcadeGlyphIcon && widget.glyph == ArcadeGlyph.bolt,
      ),
      findsNothing,
    );
  });

  testWidgets('a best of 2 from a KO win without the second condition: no '
      'condition reads as got; the best on a line of its own (PR #91 review)', (
    tester,
  ) async {
    await show(tester, 8, best: 2);
    final stage = ArcadeCatalog.stage(8);
    expect(find.text('최고 기록: 별 2/3'), findsOneWidget);
    expect(find.bySemanticsLabel('최고 기록, 별 3개 중 2개'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('받음')), findsNothing);
    expect(
      tester
          .widgetList<ArcadeGlyphIcon>(find.byType(ArcadeGlyphIcon))
          .where((icon) => icon.fill == AppColors.starOn),
      isEmpty,
    );
    expect(
      find.bySemanticsLabel('두 번째 별, ${stage.stars[1].label}'),
      findsOneWidget,
    );
  });

  testWidgets('never cleared: no best line; the conditions read by their '
      'star (PR #91 review)', (tester) async {
    await show(tester, 8);
    final stage = ArcadeCatalog.stage(8);
    expect(find.textContaining('최고 기록'), findsNothing);
    expect(
      find.bySemanticsLabel('첫 번째 별, ${stage.stars[0].label}'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('세 번째 별, ${stage.stars[2].label}'),
      findsOneWidget,
    );
  });

  testWidgets('닫기 closes it; 도전 closes it and challenges', (tester) async {
    await show(tester, 8);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(ArcadeStageSheet), findsNothing);
    expect(taps, isEmpty);

    await tester.tap(find.text('map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('도전'));
    await tester.pumpAndSettle();
    expect(find.byType(ArcadeStageSheet), findsNothing);
    expect(taps, ['challenge']);
  });

  testWidgets('it names its route for a screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, 8);
    expect(find.bySemanticsLabel('스테이지 8'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  test('the grid repaints only for another cell', () {
    const grid = ArcadeGridPainter(cell: 22);
    expect(grid.shouldRepaint(const ArcadeGridPainter(cell: 22)), isFalse);
    expect(grid.shouldRepaint(const ArcadeGridPainter(cell: 28)), isTrue);
  });
}
