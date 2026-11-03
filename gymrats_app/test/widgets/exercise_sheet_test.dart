import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';

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

  ExerciseType? answer;
  bool answered = false;

  /// Opens the sheet from a page with one button.
  Future<void> open(
    WidgetTester tester, {
    UserProfile profile = const UserProfile(name: '우현'),
    Size size = const Size(360, 780),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    answer = null;
    answered = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                answer = await showExerciseSheet(
                  context,
                  subtitle: '온라인 1v1 · 30초',
                  profile: profile,
                );
                answered = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsOneWidget);
  }

  testWidgets('asks with both exercises, each with its drawing', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('어떤 종목으로 붙을까요?'), findsOneWidget);
    expect(find.text('온라인 1v1 · 30초'), findsOneWidget);
    expect(find.text('푸쉬업'), findsOneWidget);
    expect(find.text('스쿼트'), findsOneWidget);
    final drawings = tester
        .widgetList<ExercisePictogram>(find.byType(ExercisePictogram))
        .map((picture) => picture.exercise);
    expect(drawings, [ExerciseType.pushUp, ExerciseType.squat]);
    // Side by side, the same size.
    final left = tester.getRect(find.byType(Card).first);
    final right = tester.getRect(find.byType(Card).last);
    expect(left.right, lessThan(right.left));
    expect(left.top, right.top);
    expect(left.size, right.size);
    // Each card reads from the drawing down.
    final drawing = tester.getRect(find.byType(ExercisePictogram).first);
    final name = tester.getRect(find.text('푸쉬업'));
    final best = tester.getRect(find.text('개인 최고 —').first);
    expect(drawing.bottom, lessThanOrEqualTo(name.top));
    expect(name.bottom, lessThanOrEqualTo(best.top));
  });

  for (final (name, exercise) in const [
    ('푸쉬업', ExerciseType.pushUp),
    ('스쿼트', ExerciseType.squat),
  ]) {
    testWidgets('tapping $name closes the sheet with it', (tester) async {
      await open(tester);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseSheet), findsNothing);
      expect(answered, isTrue);
      expect(answer, exercise);
    });

    testWidgets('a screen reader can choose $name', (tester) async {
      final handle = tester.ensureSemantics();
      await open(
        tester,
        profile: UserProfile(
          name: '우현',
          bests: {exercise: const PersonalBest(reps: 14, score: 150)},
        ),
      );
      final card = find.semantics.byLabel('$name, 개인 최고 150점');
      expect(card, findsOne);
      tester.semantics.tap(card);
      await tester.pumpAndSettle();
      expect(answer, exercise);
      handle.dispose();
    });
  }

  testWidgets('closing the sheet answers nothing', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(answered, isTrue);
    expect(answer, isNull);
  });

  group('the personal best', () {
    testWidgets('each exercise shows its own', (tester) async {
      await open(
        tester,
        profile: const UserProfile(
          name: '우현',
          bests: {
            ExerciseType.pushUp: PersonalBest(reps: 14, score: 150),
            ExerciseType.squat: PersonalBest(reps: 9),
          },
        ),
      );
      Finder inCardOf(String name, String text) => find.descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(Card)),
        matching: find.text(text),
      );
      expect(inCardOf('푸쉬업', '개인 최고 150점'), findsOneWidget);
      expect(inCardOf('스쿼트', '개인 최고 9회'), findsOneWidget);
    });

    testWidgets('its number is in the number font', (tester) async {
      await open(
        tester,
        profile: const UserProfile(
          name: '우현',
          bests: {ExerciseType.pushUp: PersonalBest(reps: 14, score: 150)},
        ),
      );
      final best =
          tester.widget<Text>(find.text('개인 최고 150점')).textSpan! as TextSpan;
      final number = best.children![1] as TextSpan;
      expect(number.text, '150');
      expect(number.style!.fontFamily, AppFonts.number);
      expect(number.style!.fontWeight, FontWeight.w700);
      expect(number.style!.color, AppColors.textPrimary);
    });

    testWidgets('keeps its reps when the best points are zero', (tester) async {
      await open(
        tester,
        profile: const UserProfile(
          name: '우현',
          bests: {ExerciseType.pushUp: PersonalBest(reps: 32, score: 0)},
        ),
      );
      expect(find.text('개인 최고 32회'), findsOneWidget);
    });

    testWidgets('an old server\'s reps stand for push-ups', (tester) async {
      await open(tester, profile: const UserProfile(name: '우현', bestReps: 32));
      expect(find.text('개인 최고 32회'), findsOneWidget);
      expect(find.text('개인 최고 —'), findsOneWidget);
    });

    for (final (name, profile) in const [
      ('a new user', UserProfile(name: '우현')),
      ('a new user on the new server', UserProfile(name: '우현', bests: {})),
      (
        'a battle with no points and no reps',
        UserProfile(
          name: '우현',
          bestReps: 0,
          bests: {
            ExerciseType.pushUp: PersonalBest(reps: 0, score: 0),
            ExerciseType.squat: PersonalBest(reps: 0),
          },
        ),
      ),
      (
        'no reps from a server with no bests',
        UserProfile(name: '우현', bestReps: 0),
      ),
    ]) {
      testWidgets('reads a dash for $name, not 0점 or 0회', (tester) async {
        await open(tester, profile: profile);
        expect(find.text('개인 최고 —'), findsNWidgets(2));
        expect(find.textContaining('0점'), findsNothing);
        expect(find.textContaining('0회'), findsNothing);
      });
    }
  });

  group('the drawings', () {
    Future<void> show(WidgetTester tester, ExerciseType exercise) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Center(
                child: ExercisePictogram(
                  exercise,
                  // 1.75 times the 72×40 design, for round numbers.
                  size: const Size(126, 70),
                ),
              ),
            ),
          ),
        );

    testWidgets('the push-up scales its points but not its line widths', (
      tester,
    ) async {
      await show(tester, ExerciseType.pushUp);
      expect(
        tester.renderObject(find.byType(CustomPaint).last),
        paints
          ..line(
            p1: const Offset(7, 63),
            p2: const Offset(122.5, 63),
            strokeWidth: 1.5,
          )
          ..circle(x: 17.5, y: 26.25, radius: 7.875, strokeWidth: 3)
          ..line(
            p1: const Offset(28, 31.5),
            p2: const Offset(112, 52.5),
            strokeWidth: 3,
          )
          ..line(
            p1: const Offset(31.5, 31.5),
            p2: const Offset(31.5, 59.5),
            strokeWidth: 3,
          )
          ..line(
            p1: const Offset(112, 52.5),
            p2: const Offset(115.5, 59.5),
            strokeWidth: 3,
          ),
      );
    });

    testWidgets('the squat stands on the same floor, in the same lines', (
      tester,
    ) async {
      await show(tester, ExerciseType.squat);
      expect(
        tester.renderObject(find.byType(CustomPaint).last),
        paints
          ..line(
            p1: const Offset(7, 63),
            p2: const Offset(122.5, 63),
            strokeWidth: 1.5,
          )
          ..circle(x: 63, y: 8.75, radius: 7.875, strokeWidth: 3)
          ..line(
            p1: const Offset(82.25, 40.25),
            p2: const Offset(70.875, 19.25),
            strokeWidth: 3,
          )
          ..line(
            p1: const Offset(70, 21),
            p2: const Offset(42, 22.75),
            strokeWidth: 3,
          )
          // The leg, hip to knee to ankle to toe: a path fills between its
          // points, so these lie inside it and outside it.
          ..path(
            strokeWidth: 3,
            includes: const [Offset(66, 44), Offset(59, 58)],
            excludes: const [
              Offset(20, 50),
              Offset(100, 20),
              Offset(70, 58),
              // Inside it only with the ankle and the toe swapped.
              Offset(54, 50),
            ],
          ),
      );
    });

    testWidgets('takes its color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ExercisePictogram(
              ExerciseType.pushUp,
              color: AppColors.opponent,
            ),
          ),
        ),
      );
      expect(
        tester.renderObject(find.byType(CustomPaint).last),
        paints
          ..line()
          ..circle(color: AppColors.opponent),
      );
    });
  });

  // Last in the file: the fonts stay loaded for the rest of the run.
  group('with the real fonts', () {
    double linesOf(WidgetTester tester, Finder text) {
      final style = tester.renderObject<RenderParagraph>(text).text.style!;
      final lineHeight = style.fontSize! * (style.height ?? 1.5);
      return tester.getSize(text).height / lineHeight;
    }

    /// The width a text was given, after any FittedBox above it scaled it.
    double shownWidth(WidgetTester tester, Finder text) {
      final box = tester.renderObject<RenderBox>(text);
      return box.localToGlobal(Offset(box.size.width, 0)).dx -
          box.localToGlobal(Offset.zero).dx;
    }

    for (final size in const [Size(360, 780), Size(360, 640)]) {
      for (final (best, label) in const [
        (PersonalBest(reps: 14, score: 150), '개인 최고 150점'),
        (PersonalBest(reps: 14, score: 999), '개인 최고 999점'),
        (PersonalBest(reps: 75, score: 2000), '개인 최고 2000점'),
        (PersonalBest(reps: 32), '개인 최고 32회'),
      ]) {
        testWidgets('$label fits at full size at '
            '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          await _loadAppFonts(tester);
          await open(
            tester,
            size: size,
            profile: UserProfile(
              name: '우현',
              bests: {ExerciseType.pushUp: best, ExerciseType.squat: best},
            ),
          );
          final texts = find.descendant(
            of: find.byType(ExerciseSheet),
            matching: find.byType(Text),
          );
          expect(texts, findsNWidgets(6));
          for (final element in texts.evaluate()) {
            final text = find.byWidget(element.widget).first;
            // The best's line is as tall as its bigger number: 28 over 16.
            expect(linesOf(tester, text), lessThan(2));
            expect(
              tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
              isFalse,
            );
            // A FittedBox that had to shrink it would show it narrower.
            expect(
              shownWidth(tester, text),
              moreOrLessEquals(tester.getSize(text).width, epsilon: 0.01),
            );
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    // The number and the words around it differ in size, which the row's
    // measured height gets wrong at some of these unless the line's height is
    // forced to the number's.
    for (final width in const [320.0, 360.0]) {
      for (final scale in const [1.0, 1.5, 1.75, 2.0]) {
        for (final (name, bests) in const [
          ('no best', <ExerciseType, PersonalBest>{}),
          (
            'a best in points',
            {
              ExerciseType.pushUp: PersonalBest(reps: 14, score: 150),
              ExerciseType.squat: PersonalBest(reps: 14, score: 150),
            },
          ),
          (
            'the largest best',
            {
              ExerciseType.pushUp: PersonalBest(reps: 75, score: 100000),
              ExerciseType.squat: PersonalBest(reps: 75, score: 100000),
            },
          ),
        ]) {
          testWidgets('does not overflow at ${width.toInt()} wide, text scale '
              '$scale, with $name', (tester) async {
            await _loadAppFonts(tester);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await open(
              tester,
              size: Size(width, 780),
              profile: UserProfile(name: '우현', bests: bests),
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
