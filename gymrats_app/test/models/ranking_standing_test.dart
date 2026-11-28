import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/ranking_standing.dart';

StandingRow row(int rank, int points, {int battles = 3, bool me = false}) =>
    (rank: rank, points: points, battles: battles, isMe: me);

void main() {
  group('RankingWeek.name', () {
    test('names the week by its Monday in Korea', () {
      // Monday 11.23 00:00 KST, as the server sends it (UTC).
      expect(RankingWeek.name(DateTime.utc(2026, 11, 22, 15)), '11월 4주차');
      expect(RankingWeek.name(DateTime.utc(2026, 11, 29, 15)), '11월 5주차');
    });

    test('reads Korean dates whatever the zone given', () {
      expect(
        RankingWeek.name(DateTime.parse('2026-11-23T00:00:00+09:00')),
        '11월 4주차',
      );
      // The first seventh of a month is days 1 to 7: Monday 12.7 is still
      // the first week, Monday 12.14 the second, Monday 11.2 the first.
      expect(RankingWeek.name(DateTime.utc(2026, 12, 6, 15)), '12월 1주차');
      expect(RankingWeek.name(DateTime.utc(2026, 12, 13, 15)), '12월 2주차');
      expect(RankingWeek.name(DateTime.utc(2026, 11, 1, 15)), '11월 1주차');
    });
  });

  group('RankingWeek.timeLeft', () {
    final end = DateTime.utc(2026, 11, 29, 15);

    test('days and hours from a day left', () {
      expect(
        RankingWeek.timeLeft(
          end,
          end.subtract(const Duration(days: 1, hours: 9, minutes: 59)),
        ),
        '1일 9시간 남음',
      );
      expect(
        RankingWeek.timeLeft(end, end.subtract(const Duration(days: 1))),
        '1일 0시간 남음',
      );
      expect(
        RankingWeek.timeLeft(
          end,
          end.subtract(const Duration(days: 6, hours: 23)),
        ),
        '6일 23시간 남음',
      );
    });

    test('hours and minutes below a day', () {
      expect(
        RankingWeek.timeLeft(
          end,
          end.subtract(const Duration(hours: 23, minutes: 59, seconds: 59)),
        ),
        '23시간 59분 남음',
      );
      expect(
        RankingWeek.timeLeft(end, end.subtract(const Duration(hours: 1))),
        '1시간 0분 남음',
      );
    });

    test('minutes below an hour, at least one', () {
      expect(
        RankingWeek.timeLeft(
          end,
          end.subtract(const Duration(minutes: 59, seconds: 59)),
        ),
        '59분 남음',
      );
      expect(
        RankingWeek.timeLeft(end, end.subtract(const Duration(seconds: 20))),
        '1분 남음',
      );
    });

    test('a new week is coming once the end has passed', () {
      expect(RankingWeek.timeLeft(end, end), '곧 새로 시작해요');
      expect(
        RankingWeek.timeLeft(end, end.add(const Duration(minutes: 3))),
        '곧 새로 시작해요',
      );
    });
  });

  group('RankingWeek.progress', () {
    final start = DateTime.utc(2026, 11, 22, 15);
    final end = DateTime.utc(2026, 11, 29, 15);

    test('is 0 at the start and 1 at the end', () {
      expect(RankingWeek.progress(start, end, start), 0);
      expect(RankingWeek.progress(start, end, end), 1);
    });

    test('is the share of the week gone by', () {
      expect(
        RankingWeek.progress(
          start,
          end,
          start.add(const Duration(days: 3, hours: 12)),
        ),
        0.5,
      );
    });

    test('stays within 0 and 1 outside the week', () {
      expect(
        RankingWeek.progress(
          start,
          end,
          start.subtract(const Duration(hours: 1)),
        ),
        0,
      );
      expect(
        RankingWeek.progress(start, end, end.add(const Duration(days: 2))),
        1,
      );
      // A week without length counts as over.
      expect(RankingWeek.progress(end, end, start), 1);
    });
  });

  test('a record reads battles, wins and KO wins, or no record', () {
    expect(RankingWeek.record(battles: 4, wins: 2, koWins: 1), '4전 2승 · KO 1');
    expect(RankingWeek.record(battles: 0, wins: 0, koWins: 0), '이번 주 기록 없음');
  });

  group('RankingStanding.of', () {
    test('someone above: the lowest points above me and their rank', () {
      // RankD1: 31, 23, 22, me 19 (4th).
      final standing = RankingStanding.of(
        me: row(4, 19, me: true),
        entries: [row(1, 31), row(2, 23), row(3, 22), row(4, 19, me: true)],
        friends: false,
      );
      expect(standing.kind, StandingKind.behind);
      expect((standing.rank, standing.points), (4, 19));
      expect((standing.goalRank, standing.gap), (3, 3));
      expect(standing.fill, closeTo(19 / 22, 1e-9));
      expect(standing.goalParts, (lead: '3위까지 ', number: 3, tail: '점'));
      expect(standing.goalLine, '3위까지 3점');
      expect(standing.plainLine, isNull);
    });

    test('someone above with a tie: the tied rank the server gave', () {
      final standing = RankingStanding.of(
        me: row(4, 12, me: true),
        entries: [
          row(1, 31),
          row(2, 16),
          row(2, 16),
          row(4, 12, me: true),
          row(4, 12),
        ],
        friends: false,
      );
      expect(
        (standing.kind, standing.goalRank, standing.gap),
        (StandingKind.behind, 2, 4),
      );
      // Tied with me is not above me.
      expect(standing.goalLine, '2위까지 4점');
    });

    test('first: ahead of the next points below, the bar full', () {
      // RankF1: me 19, then 15, and two friends without a battle.
      final standing = RankingStanding.of(
        me: null,
        entries: [
          row(1, 19, me: true),
          row(2, 15),
          row(3, 9),
          row(4, 0, battles: 0),
          row(4, 0, battles: 0),
        ],
        friends: true,
      );
      expect(standing.kind, StandingKind.first);
      expect((standing.rank, standing.goalRank, standing.gap), (1, 2, 4));
      expect(standing.fill, 1);
      expect(standing.goalLine, '2위보다 4점 앞섬');
    });

    test('first, tied at the top: the next points below by their rank', () {
      final standing = RankingStanding.of(
        me: row(1, 20, me: true),
        entries: [row(1, 20, me: true), row(1, 20), row(3, 14)],
        friends: false,
      );
      expect(
        (standing.kind, standing.goalRank, standing.gap),
        (StandingKind.first, 3, 6),
      );
    });

    test('first with nobody below: no goal line', () {
      final alone = RankingStanding.of(
        me: row(1, 5, me: true),
        entries: [row(1, 5, me: true)],
        friends: false,
      );
      expect(alone.kind, StandingKind.first);
      expect((alone.goalRank, alone.gap, alone.fill), (null, null, null));
      expect(alone.goalLine, isNull);
      // Friends without a battle never make a goal: their rank shows '–'.
      final idleFriends = RankingStanding.of(
        me: null,
        entries: [row(1, 5, me: true), row(2, 0, battles: 0)],
        friends: true,
      );
      expect(idleFriends.goalLine, isNull);
    });

    test('outside the global list: toward its last row', () {
      // RankG2: me 63rd with 4, the 50th has 6.
      final top = [for (var i = 1; i <= 50; i++) row(i, 56 - i)];
      final standing = RankingStanding.of(
        me: row(63, 4, battles: 2, me: true),
        entries: top,
        friends: false,
      );
      expect(standing.kind, StandingKind.outsideList);
      expect((standing.rank, standing.goalRank, standing.gap), (63, 50, 2));
      expect(standing.fill, closeTo(4 / 6, 1e-9));
      expect(standing.goalLine, '50위까지 2점');
    });

    test('left out at the last row\'s points: the points above instead', () {
      // The server cuts ties at 50 by name: my rank is the 50th's.
      final top = [
        for (var i = 1; i <= 48; i++) row(i, 60 - i),
        row(49, 8),
        row(49, 8),
      ];
      final standing = RankingStanding.of(
        me: row(49, 8, me: true),
        entries: top,
        friends: false,
      );
      expect(standing.kind, StandingKind.behind);
      expect((standing.goalRank, standing.gap), (48, 4));
    });

    test('no record: no row of mine or no battle this week', () {
      // RankG3: the server gives no row of mine in the global ranking.
      final global = RankingStanding.of(
        me: null,
        entries: [row(1, 31), row(2, 23)],
        friends: false,
      );
      expect(global.kind, StandingKind.unranked);
      expect(global.unranked, isTrue);
      expect((global.rank, global.points, global.fill), (null, 0, null));
      expect(global.goalParts, isNull);
      expect(global.plainLine, '대결하면 순위에 올라요');
      expect(global.goalLine, '대결하면 순위에 올라요');
      // RankF3: my row is there with no battle.
      final friends = RankingStanding.of(
        me: null,
        entries: [row(1, 0, battles: 0), row(1, 0, battles: 0, me: true)],
        friends: true,
      );
      expect(friends.kind, StandingKind.unranked);
      expect(friends.goalLine, '대결하면 점수가 쌓여요');
      // Global, my row given with no battle.
      expect(
        RankingStanding.of(
          me: row(1, 0, battles: 0, me: true),
          entries: const [],
          friends: false,
        ).kind,
        StandingKind.unranked,
      );
    });

    test('the friends tab finds my row among its rows, not the global one', () {
      final standing = RankingStanding.of(
        me: row(9, 1, me: true),
        entries: [row(1, 12), row(2, 7, me: true)],
        friends: true,
      );
      expect((standing.rank, standing.points), (2, 7));
      expect(standing.goalLine, '1위까지 5점');
    });

    test('no friends: only me in the friends tab, no goal line', () {
      // RankF2.
      final standing = RankingStanding.of(
        me: null,
        entries: [row(1, 19, battles: 4, me: true)],
        friends: true,
      );
      expect(standing.kind, StandingKind.noFriends);
      expect((standing.rank, standing.points), (1, 19));
      expect(standing.goalLine, isNull);
      expect(standing.fill, isNull);
      // Without a battle either, my card is the unranked one.
      expect(
        RankingStanding.of(
          me: null,
          entries: [row(1, 0, battles: 0, me: true)],
          friends: true,
        ).kind,
        StandingKind.unranked,
      );
    });

    test('a battle with no points (left battles) is still a record', () {
      final standing = RankingStanding.of(
        me: row(3, 0, battles: 2, me: true),
        entries: [row(1, 10), row(2, 5), row(3, 0, battles: 2, me: true)],
        friends: false,
      );
      expect(standing.kind, StandingKind.behind);
      expect((standing.goalRank, standing.gap, standing.fill), (2, 5, 0.0));
    });

    test('values compare by their fields', () {
      const a = RankingStanding(kind: StandingKind.first, friends: false);
      const b = RankingStanding(kind: StandingKind.first, friends: false);
      const c = RankingStanding(kind: StandingKind.first, friends: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('StandingKind.first'));
    });
  });
}
