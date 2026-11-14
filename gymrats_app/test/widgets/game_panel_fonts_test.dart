import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';

/// Tests otherwise draw every letter as the same square, so only here does
/// the text of the rules and the result have its real width. In its own
/// file, as the fonts stay loaded for the rest of the run.
Future<void> _loadAppFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final entry in const {
    AppFonts.number: ['assets/fonts/Oxanium-Bold.ttf'],
    AppFonts.headline: ['assets/fonts/BlackHanSans-Regular.ttf'],
    AppFonts.body: [
      'assets/fonts/IBMPlexSansKR-Regular.ttf',
      'assets/fonts/IBMPlexSansKR-Medium.ttf',
      'assets/fonts/IBMPlexSansKR-Bold.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
});

void main() {
  bool truncated(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  for (final scale in const [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('at 360 wide and text scale $scale the rules page keeps each '
        'of the four score tiles on one line', (tester) async {
      await _loadAppFonts(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HelpScreen(onStart: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      final lineHeight = tester.getSize(find.text('콤보')).height;
      for (final label in const ['Average', 'Good', 'Excellent']) {
        expect(
          tester.getSize(find.text(label)).height,
          lineHeight,
          reason: label,
        );
        expect(truncated(tester, label), isFalse, reason: label);
      }
      // +5 is short enough never to break: the others must match it.
      final pointsHeight = tester.getSize(find.text('+5').first).height;
      expect(tester.getSize(find.text('+10')).height, pointsHeight);
      expect(tester.getSize(find.text('+15')).height, pointsHeight);
      expect(truncated(tester, '+10'), isFalse);
      expect(truncated(tester, '+15'), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
