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

  test('a saved battle keeps its game scores', () async {
    final repository = InMemoryUserRepository(matches: []);
    await repository.saveMatch(
      const MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 7,
        opponentReps: 9,
        myScore: 150,
        opponentScore: 90,
      ),
    );
    final [saved] = await repository.fetchRecent();
    expect(saved.myScore, 150);
    expect(saved.opponentScore, 90);
  });

  test('each exercise has its own best, in points when it has them', () async {
    MatchRecord battle(ExerciseType exercise, int reps, [int? score]) =>
        MatchRecord(
          exercise: exercise,
          opponentName: 'RepBot',
          myReps: reps,
          opponentReps: 1,
          myScore: score,
          opponentScore: score == null ? null : 0,
        );
    final repository = InMemoryUserRepository(
      matches: [
        battle(ExerciseType.pushUp, 14, 150),
        battle(ExerciseType.pushUp, 20),
        battle(ExerciseType.pushUp, 9, 90),
        battle(ExerciseType.squat, 12),
      ],
    );
    final profile = await repository.fetchProfile();
    expect(profile.bestOf(ExerciseType.pushUp)!.score, 150);
    expect(profile.bestOf(ExerciseType.pushUp)!.reps, 20);
    expect(profile.bestOf(ExerciseType.squat)!.score, isNull);
    expect(profile.bestOf(ExerciseType.squat)!.reps, 12);
    expect(profile.bestReps, 20);
  });

  test('a new user has no best', () async {
    final profile = await InMemoryUserRepository(matches: []).fetchProfile();
    expect(profile.bestOf(ExerciseType.pushUp), isNull);
    expect(profile.bestOf(ExerciseType.squat), isNull);
  });

  test('an exercise not played has no best', () async {
    final repository = InMemoryUserRepository(
      matches: const [
        MatchRecord(
          exercise: ExerciseType.squat,
          opponentName: 'RepBot',
          myReps: 12,
          opponentReps: 1,
        ),
      ],
    );
    final profile = await repository.fetchProfile();
    expect(profile.bestOf(ExerciseType.pushUp), isNull);
  });

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
