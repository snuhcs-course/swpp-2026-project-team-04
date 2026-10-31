import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/game_danger_edge.dart';

Widget _edge(bool active, {bool animationsOff = false}) => MaterialApp(
  theme: AppTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: animationsOff),
    child: Scaffold(body: GameDangerEdge(active: active)),
  ),
);

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(GameDangerEdge),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  testWidgets('draws nothing while not active', (tester) async {
    await tester.pumpWidget(_edge(false));
    expect(
      find.descendant(
        of: find.byType(GameDangerEdge),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    // Times out if the flash runs unseen.
    await tester.pumpAndSettle();
  });

  testWidgets('a red edge flashes while active, slower than once a second', (
    tester,
  ) async {
    await tester.pumpWidget(_edge(true));
    final boxes = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GameDangerEdge),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration as BoxDecoration);
    final border = boxes.map((box) => box.border).nonNulls.single as Border;
    expect(border.top.color, AppColors.danger);
    final glows = boxes.map((box) => box.gradient).nonNulls.toList();
    expect(glows, hasLength(4));
    for (final glow in glows) {
      expect(glow.colors.first, AppColors.danger.withValues(alpha: 0.5));
      expect(glow.colors.last, AppColors.danger.withValues(alpha: 0));
    }

    final start = _opacity(tester);
    await tester.pump(const Duration(milliseconds: 350));
    final middle = _opacity(tester);
    await tester.pump(const Duration(milliseconds: 350));
    final end = _opacity(tester);
    expect(middle, greaterThan(start));
    expect(end, greaterThan(middle));
    await tester.pump(const Duration(milliseconds: 700));
    expect(_opacity(tester), closeTo(start, 0.01));
  });

  testWidgets('lights only the edge, fading inward; the middle stays clear', (
    tester,
  ) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: boundary,
            child: const GameDangerEdge(active: true),
          ),
        ),
      ),
    );
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(render.toImage))!;
    final bytes = (await tester.runAsync(image.toByteData))!;
    addTearDown(image.dispose);
    int alpha(int x, int y) => bytes.getUint8((y * image.width + x) * 4 + 3);

    final (middleX, middleY) = (image.width ~/ 2, image.height ~/ 2);
    expect(alpha(middleX, middleY), 0);
    expect(alpha(60, middleY), 0);
    expect(alpha(middleX, 60), 0);
    for (final (x, y) in [
      (2, middleY),
      (image.width - 3, middleY),
      (middleX, 2),
      (middleX, image.height - 3),
    ]) {
      expect(alpha(x, y), 255);
    }
    expect(alpha(10, middleY), greaterThan(alpha(30, middleY)));
    for (final (x, y) in [
      (30, middleY),
      (image.width - 31, middleY),
      (middleX, 30),
      (middleX, image.height - 31),
    ]) {
      expect(alpha(x, y), greaterThan(0));
    }
  });

  testWidgets('taps go through it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('tap'),
              ),
            ),
            const Positioned.fill(child: GameDangerEdge(active: true)),
          ],
        ),
      ),
    );
    await tester.tap(find.text('tap'));
    expect(taps, 1);
  });

  testWidgets('stops when it is no longer active', (tester) async {
    await tester.pumpWidget(_edge(true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_edge(false));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(GameDangerEdge),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('stays lit with the system animations off', (tester) async {
    await tester.pumpWidget(_edge(true, animationsOff: true));
    expect(_opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 350));
    expect(_opacity(tester), 1);
  });

  testWidgets('tells a screen reader', (tester) async {
    await tester.pumpWidget(_edge(true));
    expect(find.bySemanticsLabel('위험, 곧 질 수 있어요'), findsOneWidget);
  });
}
