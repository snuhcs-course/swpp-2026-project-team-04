import '../../models/exercise_type.dart';
import '../../models/match_record.dart';
import '../../models/user_profile.dart';
import 'user_repository.dart';

/// Sample data kept in memory until the app has a server and login.
class InMemoryUserRepository implements UserRepository {
  static const _profile = UserProfile(
    name: '우현',
    bestReps: 32,
    lastMatch: MatchRecord(
      exercise: ExerciseType.pushUp,
      opponentName: 'RepBot',
      myReps: 24,
      opponentReps: 19,
    ),
  );

  @override
  Future<UserProfile> fetchProfile() async => _profile;
}
