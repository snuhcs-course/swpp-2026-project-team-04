import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';

import '../../support/form_report_fixtures.dart';

MatchRecord _record(int mine, int theirs) => MatchRecord(
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: mine,
  opponentReps: theirs,
);

void main() {
  test('starts with the sample profile', () async {
    final profile = await InMemoryUserRepository().fetchProfile();
    expect(profile.name, '우현');
    expect(profile.bestReps, 32);
    expect(profile.lastMatch!.myReps, 24);
    expect(profile.lastMatch!.opponentReps, 19);
  });

  test(
    'a saved battle becomes the latest; only more reps raise the best',
    () async {
      final repository = InMemoryUserRepository();
      final lower = _record(20, 25);
      await repository.saveMatch(lower);
      var profile = await repository.fetchProfile();
      expect(profile.name, '우현');
      // Saved as a copy that carries a new id, like the server does.
      expect(profile.lastMatch!.myReps, lower.myReps);
      expect(profile.lastMatch!.opponentReps, lower.opponentReps);
      expect(profile.lastMatch!.id, isNotNull);
      expect(profile.bestReps, 32);

      final higher = _record(40, 30);
      await repository.saveMatch(higher);
      profile = await repository.fetchProfile();
      expect(profile.lastMatch!.myReps, higher.myReps);
      expect(profile.bestReps, 40);
    },
  );

  test('each repository keeps its own battles', () async {
    await InMemoryUserRepository().saveMatch(_record(40, 30));
    expect((await InMemoryUserRepository().fetchProfile()).bestReps, 32);
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  test(
    'a battle saved with a report has a summary and loads it back',
    () async {
      final repository = InMemoryUserRepository(matches: []);
      final report = sampleReport(valid: 2, rejected: 1);
      await repository.saveMatch(_record(2, 1), report: report);
      await repository.saveMatch(_record(5, 1));
      final [plain, withReport] = await repository.fetchRecent();
      expect(plain.hasFeedback, isFalse);
      expect(await repository.fetchFeedback(plain.id!), isNull);
      expect(withReport.feedbackSummary!.validReps, 2);
      expect(await repository.fetchFeedback(withReport.id!), same(report));
    },
  );

  test('recent battles are the newest, up to the limit', () async {
    final repository = InMemoryUserRepository(matches: []);
    for (var reps = 1; reps <= 5; reps++) {
      await repository.saveMatch(_record(reps, 0));
    }
    final recent = await repository.fetchRecent();
    expect(recent.map((m) => m.myReps), [5, 4, 3]);
    expect(await repository.fetchRecent(limit: 10), hasLength(5));
  });

  test('online feedback is accepted without a battle server', () async {
    final repository = InMemoryUserRepository(matches: []);
    await repository.saveFeedback('r' * 32, sampleReport());
    expect(await repository.fetchRecent(), isEmpty);
  });
}
