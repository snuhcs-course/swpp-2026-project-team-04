import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_mode_card.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';

import '../support/fakes.dart';

/// Tests otherwise draw every letter as the same square. The fonts stay loaded
/// for the rest of the run, so the tests that load them come last in the file.
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
  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  int taps = 0;

  /// Two cards side by side, as home has them.
  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(360, 780),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Align(
              alignment: Alignment.topCenter,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: BattleModeCard(
                        title: '온라인 1v1',
                        line: '사람과 실시간 대결',
                        picture: const BattleModePicture.online(),
                        main: true,
                        onTap: () => taps++,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: BattleModeCard(
                        title: 'AI 1v1',
                        line: '봇과 난이도별 대결',
                        picture: const BattleModePicture.bot(),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Whether [figure] is drawn flipped left to right.
  bool mirrored(WidgetTester tester, Finder figure) => find
      .ancestor(of: figure, matching: find.byType(Transform))
      .evaluate()
      .map((element) => (element.widget as Transform).transform)
      .any((matrix) => matrix.storage[0] < 0);

  ShapeBorder? shapeOf(WidgetTester tester, String title) => tester
      .widget<Card>(
        find.ancestor(of: find.text(title), matching: find.byType(Card)),
      )
      .shape;

  testWidgets('shows its picture over its title over its line', (tester) async {
    await show(tester);
    final picture = tester.getRect(find.byType(BattleModePicture).first);
    final title = tester.getRect(find.text('온라인 1v1'));
    final line = tester.getRect(find.text('사람과 실시간 대결'));
    expect(picture.bottom, lessThanOrEqualTo(title.top));
    expect(title.bottom, lessThanOrEqualTo(line.top));
    expect(title.left, line.left);
  });

  testWidgets('tapping anywhere on it calls back', (tester) async {
    await show(tester);
    await tester.tap(find.text('VS').first);
    await tester.tap(find.text('사람과 실시간 대결'));
    expect(taps, 2);
  });

  testWidgets('both cards are the same size, and at least 48 tall', (
    tester,
  ) async {
    await show(tester);
    final left = tester.getRect(find.byType(BattleModeCard).first);
    final right = tester.getRect(find.byType(BattleModeCard).last);
    expect(left.size, right.size);
    expect(left.right, lessThan(right.left));
    expect(left.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the main card has the lime edge, and the other the theme\'s', (
    tester,
  ) async {
    await show(tester);
    final main = shapeOf(tester, '온라인 1v1')! as RoundedRectangleBorder;
    expect(main.side.color, AppColors.accent);
    expect(main.side.width, 2);
    expect(shapeOf(tester, 'AI 1v1'), isNull);
  });

  testWidgets('a screen reader hears one sentence and can tap it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester);
    final card = find.semantics.byLabel('온라인 1v1, 사람과 실시간 대결');
    expect(card, findsOne);
    tester.semantics.tap(card);
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('online pits the user in lime against a person in pink', (
    tester,
  ) async {
    await show(tester);
    final picture = find.byType(BattleModePicture).first;
    final figures = tester
        .widgetList<ExercisePictogram>(
          find.descendant(
            of: picture,
            matching: find.byType(ExercisePictogram),
          ),
        )
        .toList();
    expect(figures.map((figure) => figure.color), [
      AppColors.accent,
      AppColors.opponent,
    ]);
    expect(figures.map((figure) => figure.exercise), [
      ExerciseType.pushUp,
      ExerciseType.pushUp,
    ]);
    expect(
      find.descendant(of: picture, matching: find.text('VS')),
      findsOneWidget,
    );
    // The two face each other: only the user's is mirrored.
    final figuresFinder = find.descendant(
      of: picture,
      matching: find.byType(ExercisePictogram),
    );
    expect(mirrored(tester, figuresFinder.first), isTrue);
    expect(mirrored(tester, figuresFinder.last), isFalse);
  });

  testWidgets('"VS" sits level on both cards', (tester) async {
    await show(tester);
    final online = tester.getRect(find.text('VS').first);
    final bot = tester.getRect(find.text('VS').last);
    expect(online.top, bot.top);
  });

  testWidgets('AI pits the user, facing it, against RepBot in pink', (
    tester,
  ) async {
    await show(tester);
    final picture = find.byType(BattleModePicture).last;
    final user = find.descendant(
      of: picture,
      matching: find.byType(ExercisePictogram),
    );
    expect(user, findsOneWidget);
    expect(tester.widget<ExercisePictogram>(user).color, AppColors.accent);
    expect(mirrored(tester, user), isTrue);
    expect(
      tester.renderObject(
        find.descendant(of: picture, matching: find.byType(CustomPaint)).last,
      ),
      paints
        ..line(p1: const Offset(3.2, 40.8), strokeWidth: 1.5)
        ..rrect(
          rrect: RRect.fromRectXY(
            const Rect.fromLTWH(14, 40.8 - 24, 30, 24),
            6,
            6,
          ),
          color: AppColors.opponent,
          strokeWidth: 3,
        )
        ..line(color: AppColors.opponent, strokeWidth: 3)
        ..circle(color: AppColors.opponent)
        ..circle(color: AppColors.opponent)
        ..circle(color: AppColors.opponent),
    );
  });

  testWidgets("RepBot stands on the floor of the user's figure", (
    tester,
  ) async {
    await show(tester);
    final picture = find.byType(BattleModePicture).last;
    final figure = tester.getRect(
      find.descendant(of: picture, matching: find.byType(ExercisePictogram)),
    );
    final bot = tester.getRect(
      find.descendant(of: picture, matching: find.byType(CustomPaint)).last,
    );
    // The figure's floor is at 36 of its 40 design height.
    final floor = figure.top + figure.height * 36 / 40;
    expect(floor, moreOrLessEquals(bot.top + 40.8, epsilon: 0.5));
  });

  // Last in the file: the fonts stay loaded for the rest of the run.
  group('with the real fonts', () {
    /// The width a text was given, after any FittedBox above it scaled it.
    double shownWidth(WidgetTester tester, Finder text) {
      final box = tester.renderObject<RenderBox>(text);
      return box.localToGlobal(Offset(box.size.width, 0)).dx -
          box.localToGlobal(Offset.zero).dx;
    }

    /// The real home: the cards have exactly the room they have on a phone.
    Future<void> showHome(WidgetTester tester) async {
      await _loadAppFonts(tester);
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeUserRepository()..recent = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(
            createViewModel: () => HomeViewModel(repository: repository),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('every text fits at its full size on home at 360 wide', (
      tester,
    ) async {
      await showHome(tester);
      expect(find.byType(BattleModeCard), findsNWidgets(2));
      final texts = find.descendant(
        of: find.byType(BattleModeCard),
        matching: find.byType(Text),
      );
      expect(texts, findsNWidgets(6));
      for (final element in texts.evaluate()) {
        final text = find.byWidget(element.widget).first;
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
        );
        expect(
          shownWidth(tester, text),
          moreOrLessEquals(tester.getSize(text).width, epsilon: 0.01),
          reason: '${element.widget}',
        );
      }
      final detail = find.text('30초 · 점수 높은 쪽 승리');
      expect(
        tester.renderObject<RenderParagraph>(detail).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('home does not overflow at text scale 2', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await showHome(tester);
      expect(find.byType(BattleModeCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at 320 wide or at text scale 2', (
      tester,
    ) async {
      await _loadAppFonts(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await show(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });
  });
}
