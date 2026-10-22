import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/match_record_card.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

MatchRecord _record(int mine, int theirs, {int day = 15}) => MatchRecord(
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: mine,
  opponentReps: theirs,
  playedAt: DateTime(2026, 10, day, 21, 5),
);

void main() {
  late FakeUserRepository repository;

  setUp(() => repository = FakeUserRepository());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<UserRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: Text('home')),
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
          initialRoute: '/history',
        ),
      ),
    );
  }

  testWidgets('shows battles newest first with result, scores, and date', (
    tester,
  ) async {
    repository.historyPages = [
      [
        _record(30, 20, day: 15),
        _record(10, 25, day: 14),
        _record(12, 12, day: 13),
      ],
    ];
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('경기 기록'), findsOneWidget);
    final cards = tester.widgetList<MatchRecordCard>(
      find.byType(MatchRecordCard),
    );
    expect(cards.map((c) => c.match.myReps), [30, 10, 12]);
    expect(find.text('승'), findsOneWidget);
    expect(find.text('패'), findsOneWidget);
    expect(find.text('무'), findsOneWidget);
    expect(find.text('10월 15일 21:05'), findsOneWidget);
    expect(find.text('10월 14일 21:05'), findsOneWidget);
    expect(find.text('푸쉬업 · vs RepBot'), findsNWidgets(3));
  });

  testWidgets('a new user sees the empty state', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('아직 경기 기록이 없어요'), findsOneWidget);
    expect(find.byType(MatchRecordCard), findsNothing);
  });

  testWidgets('a spinner shows while loading', (tester) async {
    repository.historyGate = Completer();
    await open(tester);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.historyGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failure shows the reason and 다시 시도 works', (tester) async {
    repository.historyError = const ApiException(ApiErrorKind.network);
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);
    expect(
      find.text(const ApiException(ApiErrorKind.network).message),
      findsOneWidget,
    );

    repository
      ..historyError = null
      ..historyPages = [
        [_record(30, 20)],
      ];
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(MatchRecordCard), findsOneWidget);
  });

  testWidgets('older battles load as the end of the list comes near', (
    tester,
  ) async {
    repository.historyPages = [
      for (var page = 0; page < 3; page++)
        [for (var i = 0; i < 20; i++) _record(60 - page * 20 - i, 5)],
    ];
    await open(tester);
    await tester.pumpAndSettle();
    // The first page fills the screen, so nothing more is asked yet.
    expect(repository.historyCursors, [null]);

    await tester.dragUntilVisible(
      find.byWidgetPredicate(
        (w) => w is MatchRecordCard && w.match.myReps == 1,
      ),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(repository.historyCursors, [null, '1', '2']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a short first page asks for the next one right away', (
    tester,
  ) async {
    repository.historyPages = [
      [_record(2, 1)],
      [_record(1, 1)],
    ];
    await open(tester);
    await tester.pumpAndSettle();
    expect(repository.historyCursors, [null, '1']);
    expect(find.byType(MatchRecordCard), findsNWidgets(2));
  });

  testWidgets('a failed next page offers a retry under the list', (
    tester,
  ) async {
    repository
      ..historyPages = [
        [_record(2, 1)],
        [_record(1, 1)],
      ]
      ..nextPageError = Exception('offline');
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MatchRecordCard), findsOneWidget);
    expect(find.text('더 불러오지 못했어요'), findsOneWidget);

    repository.nextPageError = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(MatchRecordCard), findsNWidgets(2));
    expect(find.text('더 불러오지 못했어요'), findsNothing);
  });

  testWidgets('back returns to the previous screen', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
