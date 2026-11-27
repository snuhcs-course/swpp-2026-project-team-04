import '../api/api_client.dart';

/// Whose weekly points a ranking lists: everyone's, or only mine and my
/// friends'. Friend battles are not ranked: the friends ranking takes the
/// same weekly points as the global one.
enum RankingScope { global, friends }

/// One player's row in a weekly ranking.
class RankingEntry {
  const RankingEntry({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.points,
    required this.battles,
    required this.wins,
    required this.koWins,
    required this.isMe,
  });

  /// Equal points share a rank (1, 1, 3).
  final int rank;
  final int userId;
  final String nickname;
  final int points;
  final int battles;
  final int wins;
  final int koWins;
  final bool isMe;

  @override
  bool operator ==(Object other) =>
      other is RankingEntry &&
      other.rank == rank &&
      other.userId == userId &&
      other.nickname == nickname &&
      other.points == points &&
      other.battles == battles &&
      other.wins == wins &&
      other.koWins == koWins &&
      other.isMe == isMe;

  @override
  int get hashCode =>
      Object.hash(rank, userId, nickname, points, battles, wins, koWins, isMe);
}

/// This week's ranking: Monday 00:00 KST up to the next Monday.
class WeeklyRanking {
  const WeeklyRanking({
    required this.scope,
    required this.weekStart,
    required this.weekEnd,
    required this.entries,
    required this.me,
  });

  final RankingScope scope;
  final DateTime weekStart;
  final DateTime weekEnd;

  /// Best first. The global ranking lists the top 50 players with a battle
  /// this week; the friends ranking lists me and every friend.
  final List<RankingEntry> entries;

  /// My row, also when the global list stops above it. Null in the global
  /// ranking before my first battle of the week.
  final RankingEntry? me;
}

/// Points of one battle in the weekly ranking, as the server counts them.
abstract final class RankingPoints {
  static const koWin = 10, win = 5, draw = 3, loss = 1, leftBattle = 0;
}

/// Reads weekly rankings.
abstract interface class RankingsRepository {
  Future<WeeklyRanking> fetchWeekly(RankingScope scope);
}

/// [RankingsRepository] over the GymRats API (`/matches/rankings/weekly`).
class ServerRankingsRepository implements RankingsRepository {
  ServerRankingsRepository({required this._api});

  final ApiClient _api;

  @override
  Future<WeeklyRanking> fetchWeekly(RankingScope scope) async {
    final json = await _api.get(
      '/matches/rankings/weekly',
      query: {'scope': scope.name},
    );
    try {
      final body = json! as Map<String, Object?>;
      return WeeklyRanking(
        scope: RankingScope.values.byName(body['scope']! as String),
        weekStart: DateTime.parse(body['week_start']! as String),
        weekEnd: DateTime.parse(body['week_end']! as String),
        entries: (body['entries']! as List).map(_entry).toList(),
        me: body['me'] == null ? null : _entry(body['me']),
      );
    } on Object {
      // A reply the app cannot read is the server's fault.
      throw const ApiException(ApiErrorKind.server);
    }
  }

  static RankingEntry _entry(Object? json) {
    final e = json! as Map<String, Object?>;
    return RankingEntry(
      rank: e['rank']! as int,
      userId: e['user_id']! as int,
      nickname: e['nickname']! as String,
      points: e['points']! as int,
      battles: e['battles']! as int,
      wins: e['wins']! as int,
      koWins: e['ko_wins']! as int,
      isMe: e['is_me']! as bool,
    );
  }
}

/// [RankingsRepository] kept in memory: the app's stand-in without a server
/// (tests, demos). It returns [rankings] per scope, or an empty week.
class InMemoryRankingsRepository implements RankingsRepository {
  InMemoryRankingsRepository({Map<RankingScope, WeeklyRanking>? rankings})
    : _rankings = {...?rankings};

  final Map<RankingScope, WeeklyRanking> _rankings;

  /// How many times each scope was read.
  final Map<RankingScope, int> reads = {};

  @override
  Future<WeeklyRanking> fetchWeekly(RankingScope scope) async {
    reads[scope] = (reads[scope] ?? 0) + 1;
    return _rankings[scope] ??
        WeeklyRanking(
          scope: scope,
          weekStart: DateTime.utc(2026, 11, 22, 15),
          weekEnd: DateTime.utc(2026, 11, 29, 15),
          entries: const [],
          me: null,
        );
  }
}
