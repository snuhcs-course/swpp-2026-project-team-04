import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/widgets/lobby_rep_bot.dart';

/// What the design's RepBot draws at s = 0, 0.5 and 1: its own code run with
/// s fixed, printed as it prints them (one decimal). The bars in its drawing
/// order, then the head's move.
final _designed = <double, List<String>>{
  0.0: [
    'footL M301.6 207.5 L310.3 217.2',
    'footR M332.0 213.2 L340.2 223.1',
    'shinL M258.8 194.6 L301.6 207.5',
    'shinR M295.2 201.3 L332.0 213.2',
    'thighL M201.8 177.7 L258.8 194.6',
    'thighR M248.9 186.0 L295.2 201.3',
    'pelvis M201.8 177.7 L248.9 186.0',
    'handL M109.9 287.8 L91.2 299.2',
    'farmL M106.3 223.5 L109.9 287.8',
    'torso M145.5 157.0 L224.8 181.7',
    'uarmL M106.9 150.7 L106.3 223.5',
    'handR M206.2 319.3 L192.4 334.5',
    'farmR M200.3 247.2 L206.2 319.3',
    'shoulders M106.9 150.7 L187.9 164.0',
    'uarmR M187.9 164.0 L200.3 247.2',
    'neck M125.7 145.1 L97.6 129.9',
    'visor M62.3 119.5 L89.2 123.1',
    'headT translate(0.0 0.0)',
  ],
  0.5: [
    'footL M301.6 207.5 L310.3 217.2',
    'footR M332.0 213.2 L340.2 223.1',
    'shinL M257.0 207.6 L301.6 207.5',
    'shinR M293.3 214.8 L332.0 213.2',
    'thighL M198.0 207.3 L257.0 207.6',
    'thighR M244.7 217.1 L293.3 214.8',
    'pelvis M198.0 207.3 L244.7 217.1',
    'handL M109.9 287.8 L91.2 299.2',
    'farmL M100.3 225.0 L109.9 287.8',
    'torso M138.6 213.4 L220.8 212.1',
    'uarmL M100.6 204.7 L100.3 225.0',
    'handR M206.2 319.3 L192.4 334.5',
    'farmR M228.8 258.0 L206.2 319.3',
    'shoulders M100.6 204.7 L180.4 223.1',
    'uarmR M180.4 223.1 L228.8 258.0',
    'neck M118.2 208.1 L89.0 199.3',
    'visor M53.9 190.6 L80.3 196.5',
    'headT translate(-8.6 69.4)',
  ],
  1.0: [
    'footL M301.6 207.5 L310.3 217.2',
    'footR M332.0 213.2 L340.2 223.1',
    'shinL M255.2 220.6 L301.6 207.5',
    'shinR M291.3 228.2 L332.0 213.2',
    'thighL M194.2 237.0 L255.2 220.6',
    'thighR M240.4 248.2 L291.3 228.2',
    'pelvis M194.2 237.0 L240.4 248.2',
    'handL M109.9 287.8 L91.2 299.2',
    'farmL M94.3 226.5 L109.9 287.8',
    'torso M131.7 269.8 L216.7 242.5',
    'uarmL M94.3 258.7 L94.3 226.5',
    'handR M206.2 319.3 L192.4 334.5',
    'farmR M257.2 268.8 L206.2 319.3',
    'shoulders M94.3 258.7 L172.8 282.1',
    'uarmR M172.8 282.1 L257.2 268.8',
    'neck M110.7 271.0 L80.5 268.7',
    'visor M45.5 261.6 L71.3 269.9',
    'headT translate(-17.1 138.8)',
  ],
};

/// The pose at [depth] written like [_designed].
List<String> _drawn(double depth) {
  String n(double value) => value.toStringAsFixed(1);
  final head = RepBotPainter.headShiftAt(depth);
  return [
    for (final bar in RepBotPainter.bars)
      if (bar.endsAt(depth) case (final a, final b))
        '${bar.name} M${n(a.dx)} ${n(a.dy)} L${n(b.dx)} ${n(b.dy)}',
    'headT translate(${n(head.dx)} ${n(head.dy)})',
  ];
}

/// The design's s at [ms] milliseconds after it appeared, from its formula.
double _designedDepth(int ms) =>
    (1 - math.cos(2 * math.pi * ((ms + 600) % 2000) / 2000)) / 2;

RepBotPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(LobbyRepBot),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as RepBotPainter;

void main() {
  group('the pose matches the design', () {
    test('17 bars in the design\'s drawing order, the visor last', () {
      expect(RepBotPainter.bars, hasLength(17));
      expect(RepBotPainter.bars.last, same(RepBotPainter.visor));
      expect(RepBotPainter.limbs.every((bar) => bar.shine != null), isTrue);
      expect(RepBotPainter.visor.shine, isNull);
    });

    for (final depth in _designed.keys) {
      test('at s = $depth, every bar end and the head to one decimal', () {
        expect(_drawn(depth), _designed[depth]);
      });
    }
  });

  group('the timing matches the design', () {
    test('one push-up takes 2000 ms and starts 600 ms in', () {
      expect(RepBotMotion.period, const Duration(milliseconds: 2000));
      expect(RepBotMotion.startOffset, const Duration(milliseconds: 600));
    });

    test('s = (1 - cos(2π·t/2000)) / 2 at every 50 ms over two push-ups', () {
      for (var ms = 0; ms <= 4000; ms += 50) {
        expect(
          RepBotMotion.depthAt(Duration(milliseconds: ms)),
          closeTo(_designedDepth(ms), 1e-9),
          reason: '$ms ms',
        );
      }
    });

    test('it appears on the way down, then reaches the bottom and the top', () {
      double at(int ms) => RepBotMotion.depthAt(Duration(milliseconds: ms));
      expect(at(0), closeTo(0.6545, 1e-4));
      expect(at(400), closeTo(1, 1e-9));
      expect(at(900), closeTo(0.5, 1e-9));
      expect(at(1400), closeTo(0, 1e-9));
      expect(at(3400), closeTo(0, 1e-9));
    });
  });

  group('LobbyRepBot', () {
    Future<void> open(WidgetTester tester, {bool still = false}) =>
        tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(disableAnimations: still),
              child: const Center(child: LobbyRepBot()),
            ),
          ),
        );

    testWidgets('keeps doing push-ups on the design\'s clock', (tester) async {
      await open(tester);
      expect(_painter(tester).depth, closeTo(_designedDepth(0), 1e-9));

      await tester.pump(const Duration(milliseconds: 400));
      expect(_painter(tester).depth, closeTo(1, 1e-6));

      await tester.pump(const Duration(milliseconds: 1000));
      expect(_painter(tester).depth, closeTo(0, 1e-6));

      // A whole push-up later it is back where it was.
      await tester.pump(RepBotMotion.period);
      expect(_painter(tester).depth, closeTo(0, 1e-6));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('holds the top pose with reduced motion', (tester) async {
      await open(tester, still: true);
      expect(_painter(tester).depth, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).depth, 0);
    });

    testWidgets('stops when reduced motion turns on, and goes on after', (
      tester,
    ) async {
      await open(tester);
      await open(tester, still: true);
      expect(_painter(tester).depth, 0);
      // The frame the last tick asked for, then no more.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await open(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('repaints on its own, not the screen around it', (
      tester,
    ) async {
      await open(tester, still: true);
      expect(
        find.descendant(
          of: find.byType(LobbyRepBot),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
    });

    testWidgets('takes the design\'s slot and tells a screen reader', (
      tester,
    ) async {
      await open(tester, still: true);
      expect(tester.getSize(find.byType(LobbyRepBot)), LobbyRepBot.designSize);
      expect(find.bySemanticsLabel('RepBot이 쉬지 않고 푸쉬업하는 모습'), findsOneWidget);
    });
  });

  group('RepBotPainter', () {
    test('repaints only for a new depth', () {
      const top = RepBotPainter(depth: 0);
      expect(top.shouldRepaint(const RepBotPainter(depth: 0)), isFalse);
      expect(top.shouldRepaint(const RepBotPainter(depth: 0.5)), isTrue);
    });

    testWidgets('draws the floor, the glow, the outline, then the body', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: CustomPaint(
            size: LobbyRepBot.designSize,
            painter: RepBotPainter(depth: 1),
          ),
        ),
      );
      final bars = RepBotPainter.bars.length;
      final limbs = RepBotPainter.limbs.length;
      // The first bar, [grow] wider on each side.
      bool firstBar(Symbol method, List<dynamic> arguments, double grow) =>
          method == #drawLine &&
          ((arguments[2] as Paint).strokeWidth -
                      (RepBotPainter.bars.first.width + 2 * grow))
                  .abs() <
              1e-3;
      expect(
        find.byType(CustomPaint),
        paints
          // The pink light and the shadow on the floor.
          ..circle()
          ..circle()
          // The glow: every bar and the head grown by 5, in a blurred layer.
          // Bounded to the design's filter region.
          ..something(
            (method, arguments) =>
                method == #saveLayer &&
                arguments[0] == const Rect.fromLTWH(-20, 30, 440, 380),
          )
          ..something((method, arguments) => firstBar(method, arguments, 5))
          ..something((method, _) => method == #restore)
          // The outline: every bar and the head grown by 1.6.
          ..something((method, arguments) => firstBar(method, arguments, 1.6))
          // The body itself.
          ..something((method, arguments) => firstBar(method, arguments, 0)),
      );
      // Each bar is drawn for the glow, the outline and itself, and every limb
      // has its streak of light.
      expect(
        find.byType(CustomPaint),
        paintsExactlyCountTimes(#drawLine, 3 * bars + limbs),
      );
      // The head three times, and the two floor ellipses.
      expect(find.byType(CustomPaint), paintsExactlyCountTimes(#drawCircle, 5));
    });
  });
}
