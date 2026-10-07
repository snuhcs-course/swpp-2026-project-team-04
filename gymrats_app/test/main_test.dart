import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/match_setup_screen.dart';
import 'package:gymrats_app/screens/matching_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/services/matching/bot_matchmaker.dart';
import 'package:gymrats_app/services/matching/matchmaker.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:provider/provider.dart';

void main() {
  /// Taps start and lets the matching page slide in. The radar keeps
  /// turning, so pumpAndSettle would only return after the bot is found.
  Future<void> startMatching(WidgetTester tester) async {
    await tester.tap(find.text('AI와 1v1 대결'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('start leads through matching to versus; cancelling goes home', (
    tester,
  ) async {
    await tester.pumpWidget(const GymRatsApp());
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);

    await startMatching(tester);
    expect(find.text('AI 상대를 찾는 중'), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsNothing);

    // The bot answers 3 seconds after the search started.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('MATCH FOUND'), findsOneWidget);
    expect(find.text('우현'), findsOneWidget);
    expect(find.text('RepBot'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);

    // System back only asks; 게임 나가기 in the dialog goes home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('게임에서 나갈까요?'), findsOneWidget);
    expect(find.text('RepBot과의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ExitDialog),
        matching: find.text('게임 나가기'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
  });

  testWidgets('every screen gets the same repository and matchmaker', (
    tester,
  ) async {
    await tester.pumpWidget(const GymRatsApp());
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(HomeScreen));
    final repository = home.read<UserRepository>();
    final matchmaker = home.read<Matchmaker>();
    expect(repository, isA<InMemoryUserRepository>());
    expect(matchmaker, isA<BotMatchmaker>());

    await startMatching(tester);
    final matching = tester.element(find.byType(MatchingScreen));
    expect(matching.read<UserRepository>(), same(repository));
    expect(matching.read<Matchmaker>(), same(matchmaker));

    await tester.pumpAndSettle();
    final versus = tester.element(find.byType(VersusScreen));
    expect(versus.read<UserRepository>(), same(repository));
    expect(versus.read<Matchmaker>(), same(matchmaker));
  });

  testWidgets('the matching flow sets up in MatchSetupScreen; the setup '
      'route still opens SetupScreen', (tester) async {
    await tester.pumpWidget(const GymRatsApp());
    await tester.pumpAndSettle();
    final generate = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .onGenerateRoute!;
    final context = tester.element(find.byType(HomeScreen));
    // Builds the screens without showing them: shown, they would ask the
    // real camera plugin for permission.
    Widget screenFor(String name, Object arguments) {
      final route = generate(RouteSettings(name: name, arguments: arguments));
      expect(route, isA<MaterialPageRoute<ExerciseType>>());
      return (route! as MaterialPageRoute<ExerciseType>).builder(context);
    }

    const matchup = Matchup(
      exercise: ExerciseType.pushUp,
      playerName: '우현',
      opponent: BotMatchmaker.bot,
    );
    expect(
      screenFor(GymRatsApp.matchSetupRoute, matchup),
      isA<MatchSetupScreen>().having(
        (screen) => screen.matchup,
        'matchup',
        same(matchup),
      ),
    );
    expect(
      screenFor(GymRatsApp.setupRoute, ExerciseType.pushUp),
      isA<SetupScreen>(),
    );
  });

  testWidgets('the battle route is a placeholder until P10', (tester) async {
    await tester.pumpWidget(const GymRatsApp());
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(
          GymRatsApp.battleRoute,
          arguments: const Matchup(
            exercise: ExerciseType.pushUp,
            playerName: '우현',
            opponent: BotMatchmaker.bot,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('배틀 화면은 P10에서 구현 예정'), findsOneWidget);
  });
}
