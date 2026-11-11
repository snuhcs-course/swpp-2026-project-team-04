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

  group('LobbyPage.fill', () {
    LobbyPage page({double above = 100, double below = 100}) => LobbyPage.fill(
      above: [SizedBox(height: above)],
      fill: const SizedBox.expand(key: Key('fill')),
      fillMinHeight: 100,
      below: [
        SizedBox(
          height: below,
          child: const Align(
            alignment: Alignment.bottomLeft,
            child: Text('bottom'),
          ),
        ),
      ],
    );
    double fillHeight(WidgetTester tester) =>
        tester.getSize(find.byKey(const Key('fill'))).height;
    double scrollRoom(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .maxScrollExtent;

    testWidgets('the fill takes the height left on the screen', (tester) async {
      await show(tester, page());
      // 780 less the two boxes and the page's top and bottom padding.
      expect(fillHeight(tester), 780 - 200 - AppSpacing.s4 - AppSpacing.s24);
      expect(scrollRoom(tester), 0);
    });

    testWidgets('the system bars are left out of the room', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
      await show(tester, page());
      expect(
        fillHeight(tester),
        780 - 24 - 48 - 200 - AppSpacing.s4 - AppSpacing.s24,
      );
      expect(scrollRoom(tester), 0);
    });

    testWidgets('scrolls only when the fill at its least does not fit', (
      tester,
    ) async {
      await show(tester, page(above: 400, below: 300));
      expect(tester.takeException(), isNull);
      expect(fillHeight(tester), 100);
      // 400 + 100 + 300 and the padding, on a 780-tall screen.
      expect(
        scrollRoom(tester),
        closeTo(800 + AppSpacing.s4 + AppSpacing.s24 - 780, 0.01),
      );
      expect(find.text('bottom').hitTestable(), findsNothing);
      await tester.drag(find.byType(Scrollable), const Offset(0, -200));
      await tester.pump();
      expect(find.text('bottom').hitTestable(), findsOneWidget);
    });

    testWidgets('a page that fits has no scroll room, even with fractions', (
      tester,
    ) async {
      // Heights that do not add up exactly in floating point.
      await show(
        tester,
        page(above: 100.1, below: 200.1),
        size: const Size(400, 914.2857),
      );
      expect(scrollRoom(tester), 0);
    });
  });

  group('LobbyFillColumn', () {
    /// The column, 300 wide and at least [least] tall, at the top left.
    Future<void> column(
      WidgetTester tester, {
      List<Widget> above = const [SizedBox(height: 100)],
      double fillMinHeight = 50,
      List<Widget> below = const [SizedBox(height: 120)],
      double least = 500,
    }) => show(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: least),
            child: LobbyFillColumn(
              above: above,
              fill: const SizedBox.expand(key: Key('fill')),
              fillMinHeight: fillMinHeight,
              below: below,
            ),
          ),
        ),
      ),
    );
    Rect fill(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('fill')));
    RenderBox box(WidgetTester tester) =>
        tester.renderObject<RenderBox>(find.byType(LobbyFillColumn));

    testWidgets('puts the fill between the others, with the room left', (
      tester,
    ) async {
      await column(tester);
      expect(fill(tester), const Rect.fromLTWH(0, 100, 300, 280));
      expect(box(tester).size, const Size(300, 500));
    });

    testWidgets('the fill keeps its least height; the column grows past', (
      tester,
    ) async {
      await column(tester, least: 200);
      expect(fill(tester).height, 50);
      expect(box(tester).size.height, 100 + 50 + 120);
    });

    testWidgets('a FittedBox that shrinks gives its saved room to the fill', (
      tester,
    ) async {
      // 600 × 100 shrunk into 300 wide is 50 tall; IntrinsicHeight would
      // still count 100.
      await column(
        tester,
        above: const [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: 600, height: 100),
          ),
        ],
      );
      expect(fill(tester).top, 50);
      expect(fill(tester).height, 500 - 50 - 120);
    });

    testWidgets('a tap reaches the child where it is drawn', (tester) async {
      var taps = 0;
      await column(
        tester,
        below: [
          SizedBox(
            height: 120,
            child: TextButton(onPressed: () => taps++, child: const Text('go')),
          ),
        ],
      );
      expect(tester.getTopLeft(find.byType(TextButton)).dy, 100 + 280);
      await tester.tap(find.text('go'));
      expect(taps, 1);
    });

    testWidgets('a new least fill height lays it out again', (tester) async {
      await column(tester, least: 200);
      expect(fill(tester).height, 50);
      await column(tester, least: 200, fillMinHeight: 90);
      expect(fill(tester).height, 90);
    });

    testWidgets('more children above move the fill down and shrink it', (
      tester,
    ) async {
      // Like home's unsent note appearing above RepBot after a reload.
      await column(tester);
      expect(fill(tester), const Rect.fromLTWH(0, 100, 300, 280));
      await column(
        tester,
        above: const [
          SizedBox(height: 100),
          SizedBox(height: 8),
          SizedBox(height: 40),
        ],
      );
      expect(fill(tester), const Rect.fromLTWH(0, 148, 300, 232));
      await column(tester);
      expect(fill(tester), const Rect.fromLTWH(0, 100, 300, 280));
    });

    testWidgets('its dry layout matches its layout', (tester) async {
      await column(tester);
      const constraints = BoxConstraints(
        minWidth: 300,
        maxWidth: 300,
        minHeight: 200,
      );
      expect(box(tester).getDryLayout(constraints), const Size(300, 270));
      expect(
        box(tester).getDryLayout(constraints.copyWith(minHeight: 500)),
        const Size(300, 500),
      );
    });

    testWidgets('its intrinsic size counts the fill at its least', (
      tester,
    ) async {
      await column(
        tester,
        above: const [SizedBox(width: 80, height: 100)],
        below: const [SizedBox(width: 120, height: 120)],
      );
      final render = box(tester);
      expect(render.getMinIntrinsicHeight(300), 100 + 50 + 120);
      expect(render.getMaxIntrinsicHeight(300), 100 + 50 + 120);
      // SizedBox.expand asks for no width of its own.
      expect(render.getMinIntrinsicWidth(double.infinity), 120);
      expect(render.getMaxIntrinsicWidth(double.infinity), 120);
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

  testWidgets('LobbyArrowChip is a square of its color with an ink edge and '
      'an ink arrow', (tester) async {
    await show(
      tester,
      const Center(child: LobbyArrowChip(color: AppColors.opponent, size: 48)),
    );
    expect(tester.getSize(find.byType(LobbyArrowChip)), const Size(48, 48));
    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.opponent);
    expect((decoration.border! as Border).top.color, AppColors.ink);
    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_forward_rounded));
    expect(icon.color, AppColors.ink);
    expect(icon.size, 24);
  });

  testWidgets('LobbySquareButton draws its icon in the line gray', (
    tester,
  ) async {
    await show(
      tester,
      Scaffold(
        body: Center(
          child: LobbySquareButton(
            icon: Icons.help_outline_rounded,
            tooltip: '게임 규칙',
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).color,
      AppColors.line,
    );
  });
}
