import '../../models/exercise_type.dart';
import '../../models/match_record.dart';
import '../../models/user_profile.dart';
import 'user_repository.dart';

/// Sample data kept in memory until the app has a server and login.
///
/// Saved battles last until the app closes.
class InMemoryUserRepository implements UserRepository {
  UserProfile _profile = const UserProfile(
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

  @override
  Future<void> saveMatch(MatchRecord record) async {
    final best = _profile.bestReps;
    _profile = UserProfile(
      name: _profile.name,
      bestReps: best == null || record.myReps > best ? record.myReps : best,
      lastMatch: record,
    );
  }
}
