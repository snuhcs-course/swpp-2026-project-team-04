import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/matching_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/matching_viewmodel.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/grid_background.dart';
import 'package:gymrats_app/widgets/player_avatar.dart';

import '../support/fakes.dart';
import '../widgets/battle_test_support.dart';

const _squatGuide =
    '휴대폰을 세로로 세워 내 앞 2~3m에\n'
    '두세요. 의자나 선반 위면 더 좋아요.\n'
    '머리부터 발목까지\n'
    '화면에 들어와야 해요.';

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
  late FakeMatchmaker matchmaker;
  late FakeUserRepository repository;

  setUp(() {
    matchmaker = FakeMatchmaker();
    repository = FakeUserRepository();
  });

  /// Opens MatchingScreen from a home page. The versus route is a stub that
  /// shows the matchup it received.
  ///
  /// Unless [holdSearch] is false, the search runs until the test completes
  /// `matchmaker.gate`.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    bool holdSearch = true,
    ExerciseType exercise = ExerciseType.pushUp,
  }) async {
    // Created here, inside the test's fake async zone; a completer made in
    // setUp would complete outside of it and never reach the screen.
    if (holdSearch) matchmaker.gate = Completer();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Follows the fake time that pump(duration) moves forward.
    final start = tester.binding.clock.now();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MatchingScreen(
                    exercise: exercise,
                    createViewModel: () => MatchingViewModel(
                      matchmaker: matchmaker,
                      repository: repository,
                      exercise: exercise,
                      clock: () => tester.binding.clock.now().difference(start),
                    ),
                  ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.versusRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) {
              final matchup = settings.arguments! as Matchup;
              return Scaffold(
                appBar: AppBar(),
                body: Text(
                  'versus ${matchup.playerName} vs ${matchup.opponent.name}',
                ),
              );
            },
          ),
          _ => null,
        },
      ),
    );
    await tester.tap(find.text('home'));
    await transition(tester);
  }

  /// System back. One frame later the dialog it opens takes taps.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
  }

  /// The dialog's 매칭 취소, not the button on the screen.
  final dialogCancel = find.descendant(
    of: find.byType(ExitDialog),
    matching: find.text('매칭 취소'),
  );

  testWidgets('the title says how hard the bot it looks for is', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MatchingScreen(
          exercise: ExerciseType.pushUp,
          difficulty: BotDifficulty.beginner,
          createViewModel: () => MatchingViewModel(
            matchmaker: matchmaker..gate = Completer(),
            repository: repository,
            exercise: ExerciseType.pushUp,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('초보 AI 상대를 찾는 중'), findsOneWidget);
  });

  testWidgets('shows the chip, title, guide card and the user\'s initial', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(GridBackground), findsOneWidget);
    // No close button at the top; 매칭 취소 at the bottom is the way out.
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('푸쉬업 · 30초 · 1v1'), findsOneWidget);
    expect(find.text('고수 AI 상대를 찾는 중'), findsOneWidget);
    expect(find.text('기다리는 동안 자리를 준비해 두세요'), findsOneWidget);
    expect(find.text('휴대폰을 머리 앞 약 1m 바닥에 세워\n화면이 나를 보게 두세요.'), findsOneWidget);
    expect(find.textContaining('2~3m'), findsNothing);
    expect(find.text('우'), findsOneWidget);
    expect(find.text('매칭 취소'), findsOneWidget);
    expect(find.textContaining('티어'), findsNothing);
    // The radar keeps turning while searching.
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('the avatar sits in the middle of the radar, its halo 0.36 of '
      'the radar wide (BMatching: r 51.8 of 288)', (tester) async {
    await open(tester);
    final avatar = find.byType(PlayerAvatar);
    final radar = tester.getRect(
      find.ancestor(of: avatar, matching: find.byType(AspectRatio)).first,
    );
    final rect = tester.getRect(avatar);
    expect(
      rect.width,
      moreOrLessEquals(radar.width * 51.8 * 2 / 288, epsilon: 0.5),
    );
    expect(rect.center.dx, moreOrLessEquals(radar.center.dx, epsilon: 0.01));
    expect(rect.center.dy, moreOrLessEquals(radar.center.dy, epsilon: 0.01));
  });

  testWidgets('the guide card tells where the phone goes for a squat', (
    tester,
  ) async {
    await open(tester, exercise: ExerciseType.squat);
    expect(find.text('스쿼트 · 30초 · 1v1'), findsOneWidget);
    expect(find.text(_squatGuide), findsOneWidget);
    expect(find.textContaining('머리 앞'), findsNothing);
  });

  testWidgets('the radar is the design\'s (BMatching): a white disc with an '
      'ink edge, a lime sweep of six wedges with an ink edge turning once '
      'per cycle, gray rings and dashes, ink-edged pink blips', (tester) async {
    final turn = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 3),
    );
    addTearDown(turn.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 500,
            child: BattleSearchRadar(
              animation: turn,
              elapsed: Duration.zero,
              playerName: '우현',
            ),
          ),
        ),
      ),
    );
    final painter = tester
        .widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(BattleSearchRadar),
                matching: find.byType(CustomPaint),
              )
              .first,
        )
        .painter!;
    // In the design's own 288 points.
    final ops = paintedOps(painter, const Size(288, 288));
    expect(ops.take(4), [
      'save()',
      'scale(1.000, 1.000)',
      'drawCircle((144.000, 144.000), 142.000, fill #FFFFFFFF)',
      'drawCircle((144.000, 144.000), 142.000, stroke #FF141A26 2.000 butt '
          'miter)',
    ]);
    final arcs = ops.where((op) => op.startsWith('drawArc')).toList();
    expect(arcs, [
      for (final (start, alpha) in [
        ('0.524', '1F'),
        ('0.698', '3D'),
        ('0.873', '5C'),
        ('1.047', '80'),
        ('1.222', 'A8'),
        ('1.396', 'D9'),
      ])
        'drawArc(rect(-143.000, -143.000, 143.000, 143.000), $start, 0.175, '
            'true, fill #${alpha}C6FF3D)',
    ]);
    expect(
      ops,
      contains(
        'drawLine((0.000, 0.000), (0.000, 142.000), fill '
        '#FF141A26)',
      ),
    );
    expect(ops, contains('rotate(0.000)'));
    for (final radius in ['103.000', '62.900']) {
      expect(
        ops,
        contains(
          'drawCircle((144.000, 144.000), $radius, stroke #FF586073 '
          '1.250 butt miter)',
        ),
      );
    }
    // Dashes of 4 every 8 from 2, across and down.
    expect(
      ops,
      containsAll([
        'drawLine((2.000, 144.000), (6.000, 144.000), fill #FF586073)',
        'drawLine((144.000, 282.000), (144.000, 286.000), fill #FF586073)',
      ]),
    );
    expect(
      ops,
      containsAll([
        'drawCircle((220.800, 67.200), 6.000, fill #FFFF4F81)',
        'drawCircle((55.500, 199.300), 4.600, fill #8CFF4F81)',
        'drawCircle((241.600, 217.600), 3.800, fill #FFFF4F81)',
        'drawCircle((220.800, 67.200), 6.000, stroke #FF141A26 1.500 butt '
            'miter)',
      ]),
    );
    // No pulse: nothing lime but the sweep.
    expect(
      ops.where((op) => op.contains('C6FF3D') && !op.startsWith('drawArc')),
      isEmpty,
    );
    // A quarter of the cycle later the sweep has turned a quarter.
    turn.value = 0.25;
    expect(
      paintedOps(painter, const Size(288, 288)),
      contains('rotate(1.571)'),
    );
    turn.value = 0;

    // The order of the design: disc, sweep, rings, dashes, blips.
    int first(String start) => ops.indexWhere((op) => op.startsWith(start));
    final ringAt = ops.indexWhere((op) => op.contains('103.000, stroke'));
    final dashAt = ops.indexOf(
      'drawLine((2.000, 144.000), (6.000, 144.000), fill #FF586073)',
    );
    final blipAt = first('drawCircle((220.800, 67.200)');
    expect(first('drawArc'), greaterThan(3));
    expect(
      ringAt,
      greaterThan(ops.lastIndexWhere((op) => op.startsWith('drawArc'))),
    );
    expect(dashAt, greaterThan(ringAt));
    expect(blipAt, greaterThan(dashAt));

    // The widths and caps of the lines: the sweep's edge 2 and round, the
    // dashes 1.
    final canvas = TestRecordingCanvas();
    painter.paint(canvas, const Size(288, 288));
    final lines = [
      for (final call in canvas.invocations)
        if (call.invocation.memberName == #drawLine)
          call.invocation.positionalArguments[2] as Paint,
    ];
    expect(
      (lines.first.strokeWidth, lines.first.strokeCap),
      (2.0, StrokeCap.round),
    );
    expect(lines.skip(1).map((paint) => paint.strokeWidth).toSet(), {1.0});

    // Any other size is the same picture, scaled.
    expect(
      paintedOps(painter, const Size(340, 340)),
      contains('scale(1.181, 1.181)'),
    );
  });

  testWidgets('the radar is one picture to a screen reader, and its sweep '
      'holds still when the system reduces motion', (tester) async {
    final handle = tester.ensureSemantics();
    final turn = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 3),
    )..value = 0.25;
    addTearDown(turn.dispose);
    Future<List<String>> paintWith({required bool still}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: still),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                height: 500,
                child: BattleSearchRadar(
                  animation: turn,
                  elapsed: Duration.zero,
                  playerName: '우현',
                ),
              ),
            ),
          ),
        ),
      );
      final painter = tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(BattleSearchRadar),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .painter!;
      return paintedOps(painter, const Size(288, 288));
    }

    expect(await paintWith(still: false), contains('rotate(1.571)'));
    expect(await paintWith(still: true), contains('rotate(0.000)'));
    expect(find.bySemanticsLabel('상대를 찾는 레이더'), findsOneWidget);
    // The letter in the middle is part of the picture.
    expect(find.bySemanticsLabel('우'), findsNothing);
    handle.dispose();
  });

  testWidgets('the screen turns the radar once every 3 s', (tester) async {
    await open(tester);
    double turned() {
      final painter = tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(BattleSearchRadar),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .painter!;
      final rotate = paintedOps(
        painter,
        const Size(288, 288),
      ).firstWhere((op) => op.startsWith('rotate('));
      return double.parse(rotate.substring(7, rotate.length - 1));
    }

    final before = turned();
    await tester.pump(const Duration(milliseconds: 750));
    final after = turned();
    // A quarter turn, wherever in the turn it was.
    expect((after - before) % (2 * 3.14159265), closeTo(1.571, 0.01));
  });

  testWidgets('palette B: the chip dot, the guide icon and 매칭 취소 are '
      'ink-edged or ink, the colors only fill', (tester) async {
    await open(tester);
    final dotBox = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration as BoxDecoration).color == AppColors.accent,
    );
    expect(tester.getSize(dotBox), const Size.square(10));
    final dot = tester.widget<DecoratedBox>(dotBox).decoration as BoxDecoration;
    expect(
      (dot.border! as Border).top,
      const BorderSide(color: AppColors.ink, width: 1.5),
    );
    final phone = find.byIcon(Icons.smartphone_rounded);
    expect(tester.widget<Icon>(phone).color, AppColors.ink);
    final box =
        tester
                .widget<DecoratedBox>(
                  find.ancestor(of: phone, matching: find.byType(DecoratedBox)),
                )
                .decoration
            as BoxDecoration;
    expect(box.color, AppColors.accent.withValues(alpha: 0.55));
    final cancel = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('매칭 취소'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      cancel.style!.side!.resolve({}),
      const BorderSide(color: AppColors.line, width: 1.5),
    );
  });

  testWidgets('counts the time since the search started', (tester) async {
    await open(tester);
    // open() spent 1 second on the page transition.
    expect(find.text('0:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('0:08'), findsOneWidget);

    final style = tester.widget<Text>(find.text('0:08')).style!;
    expect(style.fontFamily, AppFonts.number);
    // Ink: palette B keeps lime for fills.
    expect(style.color, AppColors.ink);
  });

  testWidgets('shows a person icon until the name is loaded', (tester) async {
    repository.gate = Completer();
    await open(tester);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.text('우'), findsNothing);

    repository.gate!.complete();
    await tester.pump();
    expect(find.byIcon(Icons.person_rounded), findsNothing);
    expect(find.text('우'), findsOneWidget);
  });

  testWidgets('a found opponent replaces this screen with the versus screen', (
    tester,
  ) async {
    await open(tester);
    matchmaker.gate!.complete();
    await transition(tester);
    expect(find.text('versus 우현 vs AI 봇 · 고수'), findsOneWidget);
    expect(find.byType(MatchingScreen), findsNothing);

    // Replaced, not pushed: going back skips the matching screen.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  final ways = <(String, Future<void> Function(WidgetTester))>[
    ('매칭 취소', (tester) => tester.tap(find.text('매칭 취소'))),
    (
      '매칭 취소 in the back dialog',
      (tester) async {
        await back(tester);
        await tester.tap(dialogCancel);
      },
    ),
  ];
  for (final (name, leave) in ways) {
    testWidgets('$name goes home, and a result arriving meanwhile is ignored', (
      tester,
    ) async {
      await open(tester);
      await leave(tester);
      // The screen is sliding away when the opponent is found.
      await tester.pump();
      matchmaker.gate!.complete();
      await transition(tester);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(MatchingScreen), findsNothing);
      expect(find.textContaining('versus'), findsNothing);
    });
  }

  testWidgets('system back keeps the screen and asks; 계속하기 searches on', (
    tester,
  ) async {
    await open(tester);
    await back(tester);
    expect(find.text('매칭을 취소할까요?'), findsOneWidget);
    expect(find.text('상대 찾기를 멈추고\n홈으로 돌아가요.'), findsOneWidget);
    expect(find.byType(MatchingScreen), findsOneWidget);

    await tester.tap(find.text('계속하기'));
    await transition(tester);
    expect(find.byType(ExitDialog), findsNothing);
    expect(find.text('고수 AI 상대를 찾는 중'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    matchmaker.gate!.complete();
    await transition(tester);
    expect(find.text('versus 우현 vs AI 봇 · 고수'), findsOneWidget);
  });

  testWidgets('an opponent found while asking waits; 계속하기 then moves on', (
    tester,
  ) async {
    await open(tester);
    await back(tester);
    matchmaker.gate!.complete();
    await transition(tester);
    // Moving on now would replace the dialog instead of this screen.
    expect(find.text('매칭을 취소할까요?'), findsOneWidget);
    expect(find.textContaining('versus'), findsNothing);

    await tester.tap(find.text('계속하기'));
    await transition(tester);
    expect(find.text('versus 우현 vs AI 봇 · 고수'), findsOneWidget);
    expect(find.byType(MatchingScreen), findsNothing);

    // Replaced, not pushed: going back skips the matching screen.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('an opponent found while asking, then 매칭 취소, goes home', (
    tester,
  ) async {
    await open(tester);
    await back(tester);
    matchmaker.gate!.complete();
    await transition(tester);
    await tester.tap(dialogCancel);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(MatchingScreen), findsNothing);
    expect(find.textContaining('versus'), findsNothing);
  });

  testWidgets('a failed search stops the radar and offers a retry', (
    tester,
  ) async {
    matchmaker.error = Exception('offline');
    await open(tester, holdSearch: false);
    expect(find.text('상대를 찾지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('0:00'), findsNothing);
    expect(find.text('매칭 취소'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    matchmaker.error = null;
    await tester.tap(find.text('다시 시도'));
    await transition(tester);
    expect(find.text('versus 우현 vs AI 봇 · 고수'), findsOneWidget);
    expect(matchmaker.requests, hasLength(2));
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    await open(tester, size: const Size(360, 640));
    expect(find.text('매칭 취소'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Last in the file: the fonts stay loaded for the rest of the run.
  for (final (exercise, text, lines) in [
    (ExerciseType.squat, _squatGuide, 4),
    (ExerciseType.pushUp, '휴대폰을 머리 앞 약 1m 바닥에 세워\n화면이 나를 보게 두세요.', 2),
  ]) {
    for (final size in const [Size(360, 640), Size(360, 780), Size(412, 915)]) {
      testWidgets('the ${exercise.name} guide keeps its $lines lines at '
          '${size.width.toInt()}x${size.height.toInt()} with the real fonts', (
        tester,
      ) async {
        await _loadAppFonts(tester);
        await open(tester, size: size, exercise: exercise);
        final guide = find.text(text);
        final style = tester.widget<Text>(guide).style!;
        expect(
          tester.getSize(guide).height / (style.fontSize! * style.height!),
          moreOrLessEquals(lines.toDouble(), epsilon: 0.1),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

/// Pumps a page transition to its end. The radar never stops turning, so
/// pumpAndSettle would time out while the matching screen is shown.
Future<void> transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
