import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/screens/coach_screen.dart';
import 'package:gymrats_app/services/feedback/coach_script.dart';
import 'package:gymrats_app/services/feedback/goal_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/coach_viewmodel.dart';
import 'package:gymrats_app/widgets/coach_graphics.dart';
import 'package:gymrats_app/widgets/coach_parts.dart';
import 'package:gymrats_app/widgets/coach_stage.dart';

import '../support/goal_fixtures.dart';

/// The design's battle: a squat, 18 counted, 3 shallow late.
final _report = coachReport(
  valid: designPace(),
  rejected: const [
    (19.4, RejectReason.shallowSquat),
    (24.2, RejectReason.shallowSquat),
    (28.8, RejectReason.shallowSquat),
  ],
);

var _fontsLoaded = false;

/// The app's fonts, so the widths are the phone's (tests otherwise draw
/// every letter as one square).
Future<void> _loadFonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  await tester.runAsync(() async {
    for (final entry in const {
      AppFonts.number: [
        'assets/fonts/Oxanium-Bold.ttf',
        'assets/fonts/Oxanium-ExtraBold.ttf',
      ],
      AppFonts.display: ['assets/fonts/DoHyeon-Regular.ttf'],
      AppFonts.body: [
        'assets/fonts/IBMPlexSansKR-Regular.ttf',
        'assets/fonts/IBMPlexSansKR-Medium.ttf',
        'assets/fonts/IBMPlexSansKR-SemiBold.ttf',
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
}

void main() {
  late CoachViewModel viewModel;
  late MemoryGoalStore store;

  /// Opens the talk above a report page, as the result screen does.
  Future<void> open(
    WidgetTester tester, {
    bool atGoal = false,
    bool reduced = false,
    Size size = const Size(360, 780),
    double textScale = 1,
    String characterId = 'seal',
  }) async {
    await _loadFonts(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    if (reduced) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    store = MemoryGoalStore();
    viewModel = CoachViewModel(
      report: _report,
      characterId: characterId,
      summary: '스쿼트 · RepBot 중수 · 승리',
      goalStore: store,
      accountId: 7,
    );
    addTearDown(viewModel.dispose);
    await viewModel.load();
    viewModel
      ..setInstant(reduced)
      ..start(atGoal: atGoal);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorKey: navigator,
        home: const Scaffold(body: Text('report')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => CoachScreen(viewModel: viewModel),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every letter of the page now out, as a tap does.
  Future<void> showAll(WidgetTester tester) async {
    if (!viewModel.state.fullyShown) {
      await tester.tap(find.byKey(const ValueKey('coach-dialog')));
      await tester.pump();
    }
  }

  Future<void> next(WidgetTester tester) async {
    await showAll(tester);
    await tester.tap(find.byKey(const ValueKey('coach-dialog')));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Rect characterRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('coach-character')));

  double characterScale(WidgetTester tester) => tester
      .widget<AnimatedScale>(
        find.ancestor(
          of: find.byKey(const ValueKey('coach-character')),
          matching: find.byType(AnimatedScale),
        ),
      )
      .scale;

  double characterLift(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .ancestor(
              of: find.byType(AnimatedScale),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .getTranslation()
      .y;

  group('typing (spec 3, 움직임)', () {
    testWidgets('one letter every 32 ms; the character rises 4 every '
        'third letter while it talks', (tester) async {
      await open(tester);
      final start = viewModel.state.revealed;
      await tester.pump(CoachScreen.letterTime * 3);
      expect(viewModel.state.revealed, start + 3);
      final lifts = <double>{};
      for (var i = 0; i < 6; i++) {
        await tester.pump(CoachScreen.letterTime);
        lifts.add(characterLift(tester));
      }
      expect(lifts, {0.0, -CoachStage.bob});
    });

    testWidgets('a tap while it types shows the whole line; the next mark '
        'shows and blinks; the next tap goes on', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('coach-next-mark')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('coach-dialog')));
      await tester.pump();
      expect(viewModel.state.fullyShown, isTrue);
      expect(characterLift(tester), 0);
      final shown = <bool>{};
      for (var i = 0; i < 4; i++) {
        shown.add(
          find.byKey(const ValueKey('coach-next-mark')).evaluate().isNotEmpty,
        );
        await tester.pump(CoachScreen.letterTime * CoachScreen.blinkTicks);
      }
      expect(shown, {true, false});
      await tester.tap(find.byKey(const ValueKey('coach-dialog')));
      await tester.pump();
      expect(viewModel.state.index, 1);
    });

    testWidgets('the box is a button named 전부 보기 while it types and 다음 '
        'after; the whole line is read once, when it is out (spec 7)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      expect(find.bySemanticsLabel('전부 보기'), findsOneWidget);
      final line = viewModel.state.line!.text;
      expect(find.bySemanticsLabel('물렁범, $line'), findsNothing);
      await showAll(tester);
      expect(find.bySemanticsLabel('다음'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('물렁범, $line')),
        isSemantics(isLiveRegion: true),
      );
      expect(find.bySemanticsLabel('건너뛰기'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('the layout (spec 3, UxDlg A)', () {
    testWidgets('the pill, 건너뛰기, the name tag and the dots, one per page', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('스쿼트 · RepBot 중수 · 승리'), findsOneWidget);
      expect(find.text('건너뛰기'), findsOneWidget);
      expect(find.text('물렁범'), findsOneWidget);
      expect(find.text('대화창을 누르면 다음으로'), findsOneWidget);
      final dots = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('coach-dot-'),
      );
      expect(dots, findsNWidgets(viewModel.state.pageCount));
      expect(
        tester.getSize(find.byKey(const ValueKey('coach-dot-0'))).width,
        20,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('coach-dot-1'))).width,
        8,
      );
      expect(
        tester.getSize(find.text('건너뛰기')).height,
        lessThanOrEqualTo(CoachStage.topBarHeight),
      );
    });

    testWidgets('a card above: the character at 1x in the middle, no disc; '
        'its feet behind the box', (tester) async {
      await open(tester);
      expect(find.byType(CoachGraphicCard), findsOneWidget);
      expect(characterScale(tester), CoachStage.cardScale);
      expect(characterRect(tester).center.dx, closeTo(180, 0.5));
      final box = tester.getRect(find.byKey(const ValueKey('coach-dialog')));
      expect(characterRect(tester).top + 150, closeTo(box.top + 22, 1));
    });

    testWidgets('no card (the end): 1.75x on the white disc', (tester) async {
      await open(tester, atGoal: true, reduced: true);
      await tester.tap(find.text('건너뛰기'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CoachGraphicCard), findsNothing);
      expect(characterScale(tester), CoachStage.bigScale);
    });

    testWidgets('at the question: the goals and 사양할래 at the right, the '
        'character 1.2x at x 84; a tap does not go on', (tester) async {
      await open(tester, atGoal: true);
      expect(find.text('사양할래'), findsNothing);
      expect(find.text('대화창을 누르면 바로 다 보여요'), findsOneWidget);
      await showAll(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('위에서 하나 골라 줘'), findsOneWidget);
      final [record, weak] = viewModel.state.script!.suggestions;
      expect(find.text(record.title), findsOneWidget);
      expect(find.text(record.subtitle), findsOneWidget);
      expect(find.text(weak.title), findsOneWidget);
      expect(find.text('사양할래'), findsOneWidget);
      expect(characterScale(tester), CoachStage.choiceScale);
      expect(characterRect(tester).center.dx, closeTo(84, 0.5));
      for (final choice in [record.title, '사양할래']) {
        expect(
          tester.getSize(find.widgetWithText(InkWell, choice)).height,
          greaterThanOrEqualTo(44),
        );
      }
      expect(find.byKey(const ValueKey('coach-next-mark')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('coach-dialog')));
      await tester.pump();
      expect(viewModel.state.onQuestion, isTrue);
    });

    for (final (name, size, scale) in const [
      ('360x780', Size(360, 780), 1.0),
      ('393x852', Size(393, 852), 1.0),
      ('320x640 at 1.3x text', Size(320, 640), 1.3),
      ('360x780 at 2x text (capped at 1.5x)', Size(360, 780), 2.0),
    ]) {
      testWidgets('every page fits $name without an overflow; every choice '
          'is above the dialog box and can be tapped', (tester) async {
        await open(tester, size: size, textScale: scale, reduced: true);
        var pages = 0;
        while (!viewModel.state.onQuestion) {
          expect(tester.takeException(), isNull, reason: 'page $pages');
          await next(tester);
          pages++;
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        final box = tester.getRect(find.byKey(const ValueKey('coach-dialog')));
        for (final title in [
          for (final goal in viewModel.state.script!.suggestions) goal.title,
          '사양할래',
        ]) {
          final choice = find.widgetWithText(InkWell, title);
          await tester.ensureVisible(choice);
          await tester.pump();
          expect(
            tester.getRect(choice).bottom,
            lessThanOrEqualTo(box.top),
            reason: title,
          );
        }
        await tester.tap(find.text('사양할래'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(viewModel.state.answered, isTrue);
        expect(tester.takeException(), isNull);
        await next(tester);
        expect(viewModel.state.ended, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('choosing and ending', () {
    testWidgets('a goal: saved for this account with the character, and the '
        'goal card with its title', (tester) async {
      await open(tester, atGoal: true, reduced: true);
      final goal = viewModel.state.script!.suggestions.first;
      await tester.tap(find.text(goal.title));
      await tester.pump(const Duration(milliseconds: 400));
      final saved = store.goals[(7, ExerciseType.squat)]!;
      expect(saved.title, goal.title);
      expect(saved.characterId, 'seal');
      expect(find.byType(CoachGoalCard), findsOneWidget);
      expect(find.text('다음 판 목표'), findsOneWidget);
      expect(find.text('스쿼트를 고르면 운동 선택과 대결 시작 화면에 떠요'), findsOneWidget);
    });

    testWidgets('사양할래: no goal; then the end with 처음부터 다시 and 리포트로', (
      tester,
    ) async {
      await open(tester, atGoal: true, reduced: true);
      await tester.tap(find.text('사양할래'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.goals, isEmpty);
      await next(tester);
      expect(find.text('처음부터 다시'), findsOneWidget);
      expect(find.text('리포트로'), findsOneWidget);
      // 건너뛰기 and the dots are gone at the end.
      expect(find.text('건너뛰기'), findsNothing);
      expect(find.byKey(const ValueKey('coach-dot-0')), findsNothing);
      await tester.tap(find.text('처음부터 다시'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(viewModel.state.index, 0);
    });

    testWidgets('리포트로 and system back return to the report', (tester) async {
      await open(tester, reduced: true);
      viewModel
        ..skip()
        ..skip();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('리포트로'));
      await tester.pumpAndSettle();
      expect(find.text('report'), findsOneWidget);
      expect(find.byType(CoachScreen), findsNothing);
    });

    testWidgets('back from the middle of the talk: nothing is saved', (
      tester,
    ) async {
      await open(tester, reduced: true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CoachScreen), findsNothing);
      expect(store.goals, isEmpty);
    });

    testWidgets('건너뛰기 at the top: to the question, then to the end', (
      tester,
    ) async {
      await open(tester, reduced: true);
      await tester.tap(find.text('건너뛰기'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(viewModel.state.onQuestion, isTrue);
      await tester.tap(find.text('건너뛰기'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(viewModel.state.ended, isTrue);
    });
  });

  group('reduced motion', () {
    testWidgets('whole lines at once, no rise, a steady next mark', (
      tester,
    ) async {
      await open(tester, reduced: true);
      expect(viewModel.state.fullyShown, isTrue);
      expect(characterLift(tester), 0);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(const ValueKey('coach-next-mark')), findsOneWidget);
        await tester.pump(CoachScreen.letterTime * CoachScreen.blinkTicks);
      }
    });

    testWidgets('turned on while it types: the rest of the line shows', (
      tester,
    ) async {
      await open(tester);
      expect(viewModel.state.fullyShown, isFalse);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.pump();
      expect(viewModel.state.fullyShown, isTrue);
    });
  });

  group('four lines at most (spec 3; with the app\'s fonts)', () {
    /// The box's text room on a 360 phone: 360 - 2 x 14 - 2 x 3 - 2 x 24.
    const room = 278.0;

    int linesOf(WidgetTester tester, CoachLine line) {
      final style = AppTheme.light.textTheme.coachLine;
      final painter = TextPainter(
        text: TextSpan(
          text: CoachMarkedText.keepWords(line.text),
          style: style.copyWith(fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: room);
      addTearDown(painter.dispose);
      return painter.computeLineMetrics().length;
    }

    testWidgets('every line of a squat and a push-up battle, for every '
        'character', (tester) async {
      await _loadFonts(tester);
      final pushUp = coachReport(
        exercise: ExerciseType.pushUp,
        valid: designPace(),
        rejected: const [
          (3, RejectReason.phoneMoved),
          (18, RejectReason.incompleteExtension),
          (22, RejectReason.incompleteExtension),
          (26, RejectReason.incompleteExtension),
        ],
      );
      for (final report in [_report, pushUp]) {
        for (final id in const [
          'mouse',
          'kangaroo',
          'bear',
          'penguin',
          'seal',
        ]) {
          final script = CoachScript.build(
            coachInputOf(
              report,
              characterId: id,
              earlier: [
                for (var i = 0; i < 5; i++)
                  earlierBattle(
                    16,
                    buckets: const [3, 3, 3, 3, 2, 2],
                    combo: 4,
                  ),
              ],
            ),
          );
          for (final line in [
            ...script.talk,
            script.question,
            for (final goal in script.suggestions) script.answer(goal),
            script.answer(null),
            script.end,
          ]) {
            expect(
              linesOf(tester, line),
              lessThanOrEqualTo(4),
              reason: line.text,
            );
          }
        }
      }
    });
  });
}
