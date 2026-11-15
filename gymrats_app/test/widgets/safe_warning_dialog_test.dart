import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/safe_warning_dialog.dart';

import 'battle_test_support.dart';

void main() {
  bool? seen;

  /// A page whose 'ask' button shows the warning and keeps its answer.
  Future<void> open(
    WidgetTester tester, {
    Duration? autoClose,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    seen = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  seen = await showSafeWarning(context, autoClose: autoClose),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsOneWidget);
  }

  final button = find.descendant(
    of: find.byType(SafeWarningDialog),
    matching: find.byType(FilledButton),
  );

  /// The drawn picture.
  final picture = find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint && widget.painter is SafeWarningPicturePainter,
  );

  testWidgets('the picture on a lighter box, then 무리하지 마세요, the message '
      'and a lime 확인', (tester) async {
    await open(tester);
    // Drawn, not an image file: the old one was white lines for the dark
    // theme and vanished on the light box.
    expect(picture, findsOneWidget);
    expect(tester.getSize(picture), const Size(240, 150));
    expect(
      find.descendant(
        of: find.byType(SafeWarningDialog),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(SafeWarningDialog.pictureLabel),
      findsOneWidget,
    );
    final box = tester.widget<DecoratedBox>(
      find.ancestor(of: picture, matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as BoxDecoration).color, AppColors.cardHigh);
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      AppColors.card,
    );

    final theme = Theme.of(tester.element(find.byType(SafeWarningDialog)));
    expect(
      tester.widget<Text>(find.text('무리하지 마세요')).style,
      theme.textTheme.headlineSmall,
    );
    final message = find.text('무리해서 운동하면 몸을 다칠 수 있어요.\n몸 상태를 살피며 플레이해 주세요.');
    expect(tester.widget<Text>(message).style!.color, AppColors.textSecondary);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('확인을 누르면 자세 세팅을 시작할 수 있어요'), findsOneWidget);
    // FilledButton paints with the theme's primary, the lime accent, here
    // with an ink edge (palette B).
    expect(theme.colorScheme.primary, AppColors.accent);
    final ok = tester.widget<FilledButton>(
      find.ancestor(of: find.text('확인'), matching: find.byType(FilledButton)),
    );
    expect(
      (ok.style!.shape!.resolve({})! as RoundedRectangleBorder).side,
      const BorderSide(color: AppColors.ink, width: 2),
    );

    // Top to bottom: picture, title, message, button, note.
    final order = [
      picture,
      find.text('무리하지 마세요'),
      message,
      button,
      find.text('확인을 누르면 자세 세팅을 시작할 수 있어요'),
    ].map((f) => tester.getRect(f).top).toList();
    expect(order, orderedEquals([...order]..sort()));
  });

  testWidgets('확인 closes it and answers true', (tester) async {
    await open(tester);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsNothing);
    expect(seen, isTrue);
  });

  testWidgets('back closes it and answers false', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsNothing);
    expect(seen, isFalse);
  });

  testWidgets('removed some other way it answers null', (tester) async {
    await open(tester, autoClose: const Duration(seconds: 5));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsNothing);
    expect(seen, isNull);
    // Its countdown went with it.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('ask'), findsOneWidget);
  });

  testWidgets('a tap outside keeps it open', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsOneWidget);
    expect(seen, isNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
  });

  testWidgets('with autoClose it counts down each second and closes itself '
      'with true', (tester) async {
    await open(tester, autoClose: const Duration(seconds: 3));
    expect(find.text('확인 (3)'), findsOneWidget);
    expect(find.text('3초 뒤 자동으로 닫혀요'), findsOneWidget);
    expect(find.text('확인을 누르면 자세 세팅을 시작할 수 있어요'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('확인 (2)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('확인 (1)'), findsOneWidget);
    expect(find.text('1초 뒤 자동으로 닫혀요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsNothing);
    expect(seen, isTrue);
  });

  testWidgets('확인 during the countdown answers once and stops it', (
    tester,
  ) async {
    await open(tester, autoClose: const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(seen, isTrue);
    // Had the countdown kept going, it would pop the page under it.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('ask'), findsOneWidget);
  });

  testWidgets('back during the countdown answers false and stops it', (
    tester,
  ) async {
    await open(tester, autoClose: const Duration(seconds: 5));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(seen, isFalse);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('ask'), findsOneWidget);
  });

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} without '
        'overflow', (tester) async {
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      // The card, not the Dialog widget, which spans the whole screen.
      final card = tester.getRect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(card.width, lessThanOrEqualTo(360));
      // On a short screen it scrolls; 확인 is reachable at the bottom.
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(seen, isTrue);
    });
  }

  group("the picture is the design's SVG (BMatchFound.dc.html)", () {
    const painter = SafeWarningPicturePainter();

    test('its numbers are the SVG\'s, element by element', () {
      expect(SafeWarningPicturePainter.size, const Size(240, 150));
      expect(SafeWarningPicturePainter.floor, (
        start: const Offset(16, 132),
        end: const Offset(224, 132),
      ));
      expect(SafeWarningPicturePainter.floorWidth, 4);
      expect(SafeWarningPicturePainter.body, const [
        Offset(80, 100),
        Offset(150, 112),
        Offset(206, 127),
      ]);
      expect(SafeWarningPicturePainter.bodyWidth, 9);
      expect(SafeWarningPicturePainter.arm, const [
        Offset(84, 102),
        Offset(104, 116),
        Offset(86, 128),
      ]);
      expect(SafeWarningPicturePainter.armWidth, 7);
      expect(SafeWarningPicturePainter.head, (
        center: const Offset(60, 92),
        radius: 13.0,
      ));
      expect(SafeWarningPicturePainter.headEdge, 3);
      // `M42 60 q5 7 0 11 q-5 -4 0 -11 z`, `M30 74 q4 6 0 9 q-4 -3 0 -9 z`.
      expect(SafeWarningPicturePainter.drops, const [
        (
          top: Offset(42, 60),
          right: Offset(42 + 5, 60 + 7),
          bottom: Offset(42, 60 + 11),
          left: Offset(42 - 5, 71 - 4),
        ),
        (
          top: Offset(30, 74),
          right: Offset(30 + 4, 74 + 6),
          bottom: Offset(30, 74 + 9),
          left: Offset(30 - 4, 83 - 3),
        ),
      ]);
      expect(SafeWarningPicturePainter.star, const [
        Offset(106, 95),
        Offset(109, 104.8),
        Offset(119, 102.5),
        Offset(112, 110),
        Offset(119, 117.5),
        Offset(109, 115.2),
        Offset(106, 125),
        Offset(103, 115.2),
        Offset(93, 117.5),
        Offset(100, 110),
        Offset(93, 102.5),
        Offset(103, 104.8),
      ]);
      expect(SafeWarningPicturePainter.starEdge, 1.5);
    });

    test('it draws them in the SVG\'s order, colors and widths', () {
      final ops = paintedOps(painter, const Size(240, 150));
      // The star's outline: its 12 sides.
      final star = SafeWarningPicturePainter.star;
      var perimeter = 0.0;
      for (var i = 0; i < star.length; i++) {
        perimeter += (star[(i + 1) % star.length] - star[i]).distance;
      }
      final starPath =
          'path(rect(93.000, 95.000, 119.000, 125.000), length '
          '${perimeter.toStringAsFixed(1)}, 1 parts)';
      expect(ops.first, 'save()');
      expect(ops[1], 'translate(0.000, 0.000)');
      expect(ops[2], 'scale(1.000, 1.000)');
      expect(
        ops[3],
        'drawLine((16.000, 132.000), (224.000, 132.000), '
        'stroke #FF586073 4.000 round miter)',
      );
      // 70 x 12 and 56 x 15 long: 71.0 + 58.0.
      expect(
        ops[4],
        'drawPath(path(rect(80.000, 100.000, 206.000, 127.000), '
        'length 129.0, 1 parts), stroke #FF586073 9.000 round round)',
      );
      // 20 x 14 and 18 x 12 long: 24.4 + 21.6.
      expect(
        ops[5],
        'drawPath(path(rect(84.000, 102.000, 104.000, 128.000), '
        'length 46.0, 1 parts), stroke #FF586073 7.000 round round)',
      );
      expect(ops[6], 'drawCircle((60.000, 92.000), 13.000, fill #FFFFFFFF)');
      expect(
        ops[7],
        'drawCircle((60.000, 92.000), 13.000, '
        'stroke #FF586073 3.000 butt miter)',
      );
      for (final drop in [ops[8], ops[9]]) {
        expect(drop, startsWith('drawPath(path('));
        expect(drop, endsWith('fill #FF586073)'));
      }
      expect(ops[10], 'drawPath($starPath, fill #FFFFB547)');
      expect(ops[11], 'drawPath($starPath, stroke #FF141A26 1.500 butt round)');
      expect(ops[12], 'restore()');
      expect(ops, hasLength(13));
      // The tokens behind those colors.
      expect(AppColors.line, const Color(0xFF586073));
      expect(AppColors.warning, const Color(0xFFFFB547));
      expect(AppColors.ink, const Color(0xFF141A26));
      expect(AppColors.card, const Color(0xFFFFFFFF));
    });

    test('a drop curves out to its control points, not past them', () {
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(240, 150));
      final drops = [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawPath)
            call.invocation.positionalArguments.first as Path,
      ].sublist(2, 4);
      // Drop 1: x 37..47 control box, the curve reaches 39.5..44.5.
      expect(drops[0].contains(const Offset(42, 66)), isTrue);
      expect(drops[0].contains(const Offset(44, 66)), isTrue);
      expect(drops[0].contains(const Offset(46, 67)), isFalse);
      expect(drops[0].contains(const Offset(42, 59)), isFalse);
      expect(drops[0].contains(const Offset(42, 72)), isFalse);
      // Drop 2: x 26..34, the curve reaches 28..32.
      expect(drops[1].contains(const Offset(30, 79)), isTrue);
      expect(drops[1].contains(const Offset(31.5, 79)), isTrue);
      expect(drops[1].contains(const Offset(33, 80)), isFalse);
      expect(drops[1].contains(const Offset(30, 84)), isFalse);
    });

    test('a box of another size scales it the same both ways, as large as '
        'fits, in the middle, as an SVG view box does', () {
      expect(paintedOps(painter, const Size(480, 300)).sublist(1, 3), [
        'translate(0.000, 0.000)',
        'scale(2.000, 2.000)',
      ]);
      // The dialog on a 360-wide phone: 232 wide.
      expect(paintedOps(painter, const Size(232, 150)).sublist(1, 3), [
        'translate(0.000, 2.500)',
        'scale(0.967, 0.967)',
      ]);
      expect(paintedOps(painter, const Size(300, 150)).sublist(1, 3), [
        'translate(30.000, 0.000)',
        'scale(1.000, 1.000)',
      ]);
    });

    testWidgets('on a 360-wide phone the dialog gives it 232 x 150, and it '
        'is scaled the same both ways', (tester) async {
      await open(tester, size: const Size(360, 780));
      final box = tester.getSize(picture);
      expect(box, const Size(232, 150));
      final ops = paintedOps(painter, box);
      expect(ops.sublist(1, 3), [
        'translate(0.000, 2.500)',
        'scale(0.967, 0.967)',
      ]);
    });

    testWidgets('in that 232 x 150 box the head is drawn where the one '
        'scale puts it', (tester) async {
      const box = Size(232, 150);
      final painted = await paintPicture(
        tester,
        const CustomPaint(size: box, painter: painter),
        size: box,
        ground: AppColors.cardHigh,
      );
      const s = 232 / 240;
      const top = (150 - 150 * s) / 2;
      Offset at(double x, double y) => Offset(x * s, top + y * s);
      // The middle of the edge, 13 up, down, left and right of the centre
      // (the scale and translate tests above are what catch a squeeze).
      for (final edge in [at(60, 79), at(47, 92), at(73, 92), at(60, 105)]) {
        expect(painted.at(edge.dx, edge.dy), AppColors.line, reason: '$edge');
      }
      expect(painted.at(at(60, 92).dx, at(60, 92).dy), AppColors.card);
    });

    testWidgets('on the light box: gray lines, a white head with a gray '
        'edge, an amber star with an ink edge', (tester) async {
      final painted = await paintPicture(
        tester,
        const CustomPaint(size: Size(240, 150), painter: painter),
        size: const Size(240, 150),
        ground: AppColors.cardHigh,
      );
      for (final (x, y) in const [
        (120.0, 132.0), // the floor
        (180.0, 120.0), // the body, clear of the star
        (92.0, 124.0), // the arm's lower part, clear of the star
        (42.0, 66.0), // a drop
        (30.0, 79.0), // the other
        (60.0, 79.0), // the head's edge
      ]) {
        expect(painted.at(x, y), AppColors.line, reason: '($x, $y)');
      }
      expect(painted.at(60, 92), AppColors.card);
      expect(painted.at(106, 110), AppColors.warning);
      // The ink edge between two of the star's corners, (109, 104.8) and
      // (119, 102.5): the darkest pixel across it is near ink.
      final across = [
        for (var y = 101.0; y <= 106; y++)
          painted.at(114, y).computeLuminance(),
      ];
      expect(across.reduce(math.min), lessThan(0.1));
      expect(AppColors.ink.computeLuminance(), lessThan(0.1));
      expect(painted.at(200, 40), AppColors.cardHigh);
    });

    test('the gray lines stand out from the light box (3 : 1 or more)', () {
      double contrast(Color a, Color b) {
        final (x, y) = (a.computeLuminance(), b.computeLuminance());
        return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
      }

      expect(
        contrast(AppColors.line, AppColors.cardHigh),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrast(AppColors.ink, AppColors.warning),
        greaterThanOrEqualTo(3),
      );
    });
  });

  // Last in the file: the fonts stay loaded for the rest of the run.
  group('with the real fonts', () {
    const message = '무리해서 운동하면 몸을 다칠 수 있어요.\n몸 상태를 살피며 플레이해 주세요.';
    const note = '확인을 누르면 자세 세팅을 시작할 수 있어요';
    // Laid-out height over one line's height, at the text size in use.
    int lines(WidgetTester tester, String text) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      final style = tester.widget<Text>(find.text(text)).style!;
      final line = paragraph.textScaler.scale(style.fontSize!) * style.height!;
      final count = paragraph.size.height / line;
      expect(count, moreOrLessEquals(count.roundToDouble(), epsilon: 0.1));
      return count.round();
    }

    // Shown width over laid-out width: below 1 when the text is shrunk.
    double shown(WidgetTester tester, String text) =>
        tester.getRect(find.text(text)).width /
        tester.getSize(find.text(text)).width;
    Rect card(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(SingleChildScrollView),
      ),
    );

    for (final size in const [Size(360, 640), Size(360, 780), Size(412, 915)]) {
      testWidgets('at ${size.width.toInt()}x${size.height.toInt()} the '
          'message keeps its two lines and the note its one, shrunk at most '
          'a little', (tester) async {
        await tester.runAsync(loadBattleFonts);
        await open(tester, size: size);
        expect(lines(tester, message), 2);
        expect(lines(tester, note), 1);
        for (final text in [message, note]) {
          expect(shown(tester, text), inInclusiveRange(0.9, 1));
          final rect = tester.getRect(find.text(text));
          expect(rect.left, greaterThanOrEqualTo(card(tester).left));
          expect(rect.right, lessThanOrEqualTo(card(tester).right));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('at text scale 2 the lines wrap at the size asked for', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(loadBattleFonts);
      await open(tester, size: const Size(360, 780));
      for (final text in [message, note]) {
        expect(
          find.ancestor(of: find.text(text), matching: find.byType(FittedBox)),
          findsNothing,
        );
        expect(shown(tester, text), 1);
      }
      expect(lines(tester, message), greaterThan(2));
      expect(lines(tester, note), greaterThan(1));
      expect(tester.takeException(), isNull);
    });
  });
}
