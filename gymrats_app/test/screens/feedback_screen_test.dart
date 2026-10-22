import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/feedback_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/feedback/form_summary.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';

import '../support/fakes.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

final _report = FormReport(
  endedAt: DateTime(2026, 10, 11, 9, 5),
  opponentName: 'RepBot',
  roundLength: const Duration(seconds: 30),
  reps: const [
    RepRecord(
      index: 1,
      valid: true,
      at: Duration(seconds: 4),
      maxDepth: 1.6,
      minElbowAngle: 147,
    ),
    RepRecord(
      index: 2,
      valid: false,
      at: Duration(seconds: 8),
      reason: RejectReason.kneesDown,
      maxDepth: 1.3,
    ),
  ],
  samples: [
    for (var i = 0; i < 30; i++)
      FormSample(
        at: Duration(milliseconds: i * 300),
        depth: (i % 10) / 6,
        leftElbow: 140,
        rightElbow: 168,
      ),
  ],
);

/// Routes the feedback screen like the app does, under [home].
Widget app(Widget home) => MaterialApp(
  theme: AppTheme.dark,
  home: home,
  onGenerateRoute: (settings) => switch (settings.name) {
    GymRatsApp.feedbackRoute => MaterialPageRoute<void>(
      builder: (_) => FeedbackScreen(report: settings.arguments! as FormReport),
    ),
    _ => null,
  },
);

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a flared-elbow finding shows the side-view figure', (
    tester,
  ) async {
    phone(tester);
    const pose = FormPose(
      at: Duration(seconds: 3),
      points: {
        'leftShoulder': FormPoint(-0.5, 0),
        'rightShoulder': FormPoint(0.5, 0),
        'leftElbow': FormPoint(-1.5, 0.3),
        'nose': FormPoint(0, -0.4),
      },
    );
    await tester.pumpWidget(
      app(
        FeedbackScreen(
          report: FormReport(
            endedAt: DateTime(2026, 10, 11, 9, 5),
            opponentName: 'RepBot',
            roundLength: const Duration(seconds: 60),
            reps: const [],
            samples: [
              for (var i = 0; i < 12; i++)
                FormSample(
                  at: Duration(milliseconds: i * 100),
                  depth: 1.2,
                  leftSpread: 1.2,
                ),
            ],
            leftFlarePose: pose,
          ),
        ),
      ),
    );
    expect(find.text('팔꿈치 벌어짐'), findsOneWidget);
    expect(find.text('예시 동작 · 누르면 멈춤'), findsOneWidget);
    expect(find.byTooltip('예시 멈춤'), findsOneWidget);

    await tester.tap(find.byTooltip('예시 멈춤'));
    await tester.pump();
    expect(find.text('예시 동작 · 누르면 재생'), findsOneWidget);
    expect(find.byTooltip('예시 재생'), findsOneWidget);

    await tester.tap(find.byTooltip('예시 재생'));
    await tester.pump();
    expect(find.text('예시 동작 · 누르면 멈춤'), findsOneWidget);
  });

  testWidgets('feedback shows findings, both charts, and every rep', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(FeedbackScreen(report: _report)));

    expect(find.text('FORM'), findsOneWidget);
    expect(find.text('vs RepBot · 10/11 09:05'), findsOneWidget);
    expect(find.text('무릎 대고 함 1회'), findsOneWidget);
    expect(find.text('좌우 불균형'), findsOneWidget);
    expect(find.text('예시 동작 · 누르면 멈춤'), findsWidgets);

    await tester.scrollUntilVisible(find.text('머리 하강 깊이'), 300);
    expect(find.byType(LineChart), findsWidgets);

    await tester.scrollUntilVisible(find.text('오른팔'), 300);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('왼팔'), findsOneWidget);
    expect(find.byType(LineChart), findsWidgets);

    await tester.scrollUntilVisible(find.text('무효 · 무릎을 바닥에서 떼요'), 300);
    expect(find.text('무효 · 무릎을 바닥에서 떼요'), findsOneWidget);
    expect(find.text('147°'), findsOneWidget);
    expect(find.text('1.60'), findsOneWidget);
    expect(find.textContaining('초반 5초 1회'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('without samples, the charts say nothing was seen', (
    tester,
  ) async {
    phone(tester);
    final empty = FormReport(
      endedAt: _report.endedAt,
      opponentName: 'RepBot',
      roundLength: const Duration(seconds: 60),
      reps: const [],
      samples: const [],
    );
    await tester.pumpWidget(app(FeedbackScreen(report: empty)));
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('이 구간은 카메라에 잡히지 않았어요.'), findsWidgets);
  });

  testWidgets('the result screen opens the feedback and comes back', (
    tester,
  ) async {
    phone(tester);
    final result = BattleResult(
      matchup: _matchup,
      myReps: 1,
      myInvalidReps: 1,
      opponentReps: 0,
      endedAt: _report.endedAt,
      form: _report,
    );
    await tester.pumpWidget(app(ResultScreen(result: result)));
    await tester.tap(find.text('자세 피드백 보기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FeedbackScreen), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
  });

  testWidgets('a result without a form report has no feedback button', (
    tester,
  ) async {
    phone(tester);
    final result = BattleResult(
      matchup: _matchup,
      myReps: 1,
      myInvalidReps: 0,
      opponentReps: 0,
      endedAt: _report.endedAt,
    );
    await tester.pumpWidget(app(ResultScreen(result: result)));
    expect(find.text('자세 피드백 보기'), findsNothing);
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  // Home no longer lists the phone's latest report on its own: each of its
  // recent battles carries its feedback (task: match history with feedback).
  testWidgets('a recent battle on home opens the same feedback screen', (
    tester,
  ) async {
    phone(tester);
    final repository = FakeUserRepository()
      ..profile = const UserProfile(name: '우현')
      ..recent = [
        MatchRecord(
          id: 5,
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 1,
          opponentReps: 0,
          playedAt: _report.endedAt,
          feedbackSummary: summarizeForm(_report),
        ),
      ]
      ..reports = {5: _report};
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserRepository>.value(value: repository),
          Provider<FormReportStore>.value(value: InMemoryFormReportStore()),
        ],
        child: app(
          HomeScreen(
            createViewModel: () => HomeViewModel(repository: repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('푸쉬업 · vs RepBot'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(
      tester.widget<FeedbackScreen>(find.byType(FeedbackScreen)).report,
      same(_report),
    );
  });
}
