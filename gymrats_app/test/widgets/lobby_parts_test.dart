import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(360, 780),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: child));
  }

  testWidgets('LobbySkew slants like italics about the corner it keeps', (
    tester,
  ) async {
    await show(
      tester,
      const Center(
        child: LobbySkew(degrees: 10, child: SizedBox(width: 10, height: 10)),
      ),
    );
    final transform = tester.widget<Transform>(find.byType(Transform));
    expect(transform.alignment, Alignment.bottomLeft);
    // x moves by -tan(10°) per unit of y: the top leans right.
    expect(
      transform.transform.entry(0, 1),
      closeTo(math.tan(-10 * math.pi / 180), 1e-12),
    );
  });

  group('LobbyPage', () {
    testWidgets('an Expanded child takes the room left', (tester) async {
      await show(
        tester,
        const LobbyPage(
          children: [
            SizedBox(height: 100),
            Expanded(child: SizedBox.expand(key: Key('room'))),
            SizedBox(height: 100),
          ],
        ),
      );
      // 780 less the two boxes and the page's top and bottom padding.
      expect(
        tester.getSize(find.byKey(const Key('room'))).height,
        780 - 200 - AppSpacing.s4 - AppSpacing.s24,
      );
      expect(tester.getSize(find.byKey(const Key('room'))).width, 320);
    });

    testWidgets('scrolls when the children are taller than the screen', (
      tester,
    ) async {
      await show(
        tester,
        const LobbyPage(
          children: [
            SizedBox(height: 600),
            Expanded(child: SizedBox.expand()),
            SizedBox(height: 600, child: Text('bottom')),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('bottom').hitTestable(), findsNothing);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pump();
      expect(find.text('bottom').hitTestable(), findsOneWidget);
    });

    testWidgets('puts what goes behind under the content', (tester) async {
      await show(
        tester,
        const LobbyPage(behind: LobbyBackdrop(), children: [Text('content')]),
      );
      final stack = tester.widget<Stack>(
        find
            .ancestor(of: find.text('content'), matching: find.byType(Stack))
            .first,
      );
      expect(stack.children.first, isA<LobbyBackdrop>());
    });
  });

  testWidgets('LobbyBackdrop paints a lighter and a darker facet', (
    tester,
  ) async {
    await show(tester, const Stack(children: [LobbyBackdrop()]));
    expect(
      find.descendant(
        of: find.byType(LobbyBackdrop),
        matching: find.byType(CustomPaint),
      ),
      paints
        ..path(color: AppColors.facetLight)
        ..path(color: AppColors.facetDark),
    );
  });

  testWidgets('LobbyWatermark runs off the right edge, unread', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(
      tester,
      const Stack(children: [LobbyWatermark('PLAY', left: 150)]),
    );
    // Where the slanted word's box sits, before the slant.
    expect(tester.getTopLeft(find.byType(LobbySkew)), const Offset(150, 62));
    expect(find.bySemanticsLabel('PLAY'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  group('LobbySquareButton', () {
    testWidgets('shows 44 points, takes taps on 48, and says its name', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await show(
        tester,
        Scaffold(
          body: Center(
            child: LobbySquareButton(
              icon: Icons.help_outline_rounded,
              tooltip: '게임 규칙',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(LobbySquareButton)),
        const Size(48, 48),
      );
      final shown = find.descendant(
        of: find.byType(LobbySquareButton),
        matching: find.byType(Material),
      );
      expect(tester.getSize(shown.first), const Size(44, 44));
      await tester.tap(find.byTooltip('게임 규칙'));
      expect(taps, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  testWidgets('LobbyTag is gray unless given a color', (tester) async {
    await show(
      tester,
      const Column(
        children: [
          LobbyTag('02 / ARCHIVE'),
          LobbyTag('01 / PLAY', color: AppColors.accent),
        ],
      ),
    );
    Color? colorOf(String text) =>
        tester.widget<Text>(find.text(text)).style!.color;
    expect(colorOf('02 / ARCHIVE'), AppColors.textSecondary);
    expect(colorOf('01 / PLAY'), AppColors.accent);
  });

  group('LobbyPageHeader', () {
    testWidgets('back closes the page; the title is a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: LobbyPageHeader(tag: '01 / PLAY', title: '게임 시작'),
                ),
              ),
            ),
            child: const Text('below'),
          ),
        ),
      );
      await tester.tap(find.text('below'));
      await tester.pumpAndSettle();
      expect(find.text('01 / PLAY'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('게임 시작')),
        matchesSemantics(label: '게임 시작', isHeader: true),
      );
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('게임 시작'), findsNothing);
      expect(find.text('below'), findsOneWidget);
      semantics.dispose();
    });
  });

  testWidgets('LobbyArrowChip is an ink square with the icon in its color', (
    tester,
  ) async {
    await show(
      tester,
      const Center(child: LobbyArrowChip(color: AppColors.opponent, size: 48)),
    );
    expect(tester.getSize(find.byType(LobbyArrowChip)), const Size(48, 48));
    final box = tester.widget<Container>(find.byType(Container));
    expect((box.decoration! as BoxDecoration).color, AppColors.ink);
    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_forward_rounded));
    expect(icon.color, AppColors.opponent);
    expect(icon.size, 24);
  });
}
