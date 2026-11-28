import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/tutorial_viewmodel.dart';

/// Tests otherwise draw every letter as the same square, so only here does
/// the text of the rules and the result have its real width. In its own
/// file, as the fonts stay loaded for the rest of the run.
Future<void> _loadAppFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final entry in const {
    AppFonts.number: ['assets/fonts/Oxanium-Bold.ttf'],
    AppFonts.display: ['assets/fonts/DoHyeon-Regular.ttf'],
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
    testWidgets('at 360 wide and text scale $scale the tutorial\'s grade '
        'pages keep each grade and its points on one line', (tester) async {
      await _loadAppFonts(tester);
      // The tutorial's pictures move until the device asks for reduced
      // motion (A12); held still, pumpAndSettle returns.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
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
      // The push-up's grade pages follow intro, setup and battle.
      // A12: the grades' bands and the fail page's reject sign, on the
      // game screen in each page's bubble.
      final pager = tester.widget<PageView>(find.byType(PageView));
      final pages = TutorialViewModel.pagesFor(battleRules);
      for (final (step, label) in const [
        (TutorialStep.excellent, 'EXCELLENT'),
        (TutorialStep.good, 'GOOD'),
        (TutorialStep.average, 'AVERAGE'),
        (TutorialStep.fail, '무릎을\n바닥에서\n떼요'),
      ]) {
        final index = pages.indexWhere(
          (page) => page.exercise == ExerciseType.pushUp && page.step == step,
        );
        pager.controller!.jumpToPage(index);
        await tester.pumpAndSettle();
        final viewport = tester.getRect(find.byType(PageView));
        final rect = tester.getRect(find.text(label));
        expect(viewport.contains(rect.topLeft), isTrue, reason: label);
        expect(viewport.contains(rect.bottomRight), isTrue, reason: label);
        expect(truncated(tester, label), isFalse, reason: label);
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }
}
