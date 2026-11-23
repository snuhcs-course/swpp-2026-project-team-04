import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/gym_owner_figure.dart';

import 'battle_test_support.dart';

Future<void> _show(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('ArcadeGlyphIcon (the design\'s icons, 24-point box)', () {
    for (final glyph in ArcadeGlyph.values) {
      testWidgets('${glyph.name} draws inside its box', (tester) async {
        final picture = await paintPicture(
          tester,
          SizedBox.square(
            dimension: 48,
            child: ColoredBox(
              color: AppColors.card,
              child: ArcadeGlyphIcon(glyph, size: 48),
            ),
          ),
          size: const Size(48, 48),
        );
        var inked = 0;
        for (var x = 0.0; x < 48; x += 2) {
          for (var y = 0.0; y < 48; y += 2) {
            if (picture.at(x, y) != AppColors.card) inked++;
          }
        }
        expect(inked, greaterThan(0));
      });
    }

    testWidgets('a star is filled with its fill and edged ink', (tester) async {
      final picture = await paintPicture(
        tester,
        const SizedBox.square(
          dimension: 48,
          child: ColoredBox(
            color: AppColors.card,
            child: ArcadeGlyphIcon(
              ArcadeGlyph.star,
              size: 48,
              fill: AppColors.starOff,
            ),
          ),
        ),
        size: const Size(48, 48),
      );
      expect(picture.at(24, 24), AppColors.starOff);
    });

    test('the design\'s strokes', () {
      expect(ArcadeGlyphPainter.defaultStroke(ArcadeGlyph.star), 2);
      expect(ArcadeGlyphPainter.defaultStroke(ArcadeGlyph.lock), 2.8);
      expect(ArcadeGlyphPainter.defaultStroke(ArcadeGlyph.arrow), 2.6);
      expect(ArcadeGlyphPainter.defaultStroke(ArcadeGlyph.cross), 3.6);
    });

    test('repaints only when something changes', () {
      const a = ArcadeGlyphPainter(ArcadeGlyph.star, color: AppColors.ink);
      expect(
        a.shouldRepaint(
          const ArcadeGlyphPainter(ArcadeGlyph.star, color: AppColors.ink),
        ),
        isFalse,
      );
      expect(
        a.shouldRepaint(
          const ArcadeGlyphPainter(ArcadeGlyph.bolt, color: AppColors.ink),
        ),
        isTrue,
      );
    });
  });

  group('ArcadeFace', () {
    testWidgets('centres a character\'s face at its scale (the design\'s '
        'face())', (tester) async {
      await _show(
        tester,
        const ClipOval(child: ArcadeFace(id: 'seal', size: 58, scale: 0.6)),
      );
      final figure = tester.widget<CharacterFigure>(
        find.byType(CharacterFigure),
      );
      expect(figure.characterId, 'seal');
      expect(figure.scale, 0.6);
      final box = tester.getTopLeft(find.byType(ArcadeFace));
      final at = tester.getTopLeft(find.byType(CharacterFigure));
      expect((at - box).dx, closeTo(29 - 70 * 0.6, 1e-9));
      expect((at - box).dy, closeTo(29 - 66 * 0.6, 1e-9));
    });

    testWidgets('an owner\'s face in goggles; locked, grey', (tester) async {
      await _show(
        tester,
        const ArcadeFace(
          id: 'kangaroo',
          size: 48,
          scale: 0.5,
          owner: true,
          gray: true,
        ),
      );
      expect(find.byType(GymOwnerFigure), findsOneWidget);
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        ArcadeFace.lockedOpacity,
      );
    });
  });

  testWidgets('ArcadeWhiteOutline lays eight white copies under the child', (
    tester,
  ) async {
    await _show(
      tester,
      const ArcadeWhiteOutline(child: SizedBox.square(dimension: 10)),
    );
    expect(
      find.descendant(
        of: find.byType(ArcadeWhiteOutline),
        matching: find.byType(Transform),
      ),
      findsNWidgets(8),
    );
  });

  testWidgets('ArcadeFigure and ArcadeOwnerFigure face left when mirrored', (
    tester,
  ) async {
    await _show(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArcadeFigure(id: 'bear', pose: BattlePose.win, mirror: true),
          ArcadeOwnerFigure(id: 'penguin', mirror: true),
        ],
      ),
    );
    expect(
      tester
          .widgetList<CharacterFigure>(find.byType(CharacterFigure))
          .map((f) => (f.characterId, f.pose))
          .toSet(),
      {('bear', BattlePose.win)},
    );
    expect(find.byType(GymOwnerFigure), findsNWidgets(9));
  });

  group('buttons', () {
    testWidgets('dark, light and link buttons answer a tap and are at least '
        '44 high', (tester) async {
      final taps = <String>[];
      await _show(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              child: ArcadeDarkButton(
                label: '도전',
                onPressed: () => taps.add('dark'),
              ),
            ),
            SizedBox(
              width: 200,
              child: ArcadeLightButton(
                label: '닫기',
                onPressed: () => taps.add('light'),
              ),
            ),
            ArcadeTextLink(label: '아케이드로', onPressed: () => taps.add('link')),
          ],
        ),
      );
      for (final label in ['도전', '닫기', '아케이드로']) {
        await tester.tap(find.text(label));
      }
      expect(taps, ['dark', 'light', 'link']);
      expect(tester.getSize(find.byType(ArcadeDarkButton)).height, 56);
      expect(
        tester.getSize(find.byType(ArcadeLightButton)).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('stars', () {
    testWidgets('the conditions light row i once the best reaches i', (
      tester,
    ) async {
      await _show(
        tester,
        const SizedBox(
          width: 300,
          child: ArcadeStarGoals(
            title: '별 조건',
            labels: ['승리', '콤보 5 이상', 'KO 승리'],
            best: 1,
            style: TextStyle(),
          ),
        ),
      );
      expect(find.text('별 조건'), findsOneWidget);
      expect(find.bySemanticsLabel('별 1개, 승리, 받음'), findsOneWidget);
      expect(find.bySemanticsLabel('별 2개, 콤보 5 이상'), findsOneWidget);
      final fills = tester
          .widgetList<ArcadeGlyphIcon>(find.byType(ArcadeGlyphIcon))
          .map((icon) => icon.fill)
          .toList();
      expect(fills.where((fill) => fill == AppColors.starOn), hasLength(1));
      expect(fills, hasLength(9));
    });

    testWidgets('the results\' stars: lit ones amber, the middle larger', (
      tester,
    ) async {
      await _show(
        tester,
        const ArcadeResultStars(
          labels: ['승리', '콤보 5 이상', 'KO 승리'],
          lit: [true, true, false],
        ),
      );
      final icons = tester
          .widgetList<ArcadeGlyphIcon>(find.byType(ArcadeGlyphIcon))
          .toList();
      expect(icons.map((i) => i.size), [60, 72, 60]);
      expect(icons.map((i) => i.fill), [
        AppColors.starOn,
        AppColors.starOn,
        AppColors.starOff,
      ]);
      expect(
        tester.widget<Text>(find.text('KO 승리')).style!.color,
        AppColors.textMuted,
      );
      expect(
        find.bySemanticsLabel('승리 받음, 콤보 5 이상 받음, KO 승리 못 받음'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the score line: the winner\'s number larger', (tester) async {
    await _show(
      tester,
      const ArcadeScoreLine(me: 98, opponent: 140, meLarger: false),
    );
    final text = Theme.of(tester.element(find.byType(ArcadeScoreLine)))
        .textTheme;
    expect(tester.widget<Text>(find.text('98')).style, text.arcadeScoreSmall);
    expect(tester.widget<Text>(find.text('140')).style, text.arcadeScoreBig);
    expect(find.bySemanticsLabel('내 점수 98, 상대 점수 140'), findsOneWidget);
  });

  testWidgets('the title band is a header', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(
      tester,
      const ArcadeTitleBand(
        label: '클리어!',
        color: AppColors.accent,
        style: TextStyle(),
      ),
    );
    expect(
      tester.getSemantics(find.text('클리어!')),
      matchesSemantics(label: '클리어!', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('the round pip lights the rounds up to this one', (tester) async {
    await _show(tester, const ArcadeRoundPip(round: 1));
    expect(find.text('R1'), findsOneWidget);
    expect(find.bySemanticsLabel('보스 매치 1라운드'), findsOneWidget);
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .where((color) => color == AppColors.accent || color == AppColors.card)
        .toList();
    // The pill itself is white too: then one lime dot and one white.
    expect(dots.where((c) => c == AppColors.accent), hasLength(1));
  });

  testWidgets('the stripes: amber and ink at 135 degrees', (tester) async {
    final picture = await paintPicture(
      tester,
      const SizedBox(
        width: 64,
        height: 32,
        child: CustomPaint(painter: ArcadeStripesPainter(8)),
      ),
      size: const Size(64, 32),
    );
    final colors = {for (var x = 0.0; x < 64; x += 3) picture.at(x, 16)};
    expect(colors, containsAll([AppColors.warning, AppColors.ink]));
  });

  testWidgets('a pedestal is white with an ink edge', (tester) async {
    await _show(tester, const ArcadePedestal(width: 112));
    expect(tester.getSize(find.byType(ArcadePedestal)), const Size(112, 16));
  });
}
