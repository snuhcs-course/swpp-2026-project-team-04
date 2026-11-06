import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/lobby_menu_item.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';

void main() {
  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  final taps = <String>[];

  /// The three entries as home has them, at the design's width.
  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(360, 780),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    taps.clear();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LobbyMenuItem(
                  tag: '01 / PLAY',
                  title: '게임 시작',
                  main: true,
                  onTap: () => taps.add('play'),
                ),
                LobbyMenuItem(
                  tag: '02 / ARCHIVE',
                  title: '기록보관소',
                  onTap: () => taps.add('archive'),
                ),
                LobbyMenuItem(
                  tag: '03 / SETTINGS',
                  title: '환경설정',
                  last: true,
                  onTap: () => taps.add('settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Finder inItem(String title, Finder finder) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(LobbyMenuItem),
    ),
    matching: finder,
  );

  testWidgets('the main entry has the lime block and the arrow chip', (
    tester,
  ) async {
    await show(tester);
    expect(
      tester
          .widgetList<ColoredBox>(inItem('게임 시작', find.byType(ColoredBox)))
          .map((box) => box.color),
      contains(AppColors.accent),
    );
    expect(inItem('게임 시작', find.byType(LobbyArrowChip)), findsOneWidget);
    expect(tester.widget<Text>(find.text('게임 시작')).style!.color, AppColors.ink);
    expect(
      tester.widget<LobbyTag>(inItem('게임 시작', find.byType(LobbyTag))).color,
      AppColors.textPrimary,
    );
  });

  testWidgets('the others end in a chevron, with no block', (tester) async {
    await show(tester);
    for (final title in ['기록보관소', '환경설정']) {
      expect(
        inItem(title, find.byIcon(Icons.chevron_right_rounded)),
        findsOneWidget,
      );
      expect(inItem(title, find.byType(LobbyArrowChip)), findsNothing);
      expect(
        tester
            .widgetList<ColoredBox>(inItem(title, find.byType(ColoredBox)))
            .map((box) => box.color),
        isNot(contains(AppColors.accent)),
      );
      expect(
        tester.widget<Text>(find.text(title)).style!.color,
        AppColors.textPrimary,
      );
    }
  });

  testWidgets('each entry has a line above, and the last less room below', (
    tester,
  ) async {
    await show(tester);
    Container boxOf(String title) =>
        tester.widget<Container>(inItem(title, find.byType(Container)).first);
    for (final title in ['게임 시작', '기록보관소', '환경설정']) {
      final border = (boxOf(title).decoration! as BoxDecoration).border!;
      expect((border as Border).top.color, AppColors.border);
    }
    expect((boxOf('기록보관소').padding! as EdgeInsets).bottom, AppSpacing.s16);
    expect((boxOf('환경설정').padding! as EdgeInsets).bottom, AppSpacing.s4);
  });

  testWidgets('tapping the tag, the title or the end opens the entry', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('01 / PLAY'));
    await tester.tap(find.text('기록보관소'));
    await tester.tap(inItem('환경설정', find.byIcon(Icons.chevron_right_rounded)));
    expect(taps, ['play', 'archive', 'settings']);
  });

  testWidgets('a screen reader hears the title as a button', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('게임 시작')),
      matchesSemantics(label: '게임 시작', isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel('01 / PLAY'), findsNothing);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('a narrow screen at a large text size shrinks the titles', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await show(tester, size: const Size(320, 900));
    expect(tester.takeException(), isNull);
  });
}
