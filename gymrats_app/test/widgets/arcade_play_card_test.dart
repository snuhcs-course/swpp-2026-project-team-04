import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/arcade_play_card.dart';

void main() {
  Future<List<String>> show(WidgetTester tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              ArcadePlayCard.online(onTap: () => taps.add('online')),
              ArcadePlayCard.arcade(onTap: () => taps.add('arcade')),
            ],
          ),
        ),
      ),
    );
    return taps;
  }

  testWidgets('each card is the design\'s 154 x 430 with its name, and taps '
      'as one button', (tester) async {
    final taps = await show(tester);
    for (final card in find.byType(ArcadePlayCard).evaluate()) {
      expect(card.size, const Size(154, 430));
    }
    await tester.tap(find.text('온라인 대결'));
    await tester.tap(find.text('아케이드'));
    expect(taps, ['online', 'arcade']);
  });

  testWidgets('the arrow chip wears the card\'s color', (tester) async {
    await show(tester);
    final arrows = tester
        .widgetList<ArcadeGlyphIcon>(find.byType(ArcadeGlyphIcon))
        .where((icon) => icon.glyph == ArcadeGlyph.arrow)
        .map((icon) => icon.color)
        .toList();
    expect(arrows, [AppColors.accent, AppColors.opponent]);
  });

  testWidgets('the names are Do Hyeon 30, centered in the name room (A11 '
      'spec 3)', (tester) async {
    await show(tester);
    for (final name in ['온라인 대결', '아케이드']) {
      final text = tester.widget<Text>(find.text(name));
      expect(text.style!.fontSize, 30);
      expect(text.style!.fontFamily, AppFonts.display);
      final card = tester.getRect(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(ArcadePlayCard),
        ),
      );
      expect(
        tester.getCenter(find.text(name)).dx,
        closeTo(card.center.dx, 0.5),
      );
      // Between the panel and the card's bottom.
      expect(
        tester.getCenter(find.text(name)).dy,
        closeTo(
          card.top + (ArcadePlayCard.panel.height + card.height) / 2,
          0.5,
        ),
      );
    }
  });

  testWidgets('a screen reader hears each card\'s name as a button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('온라인 대결')),
      matchesSemantics(label: '온라인 대결', isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel('아케이드'), findsOneWidget);
    expect(find.bySemanticsLabel('VS'), findsNothing);
    semantics.dispose();
  });
}
