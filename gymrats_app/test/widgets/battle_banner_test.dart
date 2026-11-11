import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_banner.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

import 'battle_test_support.dart';

BattleFxBanner _banner(
  String text, {
  double top = 155,
  double size = 84,
  BattleFxTone tone = BattleFxTone.plain,
  double opacity = 1,
  BattleFxFont font = BattleFxFont.number,
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

/// The four corners of the slanted fill as drawn, on the screen.
List<Offset> _corners(WidgetTester tester) {
  final fill = _fill();
  return [
    tester.getTopLeft(fill),
    tester.getTopRight(fill),
    tester.getBottomLeft(fill),
    tester.getBottomRight(fill),
  ];
}

/// The span of the slanted band as drawn, top to bottom and left to right,
/// turned and sized as it is: what the design's table of band places gives
/// (it measures the slanted shape, not the box around the text).
({double top, double bottom, double left, double right}) _span(
  WidgetTester tester,
) {
  final corners = _corners(tester);
  final ys = corners.map((c) => c.dy);
  final xs = corners.map((c) => c.dx);
  return (
    top: ys.reduce(math.min),
    bottom: ys.reduce(math.max),
    left: xs.reduce(math.min),
    right: xs.reduce(math.max),
  );
}

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

  group('the band sizes (spec v2.2, bandBox)', () {
    test(
      'a number band is its capitals with the same room above and below',
      () {
        final box = BattleFx.bandBox(100);
        expect(box.height, closeTo(89, 1e-9));
        expect(box.padX, closeTo(18, 1e-9));
        expect(box.baseline, closeTo(79, 1e-9));
        // The capitals are 0.69 tall: 0.07 + 3 above them, as much below.
        final above = box.baseline - 69;
        expect(above, closeTo(0.07 * 100 + 3, 1e-9));
        expect(box.height - box.baseline, closeTo(above, 1e-9));
      },
    );

    test('a Korean band is its 1.25 line, 16 beside the text', () {
      expect(BattleFx.koreanBandBox(28), (height: 35.0, padX: 16.0));
    });

    test('a banner takes its band\'s size from its font', () {
      final number = _banner('MISS');
      expect(number.bandHeight, closeTo(75.72, 1e-9));
      expect(number.padX, closeTo(15.6, 1e-9));
      final korean = _banner('자세 세팅 중', size: 34, font: BattleFxFont.display);
      expect(korean.bandHeight, closeTo(42.5, 1e-9));
      expect(korean.padX, 16);
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

    testWidgets('a number band is 0.83 of its size and 6 tall, all filled; a '
        'Korean band is as tall as its line', (tester) async {
      await _pumpBanner(tester, _banner('MISS', size: 100));
      expect(tester.getSize(find.byType(BattleBand)).height, closeTo(89, 0.01));
      expect(tester.getSize(_fill()).height, closeTo(89, 0.01));

      await _pumpBanner(
        tester,
        _banner('자세 세팅 중', size: 40, font: BattleFxFont.display),
      );
      expect(tester.getSize(find.byType(BattleBand)).height, closeTo(50, 0.01));
      expect(tester.getSize(_fill()).height, closeTo(50, 0.01));
    });

    testWidgets('has 0.15 of its size and 3 beside numbers, 16 beside Korean', (
      tester,
    ) async {
      await _pumpBanner(tester, _banner('MISS', size: 84));
      expect(
        tester.getSize(find.byType(BattleBand)).width -
            tester.getSize(find.text('MISS')).width,
        closeTo(2 * (0.15 * 84 + 3), 0.01),
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

    testWidgets('the text\'s line starts 3 - 0.03 of its size below the '
        'band\'s top', (tester) async {
      await _pumpBanner(tester, _banner('MISS', top: 100, size: 100));
      expect(tester.getTopLeft(find.text('MISS')).dy, closeTo(100, 0.01));
      await _pumpBanner(tester, _banner('3', top: 100, size: 160));
      expect(
        tester.getTopLeft(find.text('3')).dy,
        closeTo(100 + 3 - 0.03 * 160, 0.01),
      );
    });

    testWidgets('with the app\'s font the capitals sit in the middle of the '
        'band, clear of its edge', (tester) async {
      // Flat capitals only, so no letter reaches past the capital height.
      late double width;
      final picture = await paintPicture(
        tester,
        Builder(
          builder: (context) {
            final band = BattleBand.number(
              text: 'HIT',
              size: 100,
              color: AppColors.accent,
              theme: Theme.of(context).textTheme,
            );
            return band;
          },
        ),
        size: const Size(400, 120),
      );
      width = tester.getSize(find.byType(BattleBand)).width;
      const edge = 3;
      final box = BattleFx.bandBox(100);
      bool dark(int x, int y) {
        final c = picture.at(x.toDouble(), y.toDouble());
        return (c.r + c.g + c.b) / 3 < 0.5;
      }

      // Inside the edge, and inside the room beside the text, where the
      // slanted sides never reach.
      final rows = [
        for (var y = edge + 1; y < box.height - edge - 1; y++)
          if ([for (var x = box.padX.ceil(); x < width - box.padX; x++) x]
              .any((x) => dark(x, y)))
            y,
      ];
      final capTop = rows.first.toDouble();
      final capBottom = rows.last + 1.0;
      expect(capTop, closeTo(0.07 * 100 + edge, 1.5));
      expect(capBottom, closeTo(box.baseline, 1.5));
      // The same room above and below.
      expect(capTop - 0, closeTo(box.height - capBottom, 1.5));
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
    testWidgets('its top is the banner\'s top, in the middle of the stage', (
      tester,
    ) async {
      await _pumpBanner(tester, _banner('MISS', top: 155));
      final band = tester.getRect(find.byType(BattleBand));
      expect(band.top, 155);
      expect(band.center.dx, closeTo(180, 0.01));
    });

    testWidgets('is moved by dx and dy', (tester) async {
      await _pumpBanner(tester, _banner('MISS', top: 155, dx: -56, dy: -3.8));
      final band = tester.getRect(find.byType(BattleBand));
      expect(band.center.dx, closeTo(180 - 56, 0.01));
      expect(band.top, closeTo(155 - 3.8, 0.01));
    });

    testWidgets('is sized around its own middle', (tester) async {
      await _pumpBanner(tester, _banner('MISS'));
      final full = tester.getRect(find.byType(BattleBand));
      await _pumpBanner(tester, _banner('MISS', scaleX: 0.5, scaleY: 0.5));
      final half = tester.getRect(find.byType(BattleBand));
      expect(half.width, closeTo(full.width / 2, 0.01));
      expect(half.height, closeTo(full.height / 2, 0.01));
      expect(half.center.dx, closeTo(full.center.dx, 0.01));
      expect(half.center.dy, closeTo(full.center.dy, 0.01));
    });

    testWidgets('is turned around its middle', (tester) async {
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
      BattleFxBanner plain, {
      double dx = 0,
      double dy = 0,
      double degrees = 0,
      double scaleX = 1,
      double scaleY = 1,
    }) async {
      await _pumpBanner(tester, plain);
      final box = tester.getRect(find.byType(BattleBand));
      final anchor = Offset(180, box.center.dy);
      await _pumpBanner(
        tester,
        BattleFxBanner(
          text: plain.text,
          top: plain.top,
          textSize: plain.textSize,
          tone: plain.tone,
          opacity: 1,
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
        _banner('MISS', top: 155),
        dx: -56,
        degrees: 7,
        scaleX: 0.78,
      );
    });

    testWidgets('a turn the other way, with different width and height', (
      tester,
    ) async {
      await expectPlaced(
        tester,
        _banner('FEVER ×2', top: 263, size: 80),
        dx: -50,
        dy: 3,
        degrees: -4,
        scaleX: 0.7,
        scaleY: 1.2,
      );
    });

    testWidgets('K.O.: 102 to the side, 0.6 wide', (tester) async {
      await expectPlaced(
        tester,
        _banner('K.O.', top: 166, size: 110),
        dx: 102,
        degrees: 7,
        scaleX: 0.6,
      );
    });
  });

  group('the bands where the design puts them (spec section 4 table)', () {
    /// Draws [banner] once it has settled and checks the span the design's
    /// table gives it, measured with the app's own fonts.
    Future<void> expectSpan(
      WidgetTester tester,
      BattleFxBanner banner,
      double top,
      double bottom,
    ) async {
      await _pumpBanner(tester, banner);
      final span = _span(tester);
      expect(span.top, closeTo(top, 1.5), reason: '${banner.text} top');
      expect(span.bottom, closeTo(bottom, 1.5), reason: '${banner.text} end');
    }

    BattleFxBanner only(BattleFxTimeline fx, double now, String text) =>
        fx.frame(now).banners.singleWhere((b) => b.text == text);

    testWidgets('MISS from 144 to 242, under the time bar', (tester) async {
      final fx = BattleFxTimeline()
        ..rep(const BattleStageEvent(side: BattleSide.me, grade: null), 0);
      await expectSpan(tester, only(fx, 400, 'MISS'), 144, 242);
    });

    testWidgets('FEVER ×2 from 253 to 345, over the fighters and above the '
        'bar', (tester) async {
      final fx = BattleFxTimeline()..setFever(true, 0);
      await expectSpan(tester, only(fx, 600, 'FEVER ×2'), 253, 345);
    });

    testWidgets('3, 2, 1 from 141 to 280 and GO! from 141 to 279', (
      tester,
    ) async {
      final fx = BattleFxTimeline()..countDown(3000, 0);
      await expectSpan(tester, only(fx, 500, '3'), 141, 280);
      await expectSpan(tester, only(fx, 1500, '2'), 141, 280);
      await expectSpan(tester, only(fx, 3300, 'GO!'), 141, 279);
    });

    testWidgets('K.O. from 156 to 273, on the half the winner left empty', (
      tester,
    ) async {
      final fx = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.me,
            grade: GameGrade.excellent,
            points: 15,
            combo: 1,
            knockout: true,
          ),
          0,
        );
      final band = only(fx, 80 + 1250 + 400, 'K.O.');
      await expectSpan(tester, band, 156, 273);
      // The winner, who stands at x 158 to 286 then, stays clear.
      final span = _span(tester);
      expect(span.left, closeTo(2, 2));
      expect(span.right, closeTo(154, 2));
    });

    testWidgets('TIME! from 144 to 256; the verdict within 143 to 254, which '
        'its widest word, DRAW, fills', (tester) async {
      BattleFxTimeline timeUp(BattleSide? winner) => BattleFxTimeline()
        ..finish(BattleStageEnd(kind: BattleEndKind.timeUp, winner: winner), 0);
      await expectSpan(tester, only(timeUp(null), 500, 'TIME!'), 144, 256);
      await expectSpan(tester, only(timeUp(null), 1500, 'DRAW'), 143, 254);
      for (final (winner, text) in [
        (BattleSide.me, 'WIN!'),
        (BattleSide.opponent, 'LOSE'),
      ]) {
        await _pumpBanner(tester, only(timeUp(winner), 1500, text));
        final span = _span(tester);
        expect(span.top, greaterThan(143 - 1.5), reason: text);
        expect(span.bottom, lessThan(254 + 1.5), reason: text);
      }
    });

    testWidgets('the Korean bands, unchanged', (tester) async {
      final setup = BattleFxTimeline()..setSetup(active: true);
      await expectSpan(tester, only(setup, 0, '자세 세팅 중'), 143, 196);
      final waiting = BattleFxTimeline()..setSetup(active: true, meReady: true);
      await expectSpan(tester, only(waiting, 0, '상대를 기다리는 중'), 141, 198);
      final left = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          0,
        );
      await expectSpan(tester, only(left, 1000, '상대가 나가서 이겼어요'), 143, 192);
    });

    testWidgets('no band of the stage reaches the time bar\'s bottom at 136', (
      tester,
    ) async {
      final fx = BattleFxTimeline()
        ..rep(const BattleStageEvent(side: BattleSide.me, grade: null), 0)
        ..rep(
          const BattleStageEvent(side: BattleSide.opponent, grade: null),
          0,
        );
      for (final band in fx.frame(400).banners) {
        await _pumpBanner(tester, band);
        expect(_span(tester).top, greaterThan(136), reason: band.text);
      }
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

  group('BattleComboMark', () {
    BattleFxCombo combo(
      BattleSide side, {
      int count = 2,
      double opacity = 1,
      double rotation = 0,
      double scaleX = 1,
      double scaleY = 1,
    }) => BattleFxCombo(
      side: side,
      count: count,
      opacity: opacity,
      rotation: rotation,
      scaleX: scaleX,
      scaleY: scaleY,
    );

    Future<void> pumpMark(
      WidgetTester tester,
      BattleFxCombo mark, {
      double scale = 1,
    }) => tester.pumpWidget(
      battleTestApp(
        Stack(
          children: [
            Positioned(
              left: mark.side == BattleSide.me ? 0 : null,
              right: mark.side == BattleSide.me ? null : 0,
              top: 0,
              child: BattleComboMark(combo: mark, scale: scale),
            ),
          ],
        ),
      ),
    );

    testWidgets('a white number band of 44, its outer end 6 from the side', (
      tester,
    ) async {
      await pumpMark(tester, combo(BattleSide.me));
      expect(find.text('2 HIT'), findsOneWidget);
      expect(_styleOf(tester, '2 HIT').fontSize, 44);
      expect(
        tester.widget<BattleBand>(find.byType(BattleBand)).color,
        AppColors.card,
      );
      final mine = tester.getRect(find.byType(BattleBand));
      expect(mine.left, 6);
      expect(mine.height, closeTo(BattleFx.bandBox(44).height, 0.01));

      await pumpMark(tester, combo(BattleSide.opponent, count: 3));
      expect(tester.getRect(find.byType(BattleBand)).right, 360 - 6);
    });

    testWidgets('turns and is sized around its outer end\'s middle', (
      tester,
    ) async {
      await pumpMark(tester, combo(BattleSide.me));
      final level = tester.getRect(find.byType(BattleBand));
      await pumpMark(
        tester,
        combo(BattleSide.me, rotation: -6, scaleX: 0.72, scaleY: 0.8),
      );
      // The outer end's middle stays put; the inner end goes up and in.
      final band = find.byType(BattleBand);
      final pivot = Offset(level.left, level.center.dy);
      final a = -6 * math.pi / 180;
      Offset placed(Offset p) {
        final x = (p.dx - pivot.dx) * 0.72;
        final y = (p.dy - pivot.dy) * 0.8;
        return Offset(
          pivot.dx + x * math.cos(a) - y * math.sin(a),
          pivot.dy + x * math.sin(a) + y * math.cos(a),
        );
      }

      for (final (corner, actual) in [
        (level.topLeft, tester.getTopLeft(band)),
        (level.topRight, tester.getTopRight(band)),
        (level.bottomRight, tester.getBottomRight(band)),
      ]) {
        final want = placed(corner);
        expect(actual.dx, closeTo(want.dx, 0.01), reason: '$corner x');
        expect(actual.dy, closeTo(want.dy, 0.01), reason: '$corner y');
      }
      expect(tester.getTopRight(band).dy, lessThan(tester.getTopLeft(band).dy));

      await pumpMark(tester, combo(BattleSide.opponent));
      final theirs = tester.getRect(band);
      await pumpMark(tester, combo(BattleSide.opponent, rotation: 6));
      // The opponent's turns the other way around its right end.
      expect(
        tester.getTopRight(band).dy,
        closeTo(
          theirs.center.dy - theirs.height / 2 * math.cos(6 * math.pi / 180),
          0.01,
        ),
      );
      expect(tester.getTopLeft(band).dy, lessThan(tester.getTopRight(band).dy));
    });

    testWidgets('is sized with the stage from its top outer corner', (
      tester,
    ) async {
      await pumpMark(tester, combo(BattleSide.me), scale: 1.25);
      final mark = tester.getRect(find.byType(BattleBand));
      expect(mark.left, closeTo(6 * 1.25, 0.01));
      expect(mark.top, 0);
      expect(mark.height, closeTo(BattleFx.bandBox(44).height * 1.25, 0.01));
      await pumpMark(tester, combo(BattleSide.opponent), scale: 0.8);
      final theirs = tester.getRect(find.byType(BattleBand));
      expect(theirs.right, closeTo(360 - 6 * 0.8, 0.01));
    });

    testWidgets('fades, takes no tap and is a picture to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
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
              BattleComboMark(combo: combo(BattleSide.me, opacity: 0.3)),
            ],
          ),
        ),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.3);
      await tester.tap(find.text('2 HIT'), warnIfMissed: false);
      expect(taps, 1);
      expect(find.bySemanticsLabel('2 HIT'), findsNothing);
      handle.dispose();
    });
  });

  test('the effect math gives each rep\'s reason to the sign only', () {
    final fx = BattleFxTimeline()
      ..rep(
        const BattleStageEvent(
          side: BattleSide.me,
          grade: GameGrade.average,
          points: 5,
          reason: RejectReason.insufficientDepth,
        ),
        0,
      );
    expect(fx.frame(200).sign!.text, '더 깊게');
  });
}
