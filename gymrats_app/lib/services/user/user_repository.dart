import '../../models/match_page.dart';
import '../../models/match_record.dart';
import '../../models/user_profile.dart';

/// Where the user's data comes from and goes to.
///
/// GymRatsApp creates one instance and shares it through Provider, so every
/// screen sees the same data. The app uses ServerUserRepository; tests and
/// demos without a server use InMemoryUserRepository.
abstract interface class UserRepository {
  /// Loads the user's name, best record, and latest battle.
  ///
  /// Throws an [Exception] when the profile cannot be loaded.
  Future<UserProfile> fetchProfile();

  /// Keeps a finished battle: it becomes the latest one, and its reps
  /// become the best record if they beat it.
  ///
  /// Throws an [Exception] when the battle cannot be saved.
  Future<void> saveMatch(MatchRecord record);

  /// Loads up to [limit] battles, newest first. Pass the last page's
  /// [MatchPage.nextCursor] as [cursor] for the older ones.
  ///
  /// Throws an [Exception] when the page cannot be loaded.
  Future<MatchPage> fetchHistory({String? cursor, int limit = 20});
}
