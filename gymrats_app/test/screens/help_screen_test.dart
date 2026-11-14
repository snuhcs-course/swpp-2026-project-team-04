import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/help_pictures.dart';
import 'package:gymrats_app/widgets/help_rules.dart';
import 'package:gymrats_app/widgets/sound_cues.dart';

void main() {
  /// [home] on a phone of [size]; 412×915 unless given.
  Future<void> show(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
    await tester.pumpAndSettle();
  }

  /// A page with a button that opens the tutorial, as '?' on home does.
  Widget homeBelow() => Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
        ),
        child: const Text('home'),
      ),
    ),
  );

  Future<void> openFromHome(WidgetTester tester) async {
    await show(tester, homeBelow());
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
  }

  Future<void> toLastPage(WidgetTester tester) async {
    for (var page = 1; page < HelpRules.pages.length; page++) {
      await tapNext(tester);
    }
  }

  /// The page whose picture is on screen (the pager may keep a neighbour).
  TutorialPage shownPage(WidgetTester tester) {
    final screen = Offset.zero & tester.view.physicalSize;
    final shown = find
        .byType(HelpPicture)
        .evaluate()
        .where(
          (element) => screen.contains(
            tester.getCenter(find.byElementPredicate((e) => e == element)),
          ),
        );
    return (shown.single.widget as HelpPicture).page;
  }

  final order = HelpRules.order;
  final pages = HelpRules.pages;

  testWidgets('다음 turns through every push-up page, then every squat page', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester, HelpScreen(onStart: () {}));
    expect(find.text('게임 규칙'), findsOneWidget);
    for (var index = 0; index < pages.length; index++) {
      if (index > 0) await tapNext(tester);
      final page = order[index];
      final name = HelpRules.exerciseName(page.exercise);
      final first = order.indexWhere((p) => p.exercise == page.exercise);
      final count = order.where((p) => p.exercise == page.exercise).length;
      expect(shownPage(tester), page);
      expect(find.text(pages[index].title), findsOneWidget);
      expect(find.text(pages[index].body), findsOneWidget);
      expect(find.text('$name ${index - first + 1} / $count'), findsOneWidget);
      expect(
        find.bySemanticsLabel('$name $count장 중 ${index - first + 1}장'),
        findsOneWidget,
      );
    }
    expect(find.text('다음'), findsNothing);
    expect(find.text('완료'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('이전 turns back, and is gone on the first page', (tester) async {
    await show(tester, HelpScreen(onStart: () {}));
    expect(find.text('이전'), findsNothing);
    await tapNext(tester);
    expect(shownPage(tester).step, TutorialStep.setup);
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(shownPage(tester).step, TutorialStep.intro);
    expect(find.text('이전'), findsNothing);
  });

  testWidgets('the tabs jump to an exercise and follow the page', (
    tester,
  ) async {
    SegmentedButton<ExerciseType> tabs() =>
        tester.widget<SegmentedButton<ExerciseType>>(
          find.byType(SegmentedButton<ExerciseType>),
        );

    await show(tester, HelpScreen(onStart: () {}));
    expect(tabs().selected, {ExerciseType.pushUp});

    await tester.tap(find.text('스쿼트'));
    await tester.pumpAndSettle();
    expect(
      shownPage(tester),
      const TutorialPage(ExerciseType.squat, TutorialStep.intro),
    );
    expect(tabs().selected, {ExerciseType.squat});
    expect(find.text('스쿼트 1 / 9'), findsOneWidget);

    // Back from the squat's first page is the push-up's last.
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(
      shownPage(tester),
      const TutorialPage(ExerciseType.pushUp, TutorialStep.report),
    );
    expect(tabs().selected, {ExerciseType.pushUp});

    // The tab already chosen stays where it is.
    await tester.tap(find.text('푸시업'));
    await tester.pumpAndSettle();
    expect(shownPage(tester).step, TutorialStep.report);

    await tester.tap(find.text('스쿼트'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('푸시업'));
    await tester.pumpAndSettle();
    expect(
      shownPage(tester),
      const TutorialPage(ExerciseType.pushUp, TutorialStep.intro),
    );
  });

  testWidgets('swiping turns the pages too', (tester) async {
    await show(tester, HelpScreen(onStart: () {}));
    await tester.fling(find.text(pages[0].title), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(pages[1].title), findsOneWidget);

    await tester.fling(find.text(pages[1].title), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(pages[0].title), findsOneWidget);
  });

  testWidgets('plays the main-menu music', (tester) async {
    await show(tester, HelpScreen(onStart: () {}));
    expect(
      tester.widget<SoundCues>(find.byType(SoundCues)).music,
      MusicCue.menu,
    );
  });

  testWidgets('after sign-up: no back arrow; 건너뛰기 calls onStart', (
    tester,
  ) async {
    var started = 0;
    await show(tester, HelpScreen(onStart: () => started++));
    expect(find.byTooltip('뒤로'), findsNothing);
    await tester.tap(find.text('건너뛰기'));
    expect(started, 1);
  });

  testWidgets('after sign-up: the last page has 완료 and its hint instead '
      'of 건너뛰기; it calls onStart', (tester) async {
    var started = 0;
    await show(tester, HelpScreen(onStart: () => started++));
    await toLastPage(tester);
    expect(find.text('건너뛰기'), findsNothing);
    expect(find.text('홈 화면의 ?로 다시 볼 수 있어요'), findsOneWidget);
    expect(started, 0);

    await tester.tap(find.text('완료'));
    expect(started, 1);
  });

  testWidgets('from home: no 건너뛰기, and back returns home', (tester) async {
    await openFromHome(tester);
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('from home: the last page\'s 완료 returns home', (tester) async {
    await openFromHome(tester);
    await toLastPage(tester);
    expect(find.text('홈 화면의 ?로 다시 볼 수 있어요'), findsNothing);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('titles, lines and the hint stay on one line, shrunk to fit', (
    tester,
  ) async {
    void expectOneLine(String text) {
      final words = find.text(text);
      expect(tester.widget<Text>(words).maxLines, 1, reason: text);
      expect(tester.widget<Text>(words).softWrap, isFalse, reason: text);
      expect(
        find.ancestor(of: words, matching: find.byType(FittedBox)),
        findsOneWidget,
        reason: text,
      );
    }

    await show(tester, HelpScreen(onStart: () {}), size: const Size(320, 640));
    for (var index = 0; index < pages.length; index++) {
      if (index > 0) await tapNext(tester);
      expectOneLine(pages[index].title);
      expectOneLine(pages[index].body);
      expect(tester.takeException(), isNull);
    }
    expectOneLine('홈 화면의 ?로 다시 볼 수 있어요');
  });

  for (final size in const [Size(412, 915), Size(360, 740)]) {
    testWidgets('every page fits ${size.width.toInt()}×${size.height.toInt()}: '
        'no overflow, the one button on screen', (tester) async {
      await show(tester, HelpScreen(onStart: () {}), size: size);
      for (var page = 0; page < pages.length; page++) {
        if (page > 0) await tapNext(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(AccentButton), findsOneWidget);
        expect(
          tester.getBottomLeft(find.byType(AccentButton)).dy,
          lessThanOrEqualTo(size.height),
        );
      }
    });
  }
}
