// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/screens/feedback_screen.dart';
import 'package:gymrats_app/screens/match_feedback_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/form_report_fixtures.dart';

final _endedAt = DateTime.utc(2026, 10, 21, 3);

MatchRecord _match({FeedbackSummary? summary, int? id = 7}) => MatchRecord(
  id: id,
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: 3,
  opponentReps: 1,
  playedAt: _endedAt.toLocal(),
  feedbackSummary: summary,
);

const _summary = FeedbackSummary(validReps: 3, invalidReps: 0, issueCount: 0);

void main() {
  late FakeUserRepository repository;
  late InMemoryFormReportStore phone;

  setUp(() {
    repository = FakeUserRepository();
    phone = InMemoryFormReportStore();
  });

  Future<void> open(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserRepository>.value(value: repository),
          Provider<FormReportStore>.value(value: phone),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: home),
      ),
    );
  }

  testWidgets('loads, then shows the same feedback screen', (tester) async {
    final report = sampleReport(endedAt: _endedAt);
    repository
      ..reports = {7: report}
      ..feedbackGate = Completer();
    await open(tester, MatchFeedbackScreen(match: _match(summary: _summary)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('자세 피드백'), findsOneWidget);
    repository.feedbackGate!.complete();
    await tester.pump();
    await tester.pump();
    final screen = tester.widget<FeedbackScreen>(find.byType(FeedbackScreen));
    expect(screen.report, same(report));
  });

  testWidgets('a failure shows why and retries', (tester) async {
    repository.feedbackError = const ApiException(ApiErrorKind.network);
    await open(tester, MatchFeedbackScreen(match: _match(summary: _summary)));
    await tester.pumpAndSettle();
    expect(find.text('피드백을 불러오지 못했어요'), findsOneWidget);
    expect(
      find.text(const ApiException(ApiErrorKind.network).message),
      findsOneWidget,
    );
    repository
      ..feedbackError = null
      ..reports = {7: sampleReport()};
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(repository.feedbackRequests, [7, 7]);
  });

  testWidgets("offline, the phone's copy opens", (tester) async {
    final copy = sampleReport(endedAt: _endedAt);
    await phone.save(copy);
    repository.feedbackError = const ApiException(ApiErrorKind.network);
    await open(tester, MatchFeedbackScreen(match: _match(summary: _summary)));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<FeedbackScreen>(find.byType(FeedbackScreen)).report,
      same(copy),
    );
  });

  testWidgets('a battle with no stored report says so', (tester) async {
    await open(tester, MatchFeedbackScreen(match: _match(summary: _summary)));
    await tester.pumpAndSettle();
    expect(find.text('피드백 없음'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('the back button returns', (tester) async {
    repository.feedbackError = Exception('boom');
    await open(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: feedbackTap(context, _match(summary: _summary)),
          child: const Text('row'),
        ),
      ),
    );
    await tester.tap(find.text('row'));
    await tester.pumpAndSettle();
    expect(find.byType(MatchFeedbackScreen), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('row'), findsOneWidget);
  });

  testWidgets('a row without feedback, or without an id, is not tappable', (
    tester,
  ) async {
    late BuildContext context;
    await open(
      tester,
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    expect(feedbackTap(context, _match()), isNull);
    expect(feedbackTap(context, _match(summary: _summary, id: null)), isNull);
    expect(feedbackTap(context, _match(summary: _summary)), isNotNull);
  });
}
