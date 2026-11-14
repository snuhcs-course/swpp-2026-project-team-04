import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/lobby_menu_item.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';

void main() {
  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  final taps = <String>[];

  /// The four entries as home has them, at the design's width.
  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
                  onTap: () => taps.add('play'),
                ),
                LobbyMenuItem(
                  tag: '02 / CHARACTER',
                  title: '캐릭터',
                  onTap: () => taps.add('character'),
                ),
                LobbyMenuItem(
                  tag: '03 / ARCHIVE',
                  title: '기록보관소',
                  onTap: () => taps.add('archive'),
                ),
                LobbyMenuItem(
                  tag: '04 / SETTINGS',
                  title: '환경설정',
                  onTap: () => taps.add('settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  const titles = ['게임 시작', '캐릭터', '기록보관소', '환경설정'];

  Finder item(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(LobbyMenuItem));

  Finder inItem(String title, Finder finder) =>
      find.descendant(of: item(title), matching: finder);

  TextTheme textOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold))).textTheme;

  testWidgets('every entry looks the same: gray tag, ink title, gray '
      'chevron, no lime and no arrow chip (user, 2026-11-08)', (tester) async {
    await show(tester);
    final text = textOf(tester);
    for (final (tag, title) in [
      ('01 / PLAY', '게임 시작'),
      ('02 / CHARACTER', '캐릭터'),
      ('03 / ARCHIVE', '기록보관소'),
      ('04 / SETTINGS', '환경설정'),
    ]) {
      expect(
        tester.widget<Text>(find.text(tag)).style,
        text.lobbyMenuTag.copyWith(color: AppColors.textSecondary),
        reason: tag,
      );
      expect(
        tester.widget<Text>(find.text(title)).style,
        text.lobbyMenuTitle.copyWith(color: AppColors.textPrimary),
      );
      final chevron = tester.widget<Icon>(
        inItem(title, find.byIcon(Icons.chevron_right_rounded)),
      );
      expect(chevron.color, AppColors.line);
      expect(inItem(title, find.byType(LobbyArrowChip)), findsNothing);
      expect(inItem(title, find.byType(ColoredBox)), findsNothing);
    }
  });

  testWidgets('the design\'s 76 high row in token steps (2026-11-14): a line '
      'above, 8 over the tag, 4 to the title and 4 under it', (tester) async {
    await show(tester);
    final text = textOf(tester);
    // The design's sizes: an 11 tag on a 14 line, a 44 title on a 44 line.
    expect(text.lobbyMenuTag.fontSize, 11);
    expect(text.lobbyMenuTag.fontSize! * text.lobbyMenuTag.height!, 14);
    expect(text.lobbyMenuTag.letterSpacing, 3);
    expect(text.lobbyMenuTitle.fontSize, 44);
    expect(text.lobbyMenuTitle.height, 1);
    expect(text.lobbyMenuTitle.fontFamily, AppFonts.display);
    Container boxOf(String title) =>
        tester.widget<Container>(inItem(title, find.byType(Container)).first);
    for (final title in titles) {
      final border = (boxOf(title).decoration! as BoxDecoration).border!;
      expect((border as Border).top.color, AppColors.border);
      expect((border).top.width, 1);
      expect(
        boxOf(title).padding,
        const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s4),
      );
      // 1 + 8 + 14 + 4 + 44 + 4: the design's 3 and 6 are token steps.
      expect(tester.getSize(item(title)).height, LobbyMenuItem.height);
      // A 24 chevron in a 40 x 40 box.
      final chevron = inItem(title, find.byIcon(Icons.chevron_right_rounded));
      expect(tester.widget<Icon>(chevron).size, 24);
      expect(tester.getSize(chevron), const Size.square(40));
    }
    expect(LobbyMenuItem.height, 1 + 8 + 14 + 4 + 44 + 4);
  });

  testWidgets('a larger text size grows the tag but keeps the title\'s size', (
    tester,
  ) async {
    await show(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('게임 시작')).height, 44);
    expect(tester.getSize(find.text('01 / PLAY')).height, closeTo(14 * 1.3, 1));
    expect(
      tester.getSize(item('게임 시작')).height,
      greaterThan(LobbyMenuItem.height),
    );
  });

  testWidgets('tapping the tag, the title or the end opens the entry', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('01 / PLAY'));
    await tester.tap(find.text('캐릭터'));
    await tester.tap(find.text('기록보관소'));
    await tester.tap(inItem('환경설정', find.byIcon(Icons.chevron_right_rounded)));
    expect(taps, ['play', 'character', 'archive', 'settings']);
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
    await show(tester, size: const Size(320, 900), textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
