import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/friends/friend_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _person(int id, String name) => {
  'id': id,
  'nickname': name,
  'code': friendCode(name, id),
};

Map<String, Object?> _invite({
  int id = 7,
  String exercise = 'squat',
  String status = 'pending',
}) => {
  'invite_id': id,
  'from': _person(2, '헬창'),
  'to': _person(1, '쥐돌이'),
  'exercise': exercise,
  'status': status,
  'expires_at': '2026-11-24T12:01:00+00:00',
};

void main() {
  group('friendCode', () {
    test('pads the account id to four digits after the nickname', () {
      expect(friendCode('쥐돌이', 42), '쥐돌이#0042');
      expect(friendCode('헬창', 7), '헬창#0007');
      expect(friendCode('a', 12345), 'a#12345');
    });
  });

  group('ServerFriendRepository', () {
    late List<http.Request> sent;

    ServerFriendRepository repository(
      Object? Function(http.Request request) reply, {
      int status = 200,
    }) {
      sent = [];
      final api = ApiClient(
        baseUrl: Uri.parse('https://api.test/api'),
        httpClient: MockClient((request) async {
          sent.add(request);
          final body = reply(request);
          return http.Response(
            body == null ? '' : jsonEncode(body),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'jwt';
      return ServerFriendRepository(api: api);
    }

    test('reads the overview: code, friends, requests and invites', () async {
      final repo = repository(
        (_) => {
          'code': '쥐돌이#0001',
          'friends': [_person(3, '근육')],
          'incoming': [
            {'request_id': 10, 'from': _person(4, '근손실')},
          ],
          'outgoing': [
            {'request_id': 11, 'to': _person(5, '단백질')},
          ],
          'invites': [_invite()],
        },
      );
      final overview = await repo.fetchOverview();
      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/api/friends');
      expect(sent.single.headers['Authorization'], 'Bearer jwt');
      expect(overview.code, '쥐돌이#0001');
      expect(
        overview.friends.single,
        const FriendPerson(id: 3, nickname: '근육', code: '근육#0003'),
      );
      expect(overview.incoming.single.id, 10);
      expect(overview.incoming.single.person.nickname, '근손실');
      expect(overview.outgoing.single.id, 11);
      expect(overview.outgoing.single.person.id, 5);
      final invite = overview.invites.single;
      expect(invite.id, 7);
      expect(invite.from.nickname, '헬창');
      expect(invite.to.id, 1);
      expect(invite.exercise, ExerciseType.squat);
      expect(invite.status, InviteStatus.pending);
      expect(invite.expiresAt, DateTime.utc(2026, 11, 24, 12, 1));
    });

    test('a reply it cannot read is a server failure', () async {
      final repo = repository((_) => {'code': 3});
      await expectLater(
        repo.fetchOverview(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
      final bad = repository((_) => _invite(exercise: 'plank'));
      await expectLater(bad.fetchInvite(7), throwsA(isA<ApiException>()));
      final status = repository((_) => {'status': 'maybe'});
      await expectLater(
        status.addFriend('a#0001'),
        throwsA(isA<ApiException>()),
      );
    });

    test('addFriend posts the trimmed code and reads the outcome', () async {
      var repo = repository((_) => {'status': 'requested'});
      expect(await repo.addFriend('  헬창#0002 '), FriendAddOutcome.requested);
      expect(sent.single.url.path, '/api/friends/requests');
      expect(jsonDecode(sent.single.body), {'code': '헬창#0002'});
      repo = repository((_) => {'status': 'accepted'});
      expect(await repo.addFriend('헬창#0002'), FriendAddOutcome.accepted);
    });

    test('a refused request carries the server code', () async {
      final repo = repository(
        (_) => {'detail': 'already_requested'},
        status: 409,
      );
      await expectLater(
        repo.addFriend('헬창#0002'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'already_requested')
              .having((e) => e.kind, 'kind', ApiErrorKind.rejected),
        ),
      );
    });

    test('answers and invite calls go to their paths', () async {
      final repo = repository(
        (request) =>
            request.url.path.endsWith('/friends/invites') ||
                request.url.path.endsWith('/accept') &&
                    request.url.path.contains('invites') ||
                request.method == 'GET'
            ? _invite(status: 'accepted')
            : {'status': 'ok'},
      );
      await repo.acceptRequest(10);
      await repo.declineRequest(11);
      final invite = await repo.invite(2, ExerciseType.pushUp);
      expect(invite.status, InviteStatus.accepted);
      await repo.fetchInvite(7);
      await repo.acceptInvite(7);
      await repo.declineInvite(8);
      await repo.cancelInvite(9);
      expect(
        [for (final r in sent) '${r.method} ${r.url.path}'],
        [
          'POST /api/friends/requests/10/accept',
          'POST /api/friends/requests/11/decline',
          'POST /api/friends/invites',
          'GET /api/friends/invites/7',
          'POST /api/friends/invites/7/accept',
          'POST /api/friends/invites/8/decline',
          'POST /api/friends/invites/9/cancel',
        ],
      );
      expect(jsonDecode(sent[2].body), {'friend_id': 2, 'exercise': 'push_up'});
    });

    test('a squat invite says squat', () async {
      final repo = repository((_) => _invite());
      await repo.invite(2, ExerciseType.squat);
      expect(jsonDecode(sent.single.body)['exercise'], 'squat');
    });
  });

  group('InMemoryFriendRepository', () {
    const me = FriendPerson(id: 1, nickname: '쥐돌이', code: '쥐돌이#0001');
    const b = FriendPerson(id: 2, nickname: '헬창', code: '헬창#0002');
    const twin = FriendPerson(id: 3, nickname: '헬창', code: '헬창#0003');
    late DateTime clock;
    late InMemoryFriendRepository repo;

    setUp(() {
      clock = DateTime(2026, 11, 24, 12);
      repo = InMemoryFriendRepository(
        me: me,
        people: const [b, twin],
        now: () => clock,
      );
    });

    Future<String?> refusal(Future<Object?> call) async {
      try {
        await call;
        return null;
      } on ApiException catch (error) {
        return error.code;
      }
    }

    test('a request waits, and asking back makes friends', () async {
      expect(await repo.addFriend('헬창#0002'), FriendAddOutcome.requested);
      expect(await refusal(repo.addFriend('헬창#0002')), 'already_requested');
      repo.outgoing.clear();
      repo.incoming.add(const FriendRequestItem(id: 50, person: b));
      expect(await repo.addFriend('헬창#0002'), FriendAddOutcome.accepted);
      expect((await repo.fetchOverview()).friends, [b]);
      expect(await refusal(repo.addFriend('헬창#0002')), 'already_friends');
    });

    test('codes are checked like the server checks them', () async {
      expect(await refusal(repo.addFriend('헬창')), 'invalid_code');
      // At least the four digits a code shows.
      expect(await refusal(repo.addFriend('헬창#2')), 'invalid_code');
      expect(await refusal(repo.addFriend('쥐돌이#0001')), 'cannot_add_self');
      expect(await refusal(repo.addFriend('헬창#0009')), 'user_not_found');
      expect(await repo.addFriend('헬창#0003'), FriendAddOutcome.requested);
      expect(repo.outgoing.single.person, twin);
    });

    test('incoming requests are accepted or declined once', () async {
      repo.incoming.addAll(const [
        FriendRequestItem(id: 10, person: b),
        FriendRequestItem(id: 11, person: twin),
      ]);
      await repo.acceptRequest(10);
      await repo.declineRequest(11);
      final overview = await repo.fetchOverview();
      expect(overview.friends, [b]);
      expect(overview.incoming, isEmpty);
      expect(await refusal(repo.acceptRequest(10)), 'request_not_found');
      expect(await refusal(repo.declineRequest(11)), 'request_not_found');
    });

    test('only friends are invited; a new invite cancels my last', () async {
      expect(await refusal(repo.invite(2, ExerciseType.pushUp)), 'not_friends');
      repo.friends.addAll(const [b, twin]);
      final first = await repo.invite(2, ExerciseType.pushUp);
      expect(first.expiresAt, clock.add(const Duration(minutes: 1)));
      await repo.invite(3, ExerciseType.squat);
      expect((await repo.fetchInvite(first.id)).status, InviteStatus.cancelled);
      // My own invites are not ones to answer.
      expect((await repo.fetchOverview()).invites, isEmpty);
    });

    test('invites to me show newest first until their minute is up', () async {
      final old = repo.receiveInvite(b, ExerciseType.pushUp);
      clock = clock.add(const Duration(seconds: 30));
      final fresh = repo.receiveInvite(twin, ExerciseType.squat);
      expect(
        [for (final i in (await repo.fetchOverview()).invites) i.id],
        [fresh.id, old.id],
      );
      clock = clock.add(const Duration(seconds: 30));
      expect(
        [for (final i in (await repo.fetchOverview()).invites) i.id],
        [fresh.id],
      );
      expect((await repo.fetchInvite(old.id)).status, InviteStatus.expired);
      expect(await refusal(repo.acceptInvite(old.id)), 'invite_expired');
    });

    test('accept, decline and cancel follow the server rules', () async {
      final a = repo.receiveInvite(b, ExerciseType.pushUp);
      expect((await repo.acceptInvite(a.id)).status, InviteStatus.accepted);
      expect(await refusal(repo.declineInvite(a.id)), 'invite_closed');
      // Either player may still take back an accepted invite.
      await repo.cancelInvite(a.id);
      expect((await repo.fetchInvite(a.id)).status, InviteStatus.cancelled);
      expect(await refusal(repo.cancelInvite(a.id)), 'invite_closed');
      final d = repo.receiveInvite(b, ExerciseType.pushUp);
      await repo.declineInvite(d.id);
      repo.answer(d.id, InviteStatus.pending);
      expect((await repo.fetchInvite(d.id)).status, InviteStatus.pending);
      expect(await refusal(repo.fetchInvite(99)), 'invite_not_found');
    });
  });

  test('FriendPerson compares by value', () {
    const a = FriendPerson(id: 1, nickname: 'a', code: 'a#0001');
    expect(a, const FriendPerson(id: 1, nickname: 'a', code: 'a#0001'));
    expect(
      a.hashCode,
      const FriendPerson(id: 1, nickname: 'a', code: 'a#0001').hashCode,
    );
    expect(
      a == const FriendPerson(id: 2, nickname: 'a', code: 'a#0001'),
      isFalse,
    );
  });
}
