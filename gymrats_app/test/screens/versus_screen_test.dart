import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/grid_background.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

/// Names of the routes pushed, in order.
class _PushLog extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}

void main() {
  late _PushLog pushes;

  /// Opens VersusScreen from a home page. The setup route is a stub with
  /// a "ready" button that returns the exercise and a "back" button that
  /// returns null, like SetupScreen. The battle route shows its matchup.
  Future<void> open(
    WidgetTester tester, {
    Matchup matchup = _matchup,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pushes = _PushLog();
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
                  builder: (_) => VersusScreen(matchup: matchup),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.setupRoute => MaterialPageRoute<ExerciseType>(
            settings: settings,
            builder: (context) {
              final exercise = settings.arguments! as ExerciseType;
              return Scaffold(
                body: Column(
                  children: [
                    Text('setup ${exercise.name}'),
                    TextButton(
                      onPressed: () => Navigator.pop(context, exercise),
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
  }

  int setupPushes() =>
      pushes.names.where((name) => name == GymRatsApp.setupRoute).length;

  testWidgets('shows me versus RepBot, the rules and the setup button', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(GridBackground), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsOneWidget);
    expect(find.text('푸쉬업 · 60초'), findsOneWidget);
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

  testWidgets('back from setup stays here, and setup can open again', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('자세 세팅 시작'));
    await tester.pumpAndSettle();
    expect(find.text('setup pushUp'), findsOneWidget);

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH FOUND'), findsOneWidget);

    await tester.tap(find.text('자세 세팅 시작'));
    await tester.pumpAndSettle();
    expect(find.text('setup pushUp'), findsOneWidget);
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
    await open(tester, size: const Size(360, 640));
    expect(find.text('자세 세팅 시작'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
