import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';

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
      expect(profile.lastMatch, same(lower));
      expect(profile.bestReps, 32);

      final higher = _record(40, 30);
      await repository.saveMatch(higher);
      profile = await repository.fetchProfile();
      expect(profile.lastMatch, same(higher));
      expect(profile.bestReps, 40);
    },
  );

  test('each repository keeps its own battles', () async {
    await InMemoryUserRepository().saveMatch(_record(40, 30));
    expect((await InMemoryUserRepository().fetchProfile()).bestReps, 32);
  });
}
