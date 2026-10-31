import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/auth_session.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/services/auth/token_store.dart';
import 'package:gymrats_app/services/user/server_user_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/form_report_fixtures.dart';

const _match = {
  'id': 9,
  'exercise': 'push_up',
  'opponent_name': 'RepBot',
  'my_reps': 24,
  'opponent_reps': 19,
  'played_at': '2026-10-15T03:00:00Z',
};

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

MatchRecord _record(int mine) => MatchRecord(
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: mine,
  opponentReps: 10,
  playedAt: DateTime.utc(2026, 10, 15, 3, mine),
);

AuthSession _session(int id) => AuthSession(
  token: 't$id',
  account: Account(id: id, loginId: 'user$id', nickname: '유저$id'),
);

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) answer;
  late InMemoryAuthRepository auth;
  late ServerUserRepository repository;

  setUp(() async {
    requests = [];
    answer = (_) => _json({});
    // Id 7, so accounts signed up in a test (ids from 1) differ from it.
    auth = InMemoryAuthRepository(store: MemoryTokenStore(_session(7)));
    await auth.restoreSession();
    final api = ApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      baseUrl: Uri.parse('http://server.test'),
    );
    repository = ServerUserRepository(api: api, auth: auth);
  });

  List<Map<String, Object?>> posted() => requests
      .where((r) => r.method == 'POST')
      .map((r) => jsonDecode(r.body) as Map<String, Object?>)
      .toList();

  test('reads the profile', () async {
    answer = (_) => _json({
      'id': 1,
      'login_id': 'woohyun',
      'nickname': '우현',
      'best_reps': 32,
      'last_match': _match,
    });
    final profile = await repository.fetchProfile();
    expect(requests.single.url.path, '/users/me');
    expect(profile.name, '우현');
    expect(profile.bestReps, 32);
    expect(profile.lastMatch!.myReps, 24);
    expect(profile.lastMatch!.opponentReps, 19);
    expect(profile.lastMatch!.exercise, ExerciseType.pushUp);
    expect(
      profile.lastMatch!.playedAt!.isAtSameMomentAs(
        DateTime.utc(2026, 10, 15, 3),
      ),
      isTrue,
    );
    expect(profile.unsentMatches, 0);
  });

  test('a new user has no record', () async {
    answer = (_) => _json({
      'id': 1,
      'login_id': 'woohyun',
      'nickname': '우현',
      'best_reps': null,
      'last_match': null,
    });
    final profile = await repository.fetchProfile();
    expect(profile.bestReps, isNull);
    expect(profile.lastMatch, isNull);
  });

  test('an unreadable profile is a server error', () async {
    answer = (_) => _json({'nickname': 3});
    await expectLater(
      repository.fetchProfile(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.server),
      ),
    );
  });

  test('saves a battle with its numbers, UTC time, and an id', () async {
    await repository.saveMatch(_record(24));
    final body = posted().single;
    expect(requests.single.url.path, '/matches');
    expect(body['exercise'], 'push_up');
    expect(body['opponent_name'], 'RepBot');
    expect(body['my_reps'], 24);
    expect(body['opponent_reps'], 10);
    expect(body['played_at'], '2026-10-15T03:24:00.000Z');
    expect(body['client_id'], matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('a failed save is kept and sent again, with the same id', () async {
    answer = (_) => throw const SocketException('down');
    await expectLater(
      repository.saveMatch(_record(24)),
      throwsA(isA<ApiException>()),
    );
    final firstId = posted().single['client_id'];

    // Still offline: the profile load fails too.
    await expectLater(repository.fetchProfile(), throwsA(isA<ApiException>()));

    answer = (request) => request.method == 'POST'
        ? _json(_match, 201)
        : _json({
            'id': 1,
            'login_id': 'user1',
            'nickname': '유저1',
            'best_reps': 24,
            'last_match': _match,
          });
    requests.clear();
    final profile = await repository.fetchProfile();
    expect(posted().single['client_id'], firstId);
    expect(requests.last.url.path, '/users/me');
    expect(profile.unsentMatches, 0);
  });

  test('the profile counts battles still waiting to be sent', () async {
    answer = (request) => request.method == 'POST'
        ? _json({}, 503)
        : _json({
            'id': 1,
            'login_id': 'user1',
            'nickname': '유저1',
            'best_reps': null,
            'last_match': null,
          });
    await expectLater(
      repository.saveMatch(_record(1)),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      repository.saveMatch(_record(2)),
      throwsA(isA<ApiException>()),
    );
    final profile = await repository.fetchProfile();
    expect(profile.unsentMatches, 2);
  });

  test('queued battles are sent oldest first', () async {
    answer = (_) => _json({}, 503);
    await expectLater(repository.saveMatch(_record(1)), throwsA(anything));
    await expectLater(repository.saveMatch(_record(2)), throwsA(anything));
    answer = (request) => request.method == 'POST'
        ? _json(_match, 201)
        : _json({'items': [], 'next_before': null});
    requests.clear();
    await repository.fetchHistory();
    expect(posted().map((b) => b['my_reps']), [1, 2]);
  });

  test("another account's queued battles are not sent", () async {
    answer = (_) => _json({}, 503);
    await expectLater(repository.saveMatch(_record(1)), throwsA(anything));
    await auth.logOut();
    await auth.signUp(nickname: '다른', loginId: 'other', password: 'password1');
    answer = (request) => request.method == 'POST'
        ? _json(_match, 201)
        : _json({
            'id': 2,
            'login_id': 'other',
            'nickname': '다른',
            'best_reps': null,
            'last_match': null,
          });
    requests.clear();
    final profile = await repository.fetchProfile();
    expect(posted(), isEmpty);
    expect(profile.unsentMatches, 0);
  });

  test('saving while logged out fails without a request', () async {
    await auth.logOut();
    await expectLater(
      repository.saveMatch(_record(1)),
      throwsA(isA<ApiException>()),
    );
    expect(requests, isEmpty);
  });

  test('reads a history page and its cursor', () async {
    answer = (_) => _json({
      'items': [
        _match,
        {..._match, 'id': 8, 'my_reps': 10},
      ],
      'next_before': 8,
    });
    final page = await repository.fetchHistory(limit: 2);
    expect(requests.single.url.queryParameters, {'limit': '2'});
    expect(page.items.map((m) => m.myReps), [24, 10]);
    expect(page.nextCursor, '8');

    answer = (_) => _json({'items': [], 'next_before': null});
    final next = await repository.fetchHistory(cursor: '8', limit: 2);
    expect(requests.last.url.queryParameters, {'limit': '2', 'before': '8'});
    expect(next.items, isEmpty);
    expect(next.nextCursor, isNull);
  });

  test('an unknown exercise in history is a server error', () async {
    answer = (_) => _json({
      'items': [
        {..._match, 'exercise': 'plank'},
      ],
      'next_before': null,
    });
    await expectLater(repository.fetchHistory(), throwsA(isA<ApiException>()));
  });

  test(
    'a battle the server refuses leaves the queue and does not block',
    () async {
      // Battle 1 waits in the queue while the server is down.
      answer = (_) => _json({}, 503);
      await expectLater(repository.saveMatch(_record(1)), throwsA(anything));

      // The server is back but refuses battle 1 for good (e.g. a 422):
      // it is dropped, and battle 2 is still sent and saved.
      answer = (request) {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        return body['my_reps'] == 1
            ? _json({'detail': 'invalid'}, 422)
            : _json(_match, 201);
      };
      requests.clear();
      await repository.saveMatch(_record(2));
      expect(posted().map((b) => b['my_reps']), [1, 2]);

      // A refused new battle is reported to the caller and not kept.
      answer = (_) => _json({'detail': 'invalid'}, 422);
      await expectLater(
        repository.saveMatch(_record(3)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.rejected,
          ),
        ),
      );
      answer = (_) => _json({
        'id': 7,
        'login_id': 'user7',
        'nickname': '유저7',
        'best_reps': 2,
        'last_match': _match,
      });
      requests.clear();
      final profile = await repository.fetchProfile();
      expect(posted(), isEmpty);
      expect(profile.unsentMatches, 0);
    },
  );

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  group('feedback', () {
    final profileJson = {
      'id': 7,
      'login_id': 'user7',
      'nickname': '유저7',
      'best_reps': null,
      'last_match': null,
    };

    List<http.Request> puts() =>
        requests.where((r) => r.method == 'PUT').toList();

    test('a bot battle is uploaded with its summary and full report', () async {
      final report = sampleReport(valid: 3, rejected: 1);
      await repository.saveMatch(_record(24), report: report);
      final feedback = posted().single['feedback']! as Map<String, Object?>;
      final summary = feedback['summary']! as Map<String, Object?>;
      expect(summary['valid_reps'], 3);
      expect(summary['invalid_reps'], 1);
      expect(summary['accuracy'], 0.75);
      expect(summary.containsKey('top_issue'), isTrue);
      expect(feedback['report'], jsonDecode(jsonEncode(report.toJson())));
    });

    test('a queued battle keeps its feedback for the retry', () async {
      answer = (_) => throw const SocketException('down');
      await expectLater(
        repository.saveMatch(_record(24), report: sampleReport()),
        throwsA(isA<ApiException>()),
      );
      final firstId = posted().single['client_id'];
      answer = (request) =>
          request.method == 'POST' ? _json(_match, 201) : _json(profileJson);
      requests.clear();
      await repository.fetchProfile();
      final retried = posted().single;
      expect(retried['client_id'], firstId);
      expect(retried['feedback'], isNotNull);
    });

    test('a refused report is dropped but the battle is still saved', () async {
      answer = (request) {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        // nginx answers a body over its limit with an HTML page.
        return body.containsKey('feedback')
            ? http.Response('<html>413 Request Entity Too Large</html>', 413)
            : _json(_match, 201);
      };
      await repository.saveMatch(_record(24), report: sampleReport());
      expect(posted(), hasLength(2));
      expect(posted().last.containsKey('feedback'), isFalse);
      expect(posted().last['client_id'], posted().first['client_id']);
    });

    test('online feedback is put under the result id', () async {
      await repository.saveFeedback('a' * 32, sampleReport());
      final put = puts().single;
      expect(put.url.path, '/matches/feedback/${'a' * 32}');
      final body = jsonDecode(put.body) as Map<String, Object?>;
      expect(body.keys, containsAll(['summary', 'report']));
    });

    test(
      'failed online feedback waits in the queue but is not a battle',
      () async {
        answer = (_) => _json({}, 503);
        await expectLater(
          repository.saveFeedback('r' * 32, sampleReport()),
          throwsA(isA<ApiException>()),
        );
        answer = (request) =>
            request.method == 'PUT' ? _json({}, 503) : _json(profileJson);
        final waiting = await repository.fetchProfile();
        expect(waiting.unsentMatches, 0);
        answer = (request) => request.method == 'PUT'
            ? _json({'client_id': 'r' * 32}, 201)
            : _json(profileJson);
        requests.clear();
        await repository.fetchProfile();
        expect(puts().single.url.path, '/matches/feedback/${'r' * 32}');
        requests.clear();
        await repository.fetchProfile();
        expect(puts(), isEmpty);
      },
    );

    test('feedback refused by the proxy leaves the queue', () async {
      answer = (_) => http.Response('<html>413</html>', 413);
      await expectLater(
        repository.saveFeedback('r' * 32, sampleReport()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.rejected,
          ),
        ),
      );
      answer = (request) =>
          request.method == 'POST' ? _json(_match, 201) : _json(profileJson);
      requests.clear();
      await repository.saveMatch(_record(5));
      expect(puts(), isEmpty);
      expect(posted().single['my_reps'], 5);
    });

    test('online feedback while logged out fails without a request', () async {
      await auth.logOut();
      await expectLater(
        repository.saveFeedback('r' * 32, sampleReport()),
        throwsA(isA<ApiException>()),
      );
      expect(requests, isEmpty);
    });

    test('history rows carry id, stored outcome, and summary', () async {
      answer = (_) => _json({
        'items': [
          {
            ..._match,
            'id': 3,
            'my_reps': 20,
            'opponent_reps': 3,
            'outcome': 'loss',
            'reason': 'forfeit',
            'has_feedback': true,
            'feedback_summary': {
              'valid_reps': 20,
              'invalid_reps': 1,
              'accuracy': 0.95,
              'top_issue': null,
              'issue_count': 0,
            },
          },
          {
            ..._match,
            'id': 2,
            'outcome': 'draw',
            'has_feedback': false,
            'feedback_summary': null,
          },
        ],
        'next_before': null,
      });
      final page = await repository.fetchHistory();
      final [forfeit, old] = page.items;
      expect(forfeit.id, 3);
      expect(forfeit.outcome, MatchOutcome.lose);
      expect(forfeit.feedbackSummary!.line, '좋은 자세');
      expect(old.outcome, MatchOutcome.draw);
      expect(old.hasFeedback, isFalse);
    });

    test('an unknown outcome is a server error', () async {
      answer = (_) => _json({
        'items': [
          {..._match, 'outcome': 'surrender'},
        ],
        'next_before': null,
      });
      await expectLater(
        repository.fetchHistory(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
    });

    test('recent battles are the first page with the given limit', () async {
      answer = (_) => _json({
        'items': [_match],
        'next_before': 9,
      });
      final recent = await repository.fetchRecent();
      expect(recent, hasLength(1));
      expect(requests.single.url.queryParameters['limit'], '3');
    });

    test('loads the full report of a battle', () async {
      final report = sampleReport(valid: 4);
      answer = (_) =>
          _json({'match_id': 9, 'summary': {}, 'report': report.toJson()});
      final loaded = await repository.fetchFeedback(9);
      expect(requests.single.url.path, '/matches/9/feedback');
      expect(loaded!.validReps, 4);
      expect(loaded.endedAt.isAtSameMomentAs(report.endedAt), isTrue);
    });

    test('a battle without feedback loads as null', () async {
      answer = (_) => _json({'detail': 'not_found'}, 404);
      expect(await repository.fetchFeedback(9), isNull);
    });

    test('other failures and unreadable reports are errors', () async {
      answer = (_) => _json({}, 500);
      await expectLater(
        repository.fetchFeedback(9),
        throwsA(isA<ApiException>()),
      );
      answer = (_) => _json({'report': 'nope'});
      await expectLater(
        repository.fetchFeedback(9),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
    });
  });
}
