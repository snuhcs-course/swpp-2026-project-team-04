import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _row(
  int id,
  String name, {
  int rank = 1,
  int points = 15,
  bool me = false,
}) => {
  'user_id': id,
  'nickname': name,
  'rank': rank,
  'points': points,
  'battles': 2,
  'wins': 2,
  'ko_wins': 1,
  'is_me': me,
};

Map<String, Object?> _body({String scope = 'global', Object? me}) => {
  'scope': scope,
  'week_start': '2026-11-23T00:00:00+09:00',
  'week_end': '2026-11-30T00:00:00+09:00',
  'entries': [_row(2, '헬창'), _row(1, '쥐돌이', rank: 2, points: 6, me: true)],
  'me': me,
};

void main() {
  group('ServerRankingsRepository', () {
    late List<http.Request> sent;

    ServerRankingsRepository repository(Object? reply, {int status = 200}) {
      sent = [];
      final api = ApiClient(
        baseUrl: Uri.parse('https://api.test/api'),
        httpClient: MockClient((request) async {
          sent.add(request);
          return http.Response(
            reply == null ? '' : jsonEncode(reply),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'jwt';
      return ServerRankingsRepository(api: api);
    }

    test('reads the global week with every row and mine', () async {
      final repo = repository(
        _body(me: _row(1, '쥐돌이', rank: 2, points: 6, me: true)),
      );

      final ranking = await repo.fetchWeekly(RankingScope.global);

      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/api/matches/rankings/weekly');
      expect(sent.single.url.queryParameters, {'scope': 'global'});
      expect(sent.single.headers['Authorization'], 'Bearer jwt');
      expect(ranking.scope, RankingScope.global);
      expect(ranking.weekStart, DateTime.utc(2026, 11, 22, 15));
      expect(ranking.weekEnd, DateTime.utc(2026, 11, 29, 15));
      expect(ranking.entries, [
        const RankingEntry(
          rank: 1,
          userId: 2,
          nickname: '헬창',
          points: 15,
          battles: 2,
          wins: 2,
          koWins: 1,
          isMe: false,
        ),
        const RankingEntry(
          rank: 2,
          userId: 1,
          nickname: '쥐돌이',
          points: 6,
          battles: 2,
          wins: 2,
          koWins: 1,
          isMe: true,
        ),
      ]);
      expect(ranking.me, ranking.entries.last);
    });

    test('asks for the friends scope by name', () async {
      final repo = repository(
        _body(scope: 'friends', me: _row(1, '쥐돌이', me: true)),
      );

      final ranking = await repo.fetchWeekly(RankingScope.friends);

      expect(sent.single.url.queryParameters, {'scope': 'friends'});
      expect(ranking.scope, RankingScope.friends);
    });

    test('a week without my battle has no row of mine', () async {
      final ranking = await repository(_body())
          .fetchWeekly(RankingScope.global);

      expect(ranking.me, isNull);
    });

    test('a reply it cannot read is a server error', () async {
      final repo = repository({'scope': 'global', 'entries': 'none'});

      await expectLater(
        repo.fetchWeekly(RankingScope.global),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
    });

    test('an error status passes through as the API client maps it', () async {
      final repo = repository({'detail': 'nope'}, status: 401);

      await expectLater(
        repo.fetchWeekly(RankingScope.global),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('RankingEntry', () {
    const entry = RankingEntry(
      rank: 1,
      userId: 2,
      nickname: '헬창',
      points: 15,
      battles: 2,
      wins: 2,
      koWins: 1,
      isMe: false,
    );

    test('is equal by value', () {
      const same = RankingEntry(
        rank: 1,
        userId: 2,
        nickname: '헬창',
        points: 15,
        battles: 2,
        wins: 2,
        koWins: 1,
        isMe: false,
      );
      expect(entry, same);
      expect(entry.hashCode, same.hashCode);
      expect(entry == Object(), isFalse);
    });
  });

  group('RankingPoints', () {
    test('match the server: KO 10, win 5, draw 3, loss 1, leaving 0', () {
      expect(
        [
          RankingPoints.koWin,
          RankingPoints.win,
          RankingPoints.draw,
          RankingPoints.loss,
          RankingPoints.leftBattle,
        ],
        [10, 5, 3, 1, 0],
      );
    });
  });

  group('InMemoryRankingsRepository', () {
    test('returns the given week and counts the reads', () async {
      final week = WeeklyRanking(
        scope: RankingScope.friends,
        weekStart: DateTime.utc(2026, 11, 22, 15),
        weekEnd: DateTime.utc(2026, 11, 29, 15),
        entries: const [],
        me: null,
      );
      final repo = InMemoryRankingsRepository(
        rankings: {RankingScope.friends: week},
      );

      expect(await repo.fetchWeekly(RankingScope.friends), same(week));
      final empty = await repo.fetchWeekly(RankingScope.global);

      expect(empty.scope, RankingScope.global);
      expect(empty.entries, isEmpty);
      expect(repo.reads, {RankingScope.friends: 1, RankingScope.global: 1});
    });
  });
}
