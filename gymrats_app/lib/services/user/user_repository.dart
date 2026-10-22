import '../../models/form_report.dart';
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
  /// become the best record if they beat it. [report], when given, is the
  /// battle's form feedback and is kept with it.
  ///
  /// Throws an [Exception] when the battle cannot be saved.
  Future<void> saveMatch(MatchRecord record, {FormReport? report});

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Keeps the form feedback of an online battle. The battle server stores
  /// the battle itself under [resultId]; this attaches [report] to it.
  ///
  /// Throws an [Exception] when the feedback cannot be saved now; it is
  /// then sent again with the next load.
  Future<void> saveFeedback(String resultId, FormReport report);

  /// The [limit] newest battles, for the home screen.
  ///
  /// Throws an [Exception] when they cannot be loaded.
  Future<List<MatchRecord>> fetchRecent({int limit = 3});

  /// The full form report of the battle with [matchId] ([MatchRecord.id]),
  /// to rebuild its feedback screen; null when it has none.
  ///
  /// Throws an [Exception] when it cannot be loaded.
  Future<FormReport?> fetchFeedback(int matchId);

  /// Loads up to [limit] battles, newest first. Pass the last page's
  /// [MatchPage.nextCursor] as [cursor] for the older ones.
  ///
  /// Throws an [Exception] when the page cannot be loaded.
  Future<MatchPage> fetchHistory({String? cursor, int limit = 20});
}
