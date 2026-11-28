/// Where I stand in a weekly ranking, and the words the rankings screen
/// shows for the week (A13 spec 3.6): the week's name, the time left, how
/// far the week has gone, and my card's goal line. Pure functions of plain
/// values: the clock is passed in, and the ranking's rows come as
/// [StandingRow]s, so this file needs nothing from the services.
library;

/// One row of a ranking as the standing reads it: the server's rank (equal
/// points share it), the week's points and battles, and whether it is mine.
typedef StandingRow = ({int rank, int points, int battles, bool isMe});

/// What my card's goal line says.
enum StandingKind {
  /// No row of mine, or no battle this week: '대결하면 순위에 올라요'.
  unranked,

  /// The friends tab with only me in it: no goal line.
  noFriends,

  /// Nobody has more points than me: 'n위보다 m점 앞섬', the bar full
  /// (no goal line when nobody has fewer either).
  first,

  /// Someone has more points: 'r위까지 n점' toward the lowest of them.
  behind,

  /// The global list stops above me: 'r위까지 n점' toward its last row.
  outsideList,
}

/// My standing in one ranking: my rank and points as my card shows them,
/// and the goal line under my name.
class RankingStanding {
  const RankingStanding({
    required this.kind,
    required this.friends,
    this.rank,
    this.points = 0,
    this.goalRank,
    this.gap,
    this.fill,
  });

  /// My standing in a ranking of [entries] (best first). [me] is the
  /// server's row of mine, which the global ranking gives even below its
  /// list (null before my first battle of the week); the friends ranking
  /// ([friends]) finds mine among [entries].
  factory RankingStanding.of({
    required StandingRow? me,
    required List<StandingRow> entries,
    required bool friends,
  }) {
    final mine = friends ? entries.where((row) => row.isMe).firstOrNull : me;
    if (mine == null || mine.battles == 0) {
      return RankingStanding(kind: StandingKind.unranked, friends: friends);
    }
    RankingStanding goal(
      StandingKind kind, {
      int? goalRank,
      int? gap,
      double? fill,
    }) => RankingStanding(
      kind: kind,
      friends: friends,
      rank: mine.rank,
      points: mine.points,
      goalRank: goalRank,
      gap: gap,
      fill: fill,
    );
    // Rows without a battle show '–' instead of a rank: never a goal.
    final others = [
      for (final row in entries)
        if (!row.isMe && row.battles > 0) row,
    ];
    if (friends && entries.length <= 1) return goal(StandingKind.noFriends);
    final listed = entries.any((row) => row.isMe);
    if (!friends && !listed && entries.isNotEmpty) {
      final last = entries.last;
      // At the last row's points the list's cut (by name) left me out: go
      // by the points above me instead.
      if (last.points > mine.points) {
        return goal(
          StandingKind.outsideList,
          goalRank: last.rank,
          gap: last.points - mine.points,
          fill: mine.points / last.points,
        );
      }
    }
    final above = others.where((row) => row.points > mine.points);
    if (above.isNotEmpty) {
      final next = above.reduce((a, b) => b.points < a.points ? b : a);
      return goal(
        StandingKind.behind,
        goalRank: next.rank,
        gap: next.points - mine.points,
        fill: mine.points / next.points,
      );
    }
    final below = others.where((row) => row.points < mine.points);
    if (below.isEmpty) return goal(StandingKind.first);
    final closest = below.reduce((a, b) => b.points > a.points ? b : a);
    return goal(
      StandingKind.first,
      goalRank: closest.rank,
      gap: mine.points - closest.points,
      fill: 1,
    );
  }

  final StandingKind kind;

  /// Whether this is the friends ranking (the unranked line differs).
  final bool friends;

  /// My rank; null when [unranked] (the card shows '–').
  final int? rank;

  /// My points; 0 when [unranked].
  final int points;

  /// The rank the goal line names; null without a goal.
  final int? goalRank;

  /// The points between me and [goalRank]'s row; null without a goal.
  final int? gap;

  /// How full the goal bar is, 0 to 1; null when the line has no bar.
  final double? fill;

  bool get unranked => kind == StandingKind.unranked;

  /// The goal line in three parts, the number drawn in the number font:
  /// ('3위까지 ', 3, '점'), ('2위보다 ', 4, '점 앞섬'). Null when the line is
  /// a sentence alone ([plainLine]) or there is none.
  ({String lead, int number, String tail})? get goalParts {
    final (rank, gap) = (goalRank, this.gap);
    if (rank == null || gap == null) return null;
    return kind == StandingKind.first
        ? (lead: '$rank위보다 ', number: gap, tail: '점 앞섬')
        : (lead: '$rank위까지 ', number: gap, tail: '점');
  }

  /// The goal line when it is a sentence without a bar: the unranked one.
  String? get plainLine =>
      unranked ? (friends ? '대결하면 점수가 쌓여요' : '대결하면 순위에 올라요') : null;

  /// The whole goal line as one string (for a screen reader); null when the
  /// card has none.
  String? get goalLine {
    if (goalParts case (:final lead, :final number, :final tail)) {
      return '$lead$number$tail';
    }
    return plainLine;
  }

  @override
  bool operator ==(Object other) =>
      other is RankingStanding &&
      other.kind == kind &&
      other.friends == friends &&
      other.rank == rank &&
      other.points == points &&
      other.goalRank == goalRank &&
      other.gap == gap &&
      other.fill == fill;

  @override
  int get hashCode =>
      Object.hash(kind, friends, rank, points, goalRank, gap, fill);

  @override
  String toString() =>
      'RankingStanding($kind, rank $rank, $points, goal $goalRank by $gap, '
      'fill $fill)';
}

/// The week's words and progress, in Korea's time (the server's weeks start
/// on Monday 00:00 KST).
abstract final class RankingWeek {
  static const _korea = Duration(hours: 9);

  /// "11월 4주차" for the week starting [weekStart]: the Monday's month and
  /// which seventh of it the Monday falls in (11.23 → 4, 11.30 → 5).
  static String name(DateTime weekStart) {
    final monday = weekStart.toUtc().add(_korea);
    return '${monday.month}월 ${(monday.day - 1) ~/ 7 + 1}주차';
  }

  /// The time left until [weekEnd] at [now]: 'n일 m시간 남음' from a day,
  /// 'm시간 n분 남음' from an hour, 'n분 남음' below (at least 1), and
  /// '곧 새로 시작해요' once it is over. Whole units, rounded down.
  static String timeLeft(DateTime weekEnd, DateTime now) {
    final left = weekEnd.difference(now);
    if (left <= Duration.zero) return '곧 새로 시작해요';
    final days = left.inDays;
    final hours = left.inHours % Duration.hoursPerDay;
    final minutes = left.inMinutes % Duration.minutesPerHour;
    if (days > 0) return '$days일 $hours시간 남음';
    if (left.inHours > 0) return '$hours시간 $minutes분 남음';
    return '${minutes < 1 ? 1 : minutes}분 남음';
  }

  /// How much of the week from [weekStart] to [weekEnd] has gone by at
  /// [now], 0 to 1.
  static double progress(DateTime weekStart, DateTime weekEnd, DateTime now) {
    final length = weekEnd.difference(weekStart).inMicroseconds;
    if (length <= 0) return 1;
    final gone = now.difference(weekStart).inMicroseconds / length;
    return gone.clamp(0.0, 1.0);
  }

  /// A row's record, "4전 2승 · KO 1", or '이번 주 기록 없음' before its
  /// first battle.
  static String record({
    required int battles,
    required int wins,
    required int koWins,
  }) => battles == 0 ? '이번 주 기록 없음' : '$battles전 $wins승 · KO $koWins';
}

/// The words over the list (A13 spec 3.5): its name on the left, a note on
/// the right.
abstract final class RankingList {
  /// The note when nothing more needs saying.
  static const sharedRanks = '같은 점수는 같은 등수';

  /// 'TOP 50' for everyone; '나와 친구 n명' among [count] rows, mine one of
  /// them, on the friends tab ([friends]).
  static String title({required bool friends, required int count}) =>
      friends ? '나와 친구 ${count - 1}명' : 'TOP 50';

  /// The note right of the title: '50위 안에 들면 목록에 나와요' when the
  /// global list stops above my row [me]; nothing when I have no global row
  /// yet (`RankG3`); '이번 주 아직 아무도 대결하지 않았어요' when no friend
  /// nor I has had a battle; [sharedRanks] otherwise.
  static String note({
    required bool friends,
    required StandingRow? me,
    required List<StandingRow> entries,
  }) {
    if (friends) {
      return entries.every((row) => row.battles == 0)
          ? '이번 주 아직 아무도 대결하지 않았어요'
          : sharedRanks;
    }
    if (me == null) return '';
    return entries.any((row) => row.isMe) ? sharedRanks : '50위 안에 들면 목록에 나와요';
  }
}
