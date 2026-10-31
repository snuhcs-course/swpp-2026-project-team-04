import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/exit_game_button.dart';
import 'package:gymrats_app/widgets/grid_background.dart';
import 'package:gymrats_app/widgets/safe_warning_dialog.dart';

import '../support/fakes.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

void main() {
  late PushLog pushes;

  /// The safety warning's 확인 button, with or without a countdown.
  final warningButton = find.descendant(
    of: find.byType(SafeWarningDialog),
    matching: find.byType(FilledButton),
  );

  /// Opens VersusScreen from a home page and, unless [seeWarning] is false,
  /// closes the safety warning it opens with. The match setup route is a
  /// stub that shows the matchup it received, with a "ready" button that
  /// returns the exercise and a "back" button that returns null, like
  /// MatchSetupScreen. The battle route shows its matchup.
  Future<void> open(
    WidgetTester tester, {
    Matchup matchup = _matchup,
    Size size = const Size(412, 915),
    bool seeWarning = true,
    Duration? warningAutoClose,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pushes = PushLog();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        navigatorObservers: [pushes],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => VersusScreen(
                    matchup: matchup,
                    warningAutoClose: warningAutoClose,
                  ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.matchSetupRoute => MaterialPageRoute<ExerciseType>(
            settings: settings,
            builder: (context) {
              final matchup = settings.arguments! as Matchup;
              return Scaffold(
                body: Column(
                  children: [
                    Text(
                      'setup ${matchup.exercise.name} '
                      'vs ${matchup.opponent.name}',
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, matchup.exercise),
                      child: const Text('ready'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('back'),
                    ),
                  ],
                ),
              );
            },
          ),
          GymRatsApp.battleRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) {
              final matchup = settings.arguments! as Matchup;
              return Scaffold(
                appBar: AppBar(),
                body: Text('battle vs ${matchup.opponent.name}'),
              );
            },
          ),
          _ => null,
        },
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    if (seeWarning) {
      await tester.tap(warningButton);
      await tester.pumpAndSettle();
    }
  }

  int setupPushes() =>
      pushes.names.where((name) => name == GymRatsApp.matchSetupRoute).length;

  /// The 게임 나가기 button at the top left.
  final exitButton = find.byType(ExitGameButton);

  /// The dialog's 게임 나가기, not the button on the screen.
  final dialogExit = find.descendant(
    of: find.byType(ExitDialog),
    matching: find.text('게임 나가기'),
  );

  testWidgets('shows me versus RepBot, the rules and the setup button', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(GridBackground), findsOneWidget);
    expect(exitButton, findsOneWidget);
    expect(find.text('게임 나가기'), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsOneWidget);
    expect(find.text('푸쉬업 · 30초'), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
    expect(find.text('우현'), findsOneWidget);
    expect(find.text('우'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('상대'), findsOneWidget);
    expect(find.text('RepBot'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    expect(find.text('경기 규칙'), findsOneWidget);
    expect(
      find.text('가슴을 충분히 내렸다가 팔을 끝까지 펴야 1회로 인정돼요.'),
      findsOneWidget,
    );
    expect(find.text('1회 인정될 때마다 효과음이 울려요.'), findsOneWidget);
    expect(find.text('자세 세팅 시작'), findsOneWidget);
    // No tier, record, or auto-cancel countdown.
    expect(find.textContaining('승률'), findsNothing);
    expect(find.textContaining('15'), findsNothing);
  });

  testWidgets('게임 나가기 on the left; MATCH FOUND over the exercise, '
      'right aligned', (tester) async {
    await open(tester);
    final exit = tester.getRect(exitButton);
    final found = tester.getRect(find.text('MATCH FOUND'));
    final exercise = tester.getRect(find.text('푸쉬업 · 30초'));
    expect(exit.left, 20);
    expect(found.left, greaterThan(exit.right));
    // Two lines, both ending at the right padding.
    expect(found.bottom, lessThanOrEqualTo(exercise.top));
    expect(found.right, 412 - 20);
    expect(exercise.right, 412 - 20);
    // Side by side with the button.
    expect(found.top, greaterThanOrEqualTo(exit.top));
    expect(exercise.bottom, lessThanOrEqualTo(exit.bottom));
  });

  testWidgets('fonts and colors: lime for me, pink for the opponent', (
    tester,
  ) async {
    await open(tester);
    final found = tester.widget<Text>(find.text('MATCH FOUND')).style!;
    expect(found.fontFamily, AppFonts.number);
    expect(found.color, AppColors.accent);
    expect(
      tester.widget<Text>(find.text('우현')).style!.fontFamily,
      AppFonts.headline,
    );
    expect(
      tester.widget<Text>(find.text('RepBot')).style!.fontFamily,
      AppFonts.number,
    );
    expect(
      tester.widget<Text>(find.text('나')).style!.color,
      AppColors.accent,
    );
    expect(
      tester.widget<Text>(find.text('상대')).style!.color,
      AppColors.opponent,
    );
    expect(
      tester.widget<Text>(find.text('AI')).style!.color,
      AppColors.opponent,
    );
    // Me above the VS, the opponent below it.
    final vs = tester.getRect(find.text('VS'));
    expect(tester.getRect(find.text('우현')).bottom, lessThan(vs.top));
    expect(tester.getRect(find.text('RepBot')).top, greaterThan(vs.bottom));
  });

  testWidgets('a human opponent gets an initial and no AI tag', (tester) async {
    await open(
      tester,
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'Mina', isBot: false),
      ),
    );
    expect(find.text('Mina'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('AI'), findsNothing);
    expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);
  });

  final asks = <(String, Future<void> Function(WidgetTester))>[
    ('system back', (tester) => tester.binding.handlePopRoute()),
    ('the 게임 나가기 button', (tester) => tester.tap(exitButton)),
  ];
  for (final (name, ask) in asks) {
    testWidgets('$name keeps the screen and asks; 계속하기 stays', (
      tester,
    ) async {
      await open(tester);
      await ask(tester);
      await tester.pumpAndSettle();
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);
      expect(find.text('MATCH FOUND'), findsOneWidget);

      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.text('MATCH FOUND'), findsOneWidget);
    });

    testWidgets('$name, then 게임 나가기 in the dialog, goes home', (
      tester,
    ) async {
      await open(tester);
      await ask(tester);
      await tester.pumpAndSettle();
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(VersusScreen), findsNothing);
    });
  }

  testWidgets('the dialog names the opponent from the matchup', (
    tester,
  ) async {
    await open(
      tester,
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'IronBot', isBot: true),
      ),
    );
    await tester.tap(exitButton);
    await tester.pumpAndSettle();
    expect(
      find.text('IronBot과의 대결이 취소되고\n홈으로 돌아가요.'),
      findsOneWidget,
    );
  });

  testWidgets('back from setup stays here, and setup can open again', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('자세 세팅 시작'));
    await tester.pumpAndSettle();
    expect(find.text('setup pushUp vs RepBot'), findsOneWidget);

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH FOUND'), findsOneWidget);

    await tester.tap(find.text('자세 세팅 시작'));
    await tester.pumpAndSettle();
    expect(find.text('setup pushUp vs RepBot'), findsOneWidget);
    expect(setupPushes(), 2);
  });

  testWidgets('a finished setup replaces this screen with the battle', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('자세 세팅 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ready'));
    await tester.pumpAndSettle();
    expect(find.text('battle vs RepBot'), findsOneWidget);
    expect(find.byType(VersusScreen), findsNothing);

    // Replaced, not pushed: going back skips the versus screen.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('pressing again while setup opens does nothing', (tester) async {
    await open(tester);
    // Called directly: after a push the navigator already ignores taps for
    // a frame, so a second real tap would not reach the button.
    final press = tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('자세 세팅 시작'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!;
    press();
    press();
    await tester.pumpAndSettle();
    expect(setupPushes(), 1);
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    await open(tester, size: const Size(360, 640), seeWarning: false);
    expect(find.byType(SafeWarningDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(warningButton);
    await tester.pumpAndSettle();

    expect(find.text('자세 세팅 시작'), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(exitButton);
    await tester.pumpAndSettle();
    expect(find.byType(ExitDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('safety warning', () {
    /// Calls the setup button directly: the warning's barrier would stop a
    /// real tap.
    void pressSetup(WidgetTester tester) => tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('자세 세팅 시작'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!();

    testWidgets('opens over MATCH FOUND with the picture, the message and '
        '확인', (tester) async {
      await open(tester, seeWarning: false);
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      expect(find.text('무리하지 마세요'), findsOneWidget);
      expect(
        find.text('무리해서 운동하면 몸을 다칠 수 있어요.\n몸 상태를 살피며 플레이해 주세요.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(SafeWarningDialog.pictureLabel),
        findsOneWidget,
      );
      expect(find.text('확인'), findsOneWidget);
      expect(find.text('확인을 누르면 자세 세팅을 시작할 수 있어요'), findsOneWidget);
      // The screen is underneath, not replaced.
      expect(find.text('MATCH FOUND'), findsOneWidget);
    });

    testWidgets('the pose setup starts only after 확인', (tester) async {
      await open(tester, seeWarning: false);
      pressSetup(tester);
      await tester.pumpAndSettle();
      expect(setupPushes(), 0);
      expect(find.byType(SafeWarningDialog), findsOneWidget);

      await tester.tap(warningButton);
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);
      await tester.tap(find.text('자세 세팅 시작'));
      await tester.pumpAndSettle();
      expect(find.text('setup pushUp vs RepBot'), findsOneWidget);
    });

    testWidgets('a tap outside keeps it open', (tester) async {
      await open(tester, seeWarning: false);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      expect(find.byType(ExitDialog), findsNothing);
    });

    testWidgets('back on it asks whether to leave; 계속하기 shows it again', (
      tester,
    ) async {
      await open(tester, seeWarning: false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);

      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      pressSetup(tester);
      await tester.pumpAndSettle();
      expect(setupPushes(), 0);
    });

    testWidgets('back on it, then 게임 나가기, goes home with no warning left', (
      tester,
    ) async {
      await open(tester, seeWarning: false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(VersusScreen), findsNothing);
      expect(find.byType(SafeWarningDialog), findsNothing);
    });

    testWidgets('closed by a logout, which closes every screen, it asks '
        'nothing', (tester) async {
      await open(tester, seeWarning: false);
      // What GymRatsApp does when the login ends.
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(VersusScreen), findsNothing);
      expect(find.byType(SafeWarningDialog), findsNothing);
      expect(find.byType(ExitDialog), findsNothing);
    });

    testWidgets('every match shows it again', (tester) async {
      await open(tester);
      await tester.tap(exitButton);
      await tester.pumpAndSettle();
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsOneWidget);
    });

    testWidgets('online: counts down from 5 on the button and closes by '
        'itself', (tester) async {
      await open(
        tester,
        seeWarning: false,
        warningAutoClose: const Duration(seconds: 5),
      );
      expect(find.text('확인 (5)'), findsOneWidget);
      expect(find.text('5초 뒤 자동으로 닫혀요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('확인 (4)'), findsOneWidget);
      expect(find.text('4초 뒤 자동으로 닫혀요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);
      await tester.tap(find.text('자세 세팅 시작'));
      await tester.pumpAndSettle();
      expect(find.text('setup pushUp vs RepBot'), findsOneWidget);
    });

    testWidgets('online: 확인 closes it before the countdown ends', (
      tester,
    ) async {
      await open(
        tester,
        seeWarning: false,
        warningAutoClose: const Duration(seconds: 5),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(warningButton);
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);

      // The countdown is gone: running out later pops nothing.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('MATCH FOUND'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
