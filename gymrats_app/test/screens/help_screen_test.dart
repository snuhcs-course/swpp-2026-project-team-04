import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/telemetry/telemetry_service.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/help_pictures.dart';
import 'package:gymrats_app/widgets/tutorial_modes.dart';
import 'package:gymrats_app/widgets/help_rules.dart';
import 'package:gymrats_app/viewmodels/tutorial_viewmodel.dart';
import 'package:gymrats_app/widgets/sound_cues.dart';

void main() {
  /// [home] on a phone of [size]; 412×915 unless given. The device asks
  /// for reduced motion, so the moving pictures (the game page's clip, the
  /// first pages' person) hold still and pumpAndSettle returns.
  Future<void> show(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(412, 915),
    double textScale = 1,
  }) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

  testWidgets('다음 turns through the two game pages, every push-up page, '
      'then every squat page', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester, HelpScreen(onStart: () {}));
    expect(find.text('게임 규칙'), findsOneWidget);
    for (var index = 0; index < pages.length; index++) {
      if (index > 0) await tapNext(tester);
      final page = order[index];
      final name = HelpRules.sectionName(page.exercise);
      final first = order.indexWhere((p) => p.exercise == page.exercise);
      final count = order.where((p) => p.exercise == page.exercise).length;
      expect(shownPage(tester), page);
      expect(find.text(pages[index].title), findsOneWidget);
      if (pages[index].hasBody) {
        expect(find.text(pages[index].body), findsOneWidget);
      } else {
        // The KO and modes pages are told by their titles alone: no empty
        // line under them.
        expect(page.step, anyOf(TutorialStep.ko, TutorialStep.modes));
        expect(find.text(''), findsNothing);
      }
      expect(
        find.text(
          page.exercise == null ? name : '$name ${index - first + 1} / $count',
        ),
        findsOneWidget,
      );
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
    expect(shownPage(tester), TutorialPage.modes);
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(shownPage(tester), TutorialPage.welcome);
    expect(find.text('이전'), findsNothing);
  });

  testWidgets('the tabs jump to an exercise and follow the page', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    /// The exercise whose tab a screen reader hears as chosen.
    Set<String> tabs() => {
      for (final name in const ['푸시업', '스쿼트'])
        if (tester
                .getSemantics(find.bySemanticsLabel(name))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue)
          name,
    };

    /// Taps a tab where it takes taps, over the drawn pill.
    Future<void> tapTab(String name) async {
      await tester.tap(find.bySemanticsLabel(name));
      await tester.pumpAndSettle();
    }

    await show(tester, HelpScreen(onStart: () {}));
    // The page about the game belongs to neither exercise.
    expect(find.text('게임 소개'), findsOneWidget);
    expect(tabs(), isEmpty);

    await tapTab('스쿼트');
    expect(
      shownPage(tester),
      const TutorialPage(ExerciseType.squat, TutorialStep.intro),
    );
    expect(tabs(), {'스쿼트'});
    expect(find.text('스쿼트 1 / 10'), findsOneWidget);

    // Back from the squat's first page is the push-up's last.
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(
      shownPage(tester),
      const TutorialPage(ExerciseType.pushUp, TutorialStep.report),
    );
    expect(tabs(), {'푸시업'});

    // The tab already chosen stays where it is.
    await tapTab('푸시업');
    expect(shownPage(tester).step, TutorialStep.report);

    await tapTab('스쿼트');
    await tapTab('푸시업');
    expect(
      shownPage(tester),
      const TutorialPage(ExerciseType.pushUp, TutorialStep.intro),
    );
    handle.dispose();
  });

  testWidgets('a screen reader hears the two tabs as tabs of one tab bar, '
      'with which is chosen; each takes taps 48 high or more', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester, HelpScreen(onStart: () {}), size: const Size(360, 780));
    await tapNext(tester);
    await tapNext(tester);
    for (final (name, chosen, position) in const [
      ('푸시업', true, '탭 2개 중 1번째'),
      ('스쿼트', false, '탭 2개 중 2번째'),
    ]) {
      final tab = find.bySemanticsLabel(name);
      expect(tab, findsOneWidget, reason: name);
      final node = tester.getSemantics(tab);
      final data = node.getSemanticsData();
      expect(data.role, SemanticsRole.tab, reason: name);
      expect(
        data.flagsCollection.isSelected,
        chosen ? Tristate.isTrue : Tristate.isFalse,
        reason: name,
      );
      // What Android reads, which has no tab role: a button, as the
      // segments before were, and where the tab is among the tabs.
      expect(data.flagsCollection.isButton, isTrue, reason: name);
      expect(data.value, position, reason: name);
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: name);
      expect(node.rect.height, greaterThanOrEqualTo(48), reason: name);
      expect(node.rect.width, greaterThanOrEqualTo(48), reason: name);
      expect(node.parent!.getSemanticsData().role, SemanticsRole.tabBar);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

    // A tap just inside the top of the 48, above the drawn pill's 46, still
    // jumps.
    final squat = tester.getRect(find.bySemanticsLabel('스쿼트'));
    expect(squat.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    await tester.tapAt(Offset(squat.center.dx, squat.top + 0.5));
    await tester.pumpAndSettle();
    expect(shownPage(tester).exercise, ExerciseType.squat);
    handle.dispose();
  });

  testWidgets('the tabs are drawn as the design\'s pill: 46 high with a 2 ink '
      'edge, the chosen half lime and bold, none chosen on the game page', (
    tester,
  ) async {
    await show(tester, HelpScreen(onStart: () {}), size: const Size(360, 780));
    final pill = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.minHeight == 46 &&
          widget.decoration is ShapeDecoration &&
          (widget.decoration! as ShapeDecoration).shape is StadiumBorder,
    );
    expect(pill, findsOneWidget);
    expect(tester.getSize(pill).height, 46);
    final edge =
        ((tester.widget<Container>(pill).decoration! as ShapeDecoration).shape
                as StadiumBorder)
            .side;
    expect(edge.color, AppColors.ink);
    expect(edge.width, 2);

    /// The fill behind a tab's name, and the name's weight.
    /// (Page 2's picture names the exercises too; the tab comes first.)
    (Color?, FontWeight?) half(String name) {
      final tab = find.text(name).first;
      final box = tester.widget<DecoratedBox>(
        find.ancestor(of: tab, matching: find.byType(DecoratedBox)).first,
      );
      return (
        (box.decoration as BoxDecoration).color,
        tester.widget<Text>(tab).style?.fontWeight,
      );
    }

    expect(half('푸시업'), (AppColors.card, FontWeight.w500));
    expect(half('스쿼트'), (AppColors.card, FontWeight.w500));
    // The second game page belongs to neither exercise either.
    await tapNext(tester);
    expect(half('푸시업'), (AppColors.card, FontWeight.w500));
    expect(half('스쿼트'), (AppColors.card, FontWeight.w500));
    await tapNext(tester);
    expect(half('푸시업'), (AppColors.accent, FontWeight.w700));
    expect(half('스쿼트'), (AppColors.card, FontWeight.w500));
  });

  testWidgets('the card is white with a 2 ink edge and 22 corners', (
    tester,
  ) async {
    await show(tester, HelpScreen(onStart: () {}), size: const Size(360, 780));
    final card = find
        .ancestor(
          of: find.byType(HelpPicture).first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.position == DecorationPosition.foreground,
          ),
        )
        .first;
    final edge = tester.widget<DecoratedBox>(card).decoration as BoxDecoration;
    expect(edge.border, Border.all(color: AppColors.ink, width: 2));
    expect(edge.borderRadius, const BorderRadius.all(Radius.circular(22)));
    final fill = tester.widget<ColoredBox>(
      find.descendant(of: card, matching: find.byType(ColoredBox)).first,
    );
    expect(fill.color, AppColors.card);
  });

  testWidgets('the pictures keep their own size under a large system text '
      'size; the page\'s words follow it', (tester) async {
    await show(
      tester,
      HelpScreen(onStart: () {}),
      size: const Size(360, 780),
      textScale: 1.3,
    );
    final inPicture = find
        .descendant(
          of: find.byType(HelpPicture).first,
          matching: find.byType(Text),
        )
        .first;
    expect(
      MediaQuery.textScalerOf(tester.element(inPicture)),
      TextScaler.noScaling,
    );
    expect(
      MediaQuery.textScalerOf(tester.element(find.text(pages[0].title)))
          .scale(10),
      moreOrLessEquals(13),
    );
  });

  testWidgets('at 360 wide the picture fills its card edge to edge: 316×248, '
      'the two game pages 316×326', (tester) async {
    await show(tester, HelpScreen(onStart: () {}), size: const Size(360, 780));
    Size picture() => tester.getSize(
      find.byWidgetPredicate(
        (widget) => widget is HelpPicture && widget.page == shownPage(tester),
      ),
    );
    expect(picture(), const Size(316, 326));
    expect(HelpPicture.sizeOf(TutorialPage.welcome), const Size(316, 326));
    await tapNext(tester);
    expect(picture(), const Size(316, 326));
    expect(HelpPicture.sizeOf(TutorialPage.modes), const Size(316, 326));
    await tapNext(tester);
    expect(picture(), const Size(316, 248));
    expect(HelpPicture.sizeOf(order[2]), const Size(316, 248));
  });

  testWidgets('the current page has the long lime dot with an ink edge; 이전 '
      'is 104×58 beside the one 다음', (tester) async {
    await show(tester, HelpScreen(onStart: () {}), size: const Size(360, 780));
    for (var page = 0; page < 3; page++) {
      await tapNext(tester);
    }
    final dots = find.byType(AnimatedContainer);
    expect(dots, findsNWidgets(11));
    for (var index = 0; index < 11; index++) {
      final shape =
          tester.widget<AnimatedContainer>(dots.at(index)).decoration!
              as ShapeDecoration;
      final side = (shape.shape as StadiumBorder).side;
      if (index == 1) {
        expect(shape.color, AppColors.accent);
        expect(side.color, AppColors.ink);
        expect(tester.getSize(dots.at(index)), const Size(26, 10));
      } else {
        expect(shape.color, AppColors.border, reason: '$index');
        expect(side, BorderSide.none, reason: '$index');
        expect(tester.getSize(dots.at(index)), const Size(10, 10));
      }
    }
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, '이전')),
      const Size(104, 58),
    );
    expect(find.byType(AccentButton), findsOneWidget);
  });

  testWidgets('page 2 about the game: its title alone, 게임 소개, two dots '
      'with the second on, and the modes picture', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester, HelpScreen(onStart: () {}), size: const Size(360, 780));
    final dots = find.byType(AnimatedContainer);
    expect(dots, findsNWidgets(2));
    expect(find.bySemanticsLabel('게임 소개 2장 중 1장'), findsOneWidget);
    await tapNext(tester);
    expect(shownPage(tester), TutorialPage.modes);
    expect(find.text('온라인 대결과 아케이드'), findsOneWidget);
    expect(find.text('게임 소개'), findsOneWidget);
    expect(dots, findsNWidgets(2));
    expect(tester.getSize(dots.at(0)), const Size(10, 10));
    expect(tester.getSize(dots.at(1)), const Size(26, 10));
    expect(find.bySemanticsLabel('게임 소개 2장 중 2장'), findsOneWidget);
    expect(find.byType(TutorialModes), findsOneWidget);
    expect(find.bySemanticsLabel(TutorialModes.label), findsOneWidget);
    handle.dispose();
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
      if (pages[index].hasBody) expectOneLine(pages[index].body);
      expect(tester.takeException(), isNull);
    }
    expectOneLine('홈 화면의 ?로 다시 볼 수 있어요');
  });

  for (final (size, scale) in const [
    (Size(412, 915), 1.0),
    (Size(360, 740), 1.0),
    (Size(360, 780), 1.3),
    (Size(320, 640), 1.0),
  ]) {
    testWidgets('every page fits ${size.width.toInt()}×${size.height.toInt()} '
        'at text ×$scale: no overflow, the one button on screen', (
      tester,
    ) async {
      await show(
        tester,
        HelpScreen(onStart: () {}),
        size: size,
        textScale: scale,
      );
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

  group('튜토리얼 텔레메트리 (P17)', () {
    Future<Telemetry> showWith(WidgetTester tester, Widget home) async {
      final telemetry = Telemetry();
      // Held still, as in [show], so pumpAndSettle returns.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Provider<Telemetry>.value(
          value: telemetry,
          child: MaterialApp(theme: AppTheme.light, home: home),
        ),
      );
      await tester.pumpAndSettle();
      return telemetry;
    }

    List<Map<String, Object?>> ends(Telemetry t) =>
        t.pending.where((e) => e['event'] == 'tutorial_finished').toList();

    testWidgets('the first page records the start; 건너뛰기 records skipped '
        'once', (tester) async {
      var started = 0;
      final telemetry = await showWith(
        tester,
        HelpScreen(onStart: () => started++),
      );
      expect(telemetry.pending.single['event'], 'tutorial_started');
      expect(
        telemetry.pending.single['pages_total'],
        TutorialViewModel().pages.length,
      );
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpWidget(const SizedBox());
      expect(started, 1);
      expect(ends(telemetry).single['result'], 'skipped');
      expect(ends(telemetry).single['last_page'], 1);
    });

    testWidgets('완료 on the last page records completed', (tester) async {
      final telemetry = await showWith(tester, HelpScreen(onStart: () {}));
      final pages = TutorialViewModel().pages.length;
      for (var i = 1; i < pages; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('완료'));
      await tester.pumpWidget(const SizedBox());
      expect(ends(telemetry).single['result'], 'completed');
      expect(ends(telemetry).single['last_page'], pages);
    });

    testWidgets('closing the onboarding tutorial mid-way is skipped at its '
        'page', (tester) async {
      final telemetry = await showWith(tester, HelpScreen(onStart: () {}));
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(ends(telemetry).single['result'], 'skipped');
      expect(ends(telemetry).single['last_page'], 2);
    });

    testWidgets('the help opened again from home is not the onboarding: '
        'nothing is recorded', (tester) async {
      final telemetry = await showWith(tester, const HelpScreen());
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(telemetry.pending, isEmpty);
    });
  });
}
