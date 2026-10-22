// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/home_shell_screen.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

MatchRecord _battle(int id, {bool feedback = true}) => MatchRecord(
  id: id,
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: 10 + id,
  opponentReps: 5,
  playedAt: DateTime(2026, 10, 21, 9, id),
  feedbackSummary: feedback
      ? const FeedbackSummary(validReps: 1, invalidReps: 0, issueCount: 0)
      : null,
);

void main() {
  late FakeUserRepository repository;

  setUp(() {
    repository = FakeUserRepository()
      ..profile = const UserProfile(name: '우현')
      ..recent = [_battle(3), _battle(2), _battle(1, feedback: false)]
      ..historyPages = [
        [_battle(3), _battle(2), _battle(1, feedback: false)],
      ];
  });

  Future<void> open(WidgetTester tester, {HomeTab tab = HomeTab.home}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserRepository>.value(value: repository),
          Provider<FormReportStore>.value(value: InMemoryFormReportStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: HomeShellScreen(initialTab: tab),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on 홈 with the 홈 | 기록 bar', (tester) async {
    await open(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });

  testWidgets('the 기록 tab shows every battle without a back button', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byTooltip('뒤로'), findsNothing);
    expect(find.text('피드백 없음'), findsOneWidget);
    expect(find.text('좋은 자세'), findsNWidgets(2));
  });

  testWidgets('"전체 기록" on home switches to the 기록 tab', (tester) async {
    await open(tester);
    await tester.scrollUntilVisible(find.text('전체 기록 ›'), 180);
    await tester.tap(find.text('전체 기록 ›'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('coming back to a tab loads it again', (tester) async {
    await open(tester, tab: HomeTab.history);
    expect(repository.historyCursors, [null]);
    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(repository.fetchCount, 1);
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(repository.historyCursors, [null, null]);
    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(repository.fetchCount, 2);
  });

  testWidgets('back on 기록 goes to 홈 instead of leaving', (tester) async {
    await open(tester, tab: HomeTab.history);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    final scope = tester.widget<PopScope>(
      find.byWidgetPredicate((w) => w is PopScope),
    );
    expect(scope.canPop, isTrue);
  });

  testWidgets('tapping the open tab again keeps it', (tester) async {
    await open(tester);
    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(repository.fetchCount, 1);
  });

  testWidgets('the tabs can be replaced for tests', (tester) async {
    late VoidCallback openHistory;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShellScreen(
          buildHome: (open) {
            openHistory = open;
            return const Text('home tab');
          },
          buildHistory: () => const Text('history tab'),
        ),
      ),
    );
    expect(find.text('home tab'), findsOneWidget);
    openHistory();
    await tester.pump();
    expect(find.text('history tab'), findsOneWidget);
  });
}
