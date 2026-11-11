import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_banner.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';

import 'battle_test_support.dart';

BattleFxBanner _banner(
  String text, {
  double top = 132,
  double size = 84,
  BattleFxTone tone = BattleFxTone.plain,
  double opacity = 1,
  BattleFxFont font = BattleFxFont.number,
  BattleFxAlign align = BattleFxAlign.center,
  double dx = 0,
  double dy = 0,
  double rotation = 0,
  double scaleX = 1,
  double scaleY = 1,
}) => BattleFxBanner(
  text: text,
  top: top,
  textSize: size,
  tone: tone,
  opacity: opacity,
  font: font,
  align: align,
  dx: dx,
  dy: dy,
  rotation: rotation,
  scaleX: scaleX,
  scaleY: scaleY,
);

Future<void> _pumpBanner(
  WidgetTester tester,
  BattleFxBanner banner, {
  TextScaler textScaler = TextScaler.noScaling,
}) => tester.pumpWidget(
  battleTestApp(
    MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Stack(children: [BattleStageBanner(banner: banner)]),
    ),
  ),
);

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

/// The colored, ink-edged box behind a band's text.
Finder _fill() => find.descendant(
  of: find.byType(BattleBand),
  matching: find.byType(DecoratedBox),
);

void main() {
  setUpAll(loadBattleFonts);

  group('BattleFxToneColor', () {
    test('every tone is a theme fill', () {
      expect(
        {for (final tone in BattleFxTone.values) tone: tone.color},
        {
          BattleFxTone.me: AppColors.accent,
          BattleFxTone.opponent: AppColors.opponent,
          BattleFxTone.plain: AppColors.card,
          BattleFxTone.average: AppColors.warning,
          BattleFxTone.fever: AppColors.fever,
          BattleFxTone.danger: AppColors.danger,
        },
      );
    });
  });

  group('BattleBand', () {
    testWidgets('numbers and English: Oxanium extra bold in ink, at its size', (
      tester,
    ) async {
      await _pumpBanner(tester, _banner('MISS', size: 84));
      final style = _styleOf(tester, 'MISS');
      expect(style.fontFamily, AppFonts.number);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.fontSize, 84);
      expect(style.height, 1);
      expect(style.letterSpacing, -1);
      expect(style.color, AppColors.ink);
    });

    testWidgets('Korean: Do Hyeon in ink, with room for the letters', (
      tester,
    ) async {
      await _pumpBanner(
        tester,
        _banner('자세 세팅 중', size: 34, font: BattleFxFont.display),
      );
      final style = _styleOf(tester, '자세 세팅 중');
      expect(style.fontFamily, AppFonts.display);
      expect(style.fontSize, 34);
      expect(style.height, 1.25);
      expect(style.color, AppColors.ink);
    });

    testWidgets('the fill is the tone\'s color with a 3 wide ink edge', (
      tester,
    ) async {
      await _pumpBanner(tester, _banner('K.O.', tone: BattleFxTone.me));
      final decoration =
          tester.widget<DecoratedBox>(_fill()).decoration as BoxDecoration;
      expect(decoration.color, AppColors.accent);
      expect(decoration.border, Border.all(color: AppColors.ink, width: 3));
    });

    testWidgets('a number band leaves a tenth of the line free above and '
        'below; a Korean band is as tall as its line', (tester) async {
      await _pumpBanner(tester, _banner('MISS', size: 100));
      expect(tester.getSize(find.byType(BattleBand)).height, 100);
      expect(tester.getSize(_fill()).height, closeTo(80, 0.01));

      await _pumpBanner(
        tester,
        _banner('자세 세팅 중', size: 40, font: BattleFxFont.display),
      );
      expect(tester.getSize(find.byType(BattleBand)).height, closeTo(50, 0.01));
      expect(tester.getSize(_fill()).height, closeTo(50, 0.01));
    });

    testWidgets('has 14 beside numbers and 16 beside Korean', (tester) async {
      await _pumpBanner(tester, _banner('MISS'));
      expect(
        tester.getSize(find.byType(BattleBand)).width -
            tester.getSize(find.text('MISS')).width,
        closeTo(28, 0.01),
      );
      await _pumpBanner(
        tester,
        _banner('자세 세팅 중', size: 34, font: BattleFxFont.display),
      );
      expect(
        tester.getSize(find.byType(BattleBand)).width -
            tester.getSize(find.text('자세 세팅 중')).width,
        closeTo(32, 0.01),
      );
    });

    testWidgets('leans like the design: 12 degrees', (tester) async {
      await _pumpBanner(tester, _banner('MISS'));
      final skew = tester.widget<Transform>(
        find.ancestor(of: _fill(), matching: find.byType(Transform)).first,
      );
      expect(skew.transform, AppHighlight.battleSlant);
    });

    testWidgets('does not grow with the system text size', (tester) async {
      await _pumpBanner(tester, _banner('MISS'));
      final size = tester.getSize(find.byType(BattleBand));
      await _pumpBanner(
        tester,
        _banner('MISS'),
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.getSize(find.byType(BattleBand)), size);
    });
  });

  group('BattleStageBanner', () {
    testWidgets('sits at its top, in the middle of the stage', (tester) async {
      await _pumpBanner(tester, _banner('MISS', top: 146));
      final band = tester.getRect(find.byType(BattleBand));
      expect(band.top, 146);
      expect(band.center.dx, closeTo(180, 0.01));
    });

    testWidgets('a left band starts 8 from the left, a right one ends 8 from '
        'the right', (tester) async {
      await _pumpBanner(
        tester,
        _banner('2 HIT', size: 44, align: BattleFxAlign.left),
      );
      expect(tester.getRect(find.byType(BattleBand)).left, 8);
      await _pumpBanner(
        tester,
        _banner('3 HIT', size: 44, align: BattleFxAlign.right),
      );
      expect(tester.getRect(find.byType(BattleBand)).right, 352);
    });

    testWidgets('is moved by dx and dy', (tester) async {
      await _pumpBanner(tester, _banner('MISS', top: 146, dx: -56, dy: -3.8));
      final band = tester.getRect(find.byType(BattleBand));
      expect(band.center.dx, closeTo(180 - 56, 0.01));
      expect(band.top, closeTo(146 - 3.8, 0.01));
    });

    testWidgets('is sized around its own anchor: the middle, or its side', (
      tester,
    ) async {
      await _pumpBanner(tester, _banner('MISS'));
      final full = tester.getRect(find.byType(BattleBand));
      await _pumpBanner(tester, _banner('MISS', scaleX: 0.5, scaleY: 0.5));
      final half = tester.getRect(find.byType(BattleBand));
      expect(half.width, closeTo(full.width / 2, 0.01));
      expect(half.height, closeTo(full.height / 2, 0.01));
      expect(half.center.dx, closeTo(full.center.dx, 0.01));
      expect(half.center.dy, closeTo(full.center.dy, 0.01));

      await _pumpBanner(
        tester,
        _banner('2 HIT', size: 44, align: BattleFxAlign.left, scaleX: 0.72),
      );
      // The anchor of a left band is the stage's 8, where the band starts.
      expect(tester.getRect(find.byType(BattleBand)).left, closeTo(8, 0.01));
    });

    testWidgets('is turned around its anchor', (tester) async {
      await _pumpBanner(tester, _banner('MISS'));
      final level = tester.getRect(find.byType(BattleBand));
      await _pumpBanner(tester, _banner('MISS', rotation: 90));
      final turned = tester.getRect(find.byType(BattleBand));
      expect(turned.center.dx, closeTo(level.center.dx, 0.01));
      expect(turned.center.dy, closeTo(level.center.dy, 0.01));
    });

    testWidgets('a band wider than the stage spills over both sides', (
      tester,
    ) async {
      await _pumpBanner(tester, _banner('EXCELLENT', size: 190));
      expect(tester.takeException(), isNull);
      final band = tester.getRect(find.byType(BattleBand));
      expect(band.width, greaterThan(360));
      expect(band.center.dx, closeTo(180, 0.01));
    });

    testWidgets('fades with its opacity and never takes a tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        battleTestApp(
          Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                ),
              ),
              BattleStageBanner(banner: _banner('TIME!', opacity: 0.4)),
            ],
          ),
        ),
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byType(BattleStageBanner),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0.4,
      );
      await tester.tap(find.text('TIME!'), warnIfMissed: false);
      expect(taps, 1);
    });

    testWidgets('an opacity above 1 or below 0 is kept inside', (tester) async {
      await _pumpBanner(tester, _banner('MISS', opacity: 1.3));
      expect(tester.takeException(), isNull);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });
  });

  group('BattleStageBanner, moved, turned and sized together', () {
    /// Where a corner [p] of the untransformed band goes: sized around the
    /// anchor, turned clockwise around it, then moved.
    Offset placed(
      Offset p,
      Offset anchor, {
      double dx = 0,
      double dy = 0,
      double degrees = 0,
      double scaleX = 1,
      double scaleY = 1,
    }) {
      final x = (p.dx - anchor.dx) * scaleX;
      final y = (p.dy - anchor.dy) * scaleY;
      final a = degrees * math.pi / 180;
      return Offset(
        anchor.dx + dx + x * math.cos(a) - y * math.sin(a),
        anchor.dy + dy + x * math.sin(a) + y * math.cos(a),
      );
    }

    Future<void> expectPlaced(
      WidgetTester tester,
      BattleFxBanner plain,
      double anchorX, {
      double dx = 0,
      double dy = 0,
      double degrees = 0,
      double scaleX = 1,
      double scaleY = 1,
    }) async {
      await _pumpBanner(tester, plain);
      final box = tester.getRect(find.byType(BattleBand));
      final anchor = Offset(anchorX, box.center.dy);
      await _pumpBanner(
        tester,
        BattleFxBanner(
          text: plain.text,
          top: plain.top,
          textSize: plain.textSize,
          tone: plain.tone,
          opacity: 1,
          align: plain.align,
          dx: dx,
          dy: dy,
          rotation: degrees,
          scaleX: scaleX,
          scaleY: scaleY,
        ),
      );
      final band = find.byType(BattleBand);
      for (final (corner, actual) in [
        (box.topLeft, tester.getTopLeft(band)),
        (box.topRight, tester.getTopRight(band)),
        (box.bottomLeft, tester.getBottomLeft(band)),
      ]) {
        final want = placed(
          corner,
          anchor,
          dx: dx,
          dy: dy,
          degrees: degrees,
          scaleX: scaleX,
          scaleY: scaleY,
        );
        expect(actual.dx, closeTo(want.dx, 0.01), reason: '$corner x');
        expect(actual.dy, closeTo(want.dy, 0.01), reason: '$corner y');
      }
    }

    testWidgets('MISS: 56 to the side, 7 degrees clockwise, 0.78 wide', (
      tester,
    ) async {
      await expectPlaced(
        tester,
        _banner('MISS', top: 146),
        180,
        dx: -56,
        dy: -3.8,
        degrees: 7,
        scaleX: 0.78,
      );
    });

    testWidgets('a turn the other way, with different width and height', (
      tester,
    ) async {
      await expectPlaced(
        tester,
        _banner('FEVER ×2', top: 194, size: 80, tone: BattleFxTone.fever),
        180,
        dx: -50,
        degrees: -5,
        scaleX: 0.7,
        scaleY: 1.2,
      );
    });

    testWidgets('a left band around the stage\'s 8', (tester) async {
      await expectPlaced(
        tester,
        _banner('2 HIT', top: 136, size: 44, align: BattleFxAlign.left),
        8,
        degrees: -6,
        scaleX: 0.75,
        scaleY: 1.04,
      );
    });

    testWidgets('a right band around the stage\'s 352', (tester) async {
      await expectPlaced(
        tester,
        _banner('3 HIT', top: 136, size: 44, align: BattleFxAlign.right),
        352,
        degrees: 6,
        scaleX: 0.72,
      );
    });
  });

  group('BattleStageBanner, the rest', () {
    testWidgets('a Korean band takes its tone\'s color too', (tester) async {
      await _pumpBanner(
        tester,
        _banner(
          '연결이 끊겨서 졌어요',
          size: 28,
          tone: BattleFxTone.opponent,
          font: BattleFxFont.display,
        ),
      );
      final decoration =
          tester.widget<DecoratedBox>(_fill()).decoration as BoxDecoration;
      expect(decoration.color, AppColors.opponent);
    });

    testWidgets('the band leans around its own middle', (tester) async {
      await _pumpBanner(tester, _banner('MISS', size: 100));
      final skew = tester.widget<Transform>(
        find.ancestor(of: _fill(), matching: find.byType(Transform)).first,
      );
      expect(skew.alignment, Alignment.center);
      expect(skew.origin, isNull);
      // Leaning around the middle, the top edge goes right and the bottom
      // edge left by the same amount: the fill's middle stays put.
      final band = tester.getRect(find.byType(BattleBand));
      final fill = tester.getRect(_fill());
      expect(fill.center.dx, closeTo(band.center.dx, 0.01));
      expect(tester.getTopLeft(_fill()).dx, greaterThan(band.left));
      expect(tester.getBottomLeft(_fill()).dx, lessThan(band.left));
    });

    testWidgets('is a picture to a screen reader: the stage says what '
        'happened', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpBanner(tester, _banner('MISS'));
      expect(find.bySemanticsLabel('MISS'), findsNothing);
      handle.dispose();
    });
  });
}
