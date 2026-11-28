/// The rank ladder of an online battle's report (A15, the design
/// `SpScene.dc.html` `v="E"`): which weekly ranking rows the cut-in shows,
/// where each starts and ends, and the ranks it writes. Pure functions of
/// plain values: the rankings come as [RankingSnapshot]s, so this file needs
/// nothing from the services.
///
/// Every rank it gives is the server's (the PM's condition, 2026-11-29):
/// nothing is worked out from the ranking before the battle plus its points.
/// Only the choice of rows goes by points, as the design picks them.
library;

/// One row of a weekly ranking as the ladder reads it: the server's rank
/// (equal points share it, 1, 1, 3), the week's points and battles.
typedef LadderEntry = ({
  int userId,
  String nickname,
  int points,
  int rank,
  int battles,
});

/// One exercise's global weekly ranking at one time: [entries] best first
/// (the server's top rows), and my row [me], also when the list stops above
/// it. [me] is null before my first battle of the week.
class RankingSnapshot {
  const RankingSnapshot({required this.entries, this.me});

  final List<LadderEntry> entries;
  final LadderEntry? me;

  /// Whether [entry] is my row.
  bool isMine(LadderEntry entry) => entry.userId == me?.userId;
}

/// Which report the cut-in plays, chosen at [RankingLadder.decideMs].
enum LadderPath {
  /// The ranking after the battle has it: the ladder from that ranking.
  confirmed,

  /// A ranked battle whose ranking is not confirmed yet: today's scene;
  /// the rank chip shows only once the ranking is confirmed.
  late,

  /// No points layer: not a ranked battle, no ranking from before it, or no
  /// points.
  none,
}

/// The rank chip left on the report's seat: my rank and week's points after
/// the battle, and the battle's [gained] points.
typedef RankChipValues = ({int rank, int points, int gained});

/// One row of the ladder: [nickname] with [points], drawn [order]th (mine
/// last), moving from slot [fromSlot] to [toSlot] (slot 0 is the top row)
/// while its rank turns from [rankBefore] to [rankAfter]. A null
/// [rankBefore] is no rank yet ('–').
class LadderRow {
  const LadderRow({
    required this.nickname,
    required this.points,
    required this.isMe,
    required this.order,
    required this.fromSlot,
    required this.toSlot,
    required this.rankBefore,
    required this.rankAfter,
  });

  final String nickname;
  final int points;
  final bool isMe;
  final int order;
  final double fromSlot;
  final double toSlot;
  final int? rankBefore;
  final int rankAfter;

  /// Whether the rank turns, and so pops when it does.
  bool get rankChanged => rankBefore != rankAfter;

  /// Its rank before and after as written.
  String get rankBeforeText => RankingLadder.rankText(rankBefore);
  String get rankAfterText => RankingLadder.rankText(rankAfter);
}

/// The ladder of a confirmed ranking (design `pick`, `win`, `startSlot`,
/// `finalSlot`): up to three other players and my row, or, when I am still
/// outside the list after the battle, its last row, the dots and mine.
class RankingLadder {
  const RankingLadder._({
    required this.others,
    required this.me,
    required this.outside,
    required this.pointsBefore,
    required this.gained,
  });

  /// The cut-in is the same whatever the ranking until this time (ms after
  /// the report opens): the path is chosen then.
  static const decideMs = 880.0;

  /// At most this many other players are shown.
  static const shownOthers = 3;

  /// The path of a battle (SPEC 2.4): [ranked] is false for a battle that
  /// does not count (a friend battle, a bot, the arcade, a past report).
  static LadderPath pathOf({
    required bool ranked,
    required RankingSnapshot? before,
    required RankingSnapshot? after,
    required int points,
  }) {
    if (!ranked || before == null || points <= 0) return LadderPath.none;
    return after != null && confirms(before, after)
        ? LadderPath.confirmed
        : LadderPath.late;
  }

  /// Whether [after] has the battle [before] did not: one battle more.
  static bool confirms(RankingSnapshot before, RankingSnapshot after) =>
      after.me?.battles == (before.me?.battles ?? 0) + 1;

  /// The rank chip's values from a confirmed [after].
  static RankChipValues chipOf(RankingSnapshot after, int gained) =>
      (rank: after.me!.rank, points: after.me!.points, gained: gained);

  /// The ladder of a battle worth [points] from [before] to a confirmed
  /// [after] (the caller checked [confirms]). Rows are picked by points;
  /// each rank is the server's: an other's after rank from [after], its
  /// before rank the same player's in [before] (not there: the after rank,
  /// so it does not turn); mine from both [RankingSnapshot.me]s.
  factory RankingLadder.of({
    required RankingSnapshot before,
    required RankingSnapshot after,
    required int points,
  }) {
    final mine = after.me!;
    final old = before.me?.points;
    final now = mine.points;
    final others = [
      for (final entry in after.entries)
        if (!after.isMine(entry)) entry,
    ];
    final beforeRanks = {
      for (final entry in before.entries) entry.userId: entry.rank,
    };
    int? rankBefore(LadderEntry entry) =>
        beforeRanks[entry.userId] ?? entry.rank;
    final listed = after.entries.any(after.isMine);
    final outside = !listed && others.isNotEmpty && now < others.last.points;
    if (outside) {
      // Still outside the list: its lowest row (the first of equals, as
      // the design reduces), the dots, and mine. That row shows only its
      // rank after the battle, before and after, as the design draws it
      // (one rank, no pop).
      final last = others.reduce((a, b) => b.points < a.points ? b : a);
      return RankingLadder._(
        others: [
          LadderRow(
            nickname: last.nickname,
            points: last.points,
            isMe: false,
            order: 0,
            fromSlot: 0,
            toSlot: 0,
            rankBefore: last.rank,
            rankAfter: last.rank,
          ),
        ],
        me: LadderRow(
          nickname: mine.nickname,
          points: now,
          isMe: true,
          order: 1,
          fromSlot: 1.5,
          toSlot: 1.5,
          rankBefore: before.me?.rank,
          rankAfter: mine.rank,
        ),
        outside: true,
        pointsBefore: old ?? 0,
        gained: points,
      );
    }
    // Before my first battle of the week every row is at or above my old
    // points.
    bool atOrAboveOld(LadderEntry o) => old == null || o.points >= old;
    final above = _byPoints(others.where((o) => o.points > now));
    final passed = _byPoints(
      others.where((o) => o.points <= now && atOrAboveOld(o)),
    );
    final below = _byPoints(others.where((o) => !atOrAboveOld(o)));
    // The target just above, those passed (highest first), further up,
    // then those below (nearest first).
    final pick = <LadderEntry>[];
    if (above.isNotEmpty) pick.add(above.last);
    for (var i = 0; i < passed.length && pick.length < shownOthers; i++) {
      pick.add(passed[i]);
    }
    for (var i = above.length - 2; i >= 0 && pick.length < shownOthers; i--) {
      pick.add(above[i]);
    }
    for (var i = 0; i < below.length && pick.length < shownOthers; i++) {
      pick.add(below[i]);
    }
    final shown = _byPoints(pick);
    final startSlot = shown.where(atOrAboveOld).length;
    final finalSlot = shown.where((o) => o.points > now).length;
    return RankingLadder._(
      others: [
        for (final (i, entry) in shown.indexed)
          LadderRow(
            nickname: entry.nickname,
            points: entry.points,
            isMe: false,
            order: i,
            fromSlot: (i < startSlot ? i : i + 1).toDouble(),
            toSlot: (i < finalSlot ? i : i + 1).toDouble(),
            rankBefore: rankBefore(entry),
            rankAfter: entry.rank,
          ),
      ],
      me: LadderRow(
        nickname: mine.nickname,
        points: now,
        isMe: true,
        order: shown.length,
        fromSlot: startSlot.toDouble(),
        toSlot: finalSlot.toDouble(),
        rankBefore: before.me?.rank,
        rankAfter: mine.rank,
      ),
      outside: false,
      pointsBefore: old ?? 0,
      gained: points,
    );
  }

  /// The other players' rows, top first.
  final List<LadderRow> others;

  /// My row, drawn over the others.
  final LadderRow me;

  /// Whether I am outside the list after the battle: [others] is its last
  /// row and the dots stand between it and mine.
  final bool outside;

  /// My week's points before the battle (0 before my first) and the
  /// battle's points; my row rolls from [pointsBefore] to [me]'s points.
  final int pointsBefore;
  final int gained;

  /// Every row, in drawing order.
  List<LadderRow> get rows => [...others, me];

  /// The longest rank text of every row before and after (commas count):
  /// the rank cell keeps one size through the scene.
  int get rankChars => rows
      .expand((row) => [row.rankBeforeText, row.rankAfterText])
      .fold(
        1,
        (longest, text) => text.length > longest ? text.length : longest,
      );

  /// The rank cell's width and its digits' size for [rankChars] (SPEC 5):
  /// 40 and 19 for one character, 40 and 17 for two, 46 and 15 for three,
  /// 58 and 15 for more.
  double get rankCellWidth => switch (rankChars) {
    <= 2 => 40,
    3 => 46,
    _ => 58,
  };
  double get rankCellText => switch (rankChars) {
    <= 1 => 19,
    2 => 17,
    _ => 15,
  };

  /// [rows] by points, highest first; equal points keep their order in
  /// [rows], as the design's stable sort does.
  static List<LadderEntry> _byPoints(Iterable<LadderEntry> rows) {
    final indexed = rows.indexed.toList()
      ..sort((a, b) {
        final byPoints = b.$2.points.compareTo(a.$2.points);
        return byPoints != 0 ? byPoints : a.$1.compareTo(b.$1);
      });
    return [for (final (_, entry) in indexed) entry];
  }

  /// A rank as written: commas from 1,000 on, '–' for none.
  static String rankText(int? rank) {
    if (rank == null) return '–';
    final digits = '$rank';
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}
