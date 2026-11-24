import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/friends/friend_repository.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/services/telemetry/telemetry_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Answers each batch with the next of [answers] (then [last]) and keeps it.
class FakeSender {
  FakeSender([
    this.answers = const [],
    this.last = TelemetrySendResult.delivered,
  ]);

  final List<TelemetrySendResult> answers;
  final TelemetrySendResult last;
  final batches = <List<Map<String, Object?>>>[];
  Object? error;

  Future<TelemetrySendResult> call(List<Map<String, Object?>> batch) async {
    batches.add(batch);
    if (error case final e?) throw e;
    final i = batches.length - 1;
    return i < answers.length ? answers[i] : last;
  }
}

void main() {
  group('events (P17)', () {
    test('a start carries the common fields and only what the screen gave', () {
      final t = Telemetry(now: () => DateTime.utc(2026, 12, 2, 1, 2, 3));
      final attempt = t.begin(TelemetryFlow.setup, {
        'exercise': 'squat',
        'mode': 'bot',
      });
      final event = t.pending.single;
      expect(event.keys.toSet(), {
        'event',
        'event_id',
        'ts',
        'session_id',
        'app_version',
        'attempt_id',
        'exercise',
        'mode',
      });
      expect(event['event'], 'setup_started');
      expect(event['event_id'], matches(uuid));
      expect(event['ts'], '2026-12-02T01:02:03.000Z');
      expect(event['session_id'], t.sessionId);
      expect(t.sessionId, matches(uuid));
      expect(event['app_version'], telemetryAppVersion);
      expect(event['attempt_id'], attempt.id);
    });

    test('local times are sent in UTC', () {
      final t = Telemetry(now: () => DateTime(2026, 12, 2, 10));
      t.begin(TelemetryFlow.tutorial, {'pages_total': 3});
      expect(DateTime.parse(t.pending.single['ts']! as String).isUtc, isTrue);
    });

    test('an end is recorded once, with the time since its start', () {
      {
        var clock = DateTime.utc(2026, 12, 2);
        final t = Telemetry(now: () => clock);
        final attempt = t.begin(TelemetryFlow.tutorial, {'pages_total': 12});
        clock = clock.add(const Duration(milliseconds: 1500));
        attempt.finish('skipped', {'last_page': 3});
        attempt.finish('completed', {'last_page': 12});
        expect(attempt.finished, isTrue);
        final end = t.pending.last;
        expect(t.pending, hasLength(2));
        expect(end['event'], 'tutorial_finished');
        expect(end['attempt_id'], attempt.id);
        expect(end['result'], 'skipped');
        expect(end['last_page'], 3);
        expect(end['duration_ms'], 1500);
      }
    });

    test('a clock set back mid-way gives 0, not a negative time', () {
      var clock = DateTime.utc(2026, 12, 2);
      final t = Telemetry(now: () => clock);
      final attempt = t.begin(TelemetryFlow.setup, {});
      clock = clock.subtract(const Duration(minutes: 1));
      attempt.finish('ready');
      expect(t.pending.last['duration_ms'], 0);
    });

    test('matching measures its wait as wait_ms', () {
      final t = Telemetry();
      t
          .begin(TelemetryFlow.matching, {
            'exercise': 'push_up',
            'kind': 'main',
          })
          .finish('found');
      expect(t.pending.last['event'], 'matching_finished');
      expect(t.pending.last.containsKey('wait_ms'), isTrue);
      expect(t.pending.last.containsKey('duration_ms'), isFalse);
    });

    test('each attempt and event has its own id; a run keeps one session', () {
      final t = Telemetry();
      final a = t.begin(TelemetryFlow.matching, {});
      final b = t.begin(TelemetryFlow.matching, {});
      expect(a.id, isNot(b.id));
      expect(t.pending[0]['event_id'], isNot(t.pending[1]['event_id']));
      expect(t.pending[0]['session_id'], t.pending[1]['session_id']);
      expect(Telemetry().sessionId, isNot(t.sessionId));
    });

    test('setup reasons are written as in the dictionary', () {
      expect(
        {for (final r in SetupReason.values) r: setupReasonCode(r)},
        {
          SetupReason.noPerson: 'no_person',
          SetupReason.tooClose: 'too_close',
          SetupReason.tooFar: 'too_far',
          SetupReason.notFacingForward: 'not_facing_forward',
          SetupReason.missingParts: 'missing_parts',
          SetupReason.notInPushUp: 'not_in_push_up',
          SetupReason.notStanding: 'not_standing',
          SetupReason.phoneTooFlat: 'phone_too_flat',
          SetupReason.phoneShaky: 'phone_shaky',
          SetupReason.ready: null,
        },
      );
    });

    test('past the limit the oldest events are dropped', () {
      final t = Telemetry(maxPending: 3);
      for (var i = 0; i < 5; i++) {
        t.begin(TelemetryFlow.tutorial, {'pages_total': i + 1});
      }
      expect(t.pending.map((e) => e['pages_total']), [3, 4, 5]);
    });

    test('after dispose nothing more is recorded', () {
      final t = Telemetry();
      final attempt = t.begin(TelemetryFlow.setup, {});
      t.dispose();
      attempt.finish('cancelled');
      expect(t.pending, hasLength(1));
    });
  });

  group('sending', () {
    test('without a sender nothing is sent or scheduled', () {
      fakeAsync((async) {
        final t = Telemetry();
        t.begin(TelemetryFlow.tutorial, {'pages_total': 3});
        async.elapse(const Duration(minutes: 5));
        expect(async.pendingTimers, isEmpty);
        expect(t.pending, hasLength(1));
      });
    });

    test('events go a short while after they are recorded, together', () {
      fakeAsync((async) {
        final sender = FakeSender();
        final t = Telemetry(send: sender.call);
        t.begin(TelemetryFlow.matching, {}).finish('cancelled');
        async.elapse(const Duration(milliseconds: 2999));
        expect(sender.batches, isEmpty);
        async.elapse(const Duration(milliseconds: 2));
        expect(sender.batches.single.map((e) => e['event']), [
          'matching_started',
          'matching_finished',
        ]);
        expect(t.pending, isEmpty);
      });
    });

    test('a batch that has to wait stays and is tried again later', () {
      fakeAsync((async) {
        final sender = FakeSender([TelemetrySendResult.later]);
        final t = Telemetry(send: sender.call);
        t.begin(TelemetryFlow.tutorial, {'pages_total': 3});
        async.elapse(const Duration(seconds: 4));
        expect(t.pending, hasLength(1));
        async.elapse(const Duration(seconds: 30));
        expect(sender.batches, hasLength(2));
        expect(t.pending, isEmpty);
      });
    });

    test('a sender that throws counts as later', () {
      fakeAsync((async) {
        final sender = FakeSender()..error = StateError('offline');
        final t = Telemetry(send: sender.call);
        t.begin(TelemetryFlow.tutorial, {'pages_total': 3});
        async.elapse(const Duration(seconds: 4));
        expect(t.pending, hasLength(1));
      });
    });

    test('without a login the server takes, it waits for the next login, '
        'not the retry timer', () {
      fakeAsync((async) {
        final sender = FakeSender([TelemetrySendResult.unauthorized]);
        final t = Telemetry(send: sender.call);
        t.begin(TelemetryFlow.tutorial, {'pages_total': 3});
        async.elapse(const Duration(minutes: 5));
        expect(sender.batches, hasLength(1));
        expect(t.pending, hasLength(1));
        t.flush();
        async.flushMicrotasks();
        expect(sender.batches, hasLength(2));
        expect(t.pending, isEmpty);
      });
    });

    test("each account's events go only with its own login; one recorded "
        'signed out goes with the next', () {
      fakeAsync((async) {
        String? who = '1';
        final sender = FakeSender();
        final t = Telemetry(send: sender.call, owner: () => who);
        t.begin(TelemetryFlow.setup, {'mode': 'a'});
        who = null;
        t.begin(TelemetryFlow.setup, {'mode': 'out'});
        async.elapse(const Duration(seconds: 10));
        // Signed out: nothing goes.
        expect(sender.batches, isEmpty);
        who = '2';
        t.begin(TelemetryFlow.setup, {'mode': 'b'});
        async.elapse(const Duration(seconds: 4));
        expect(sender.batches.single.map((e) => e['mode']), ['out', 'b']);
        // The account key stays on the phone; it is never sent.
        expect(
          sender.batches.single.every((e) => !e.containsKey('_owner')),
          isTrue,
        );
        expect(t.pending.single['mode'], 'a');
        who = '1';
        t.flush();
        async.flushMicrotasks();
        expect(sender.batches.last.single['mode'], 'a');
        expect(t.pending, isEmpty);
      });
    });

    test(
      'an account switch while sending stops before the next batch',
      () async {
        String? who = '1';
        final batches = <int>[];
        final t = Telemetry(
          send: (batch) async {
            batches.add(batch.length);
            who = '2';
            return TelemetrySendResult.delivered;
          },
          owner: () => who,
          batchSize: 1,
          flushDelay: const Duration(hours: 1),
        );
        t.begin(TelemetryFlow.tutorial, {'pages_total': 1});
        t.begin(TelemetryFlow.tutorial, {'pages_total': 2});
        await t.flush();
        expect(batches, [1]);
        expect(t.pending.single['pages_total'], 2);
        t.dispose();
      },
    );

    test('a login while the last account is still sending sends the new '
        "account's events when that send ends", () async {
      String? who = '1';
      final sent = <List<Object?>>[];
      final inFlight = Completer<void>();
      final t = Telemetry(
        send: (batch) async {
          sent.add([for (final e in batch) e['mode']]);
          if (sent.length == 1) await inFlight.future;
          return TelemetrySendResult.delivered;
        },
        owner: () => who,
        flushDelay: const Duration(hours: 1),
      );
      t.begin(TelemetryFlow.setup, {'mode': 'a'});
      final first = t.flush();
      // B signs in while A's batch is on its way; the app flushes on login.
      who = '2';
      t.begin(TelemetryFlow.setup, {'mode': 'b'});
      await t.flush();
      inFlight.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(sent, [
        ['a'],
        ['b'],
      ]);
      expect(t.pending, isEmpty);
      t.dispose();
    });

    test('a refused batch is dropped, not retried', () {
      fakeAsync((async) {
        final sender = FakeSender([TelemetrySendResult.refused]);
        final t = Telemetry(send: sender.call);
        t.begin(TelemetryFlow.tutorial, {'pages_total': 3});
        async.elapse(const Duration(minutes: 2));
        expect(sender.batches, hasLength(1));
        expect(t.pending, isEmpty);
      });
    });

    test(
      'large queues go in batches; events recorded while sending stay',
      () async {
        late Telemetry t;
        var first = true;
        final batches = <int>[];
        t = Telemetry(
          send: (batch) async {
            batches.add(batch.length);
            if (first) {
              first = false;
              t.begin(TelemetryFlow.setup, {'mode': 'late'});
            }
            return TelemetrySendResult.delivered;
          },
          batchSize: 2,
          flushDelay: const Duration(hours: 1),
        );
        for (var i = 0; i < 3; i++) {
          t.begin(TelemetryFlow.tutorial, {'pages_total': i + 1});
        }
        await t.flush();
        expect(batches, [2, 2]);
        expect(t.pending, isEmpty);
        t.dispose();
      },
    );
  });

  group('the copy on the phone', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('telemetry'));
    tearDown(() => dir.delete(recursive: true));

    test('what was not sent is read by the next app run, before its own '
        'events', () async {
      final first = Telemetry(root: () async => dir.path);
      first.begin(TelemetryFlow.tutorial, {'pages_total': 1});
      first.begin(TelemetryFlow.tutorial, {'pages_total': 2});
      await first.saved();
      first.dispose();

      final next = Telemetry(root: () async => dir.path);
      next.begin(TelemetryFlow.tutorial, {'pages_total': 3});
      await next.load();
      expect(next.pending.map((e) => e['pages_total']), [1, 2, 3]);
      // On the phone too: this run's first write keeps the earlier events.
      await next.saved();
      final file = File(
        '${dir.path}${Platform.pathSeparator}telemetry_pending.json',
      );
      final onPhone = jsonDecode(await file.readAsString()) as List;
      expect(onPhone.map((e) => (e as Map)['pages_total']), [1, 2, 3]);
      next.dispose();
    });

    test('a broken copy is dropped', () async {
      final file = File(
        '${dir.path}${Platform.pathSeparator}telemetry_pending.json',
      );
      await file.writeAsString('{not json');
      final t = Telemetry(root: () async => dir.path);
      await t.load();
      expect(t.pending, isEmpty);
      expect(await file.exists(), isFalse);
    });

    test('without a folder nothing is written or read', () async {
      final t = Telemetry(root: () async => null);
      t.begin(TelemetryFlow.tutorial, {'pages_total': 1});
      await t.saved();
      await t.load();
      expect(t.pending, hasLength(1));
    });
  });

  group('the HTTP sender', () {
    final base = Uri.parse('https://api.test/api');
    final batch = [
      {'event': 'tutorial_started'},
    ];

    (ApiClient, List<http.Request>, List<void>) api(
      Future<http.Response> Function(http.Request) answer, {
      String? token = 'token-1',
    }) {
      final requests = <http.Request>[];
      final client = ApiClient(baseUrl: base)..token = token;
      final loggedOut = <void>[];
      client.unauthorized.listen(loggedOut.add);
      return (client, requests, loggedOut);
    }

    test('logged out, it waits for a login and sends nothing', () async {
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response('{}', 200);
      });
      final (a, _, _) = api((_) async => http.Response('{}', 200), token: null);
      expect(
        await httpTelemetrySender(a, client: client)(batch),
        TelemetrySendResult.unauthorized,
      );
      expect(requests, isEmpty);
    });

    test('posts the batch with the login', () async {
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response('{"stored": 1}', 200);
      });
      final (a, _, _) = api((_) async => http.Response('{}', 200));
      expect(
        await httpTelemetrySender(a, client: client)(batch),
        TelemetrySendResult.delivered,
      );
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.test/api/telemetry/events');
      expect(request.headers['Authorization'], 'Bearer token-1');
      expect(jsonDecode(request.body), {'events': batch});
    });

    for (final (status, result) in [
      (401, TelemetrySendResult.unauthorized),
      (429, TelemetrySendResult.later),
      (503, TelemetrySendResult.later),
      // The app may be out before the server has the telemetry API.
      (404, TelemetrySendResult.later),
      (422, TelemetrySendResult.refused),
      (400, TelemetrySendResult.refused),
    ]) {
      test('HTTP $status is $result', () async {
        final client = MockClient((_) async => http.Response('{}', status));
        final (a, _, loggedOut) = api((_) async => http.Response('{}', 200));
        expect(await httpTelemetrySender(a, client: client)(batch), result);
        // A rejected token never logs the user out from here.
        expect(loggedOut, isEmpty);
      });
    }

    test('no connection or no answer in time is later', () async {
      final (a, _, _) = api((_) async => http.Response('{}', 200));
      final failing = MockClient((_) async => throw const SocketException('x'));
      expect(
        await httpTelemetrySender(a, client: failing)(batch),
        TelemetrySendResult.later,
      );
      final slow = MockClient(
        (_) => Future.delayed(
          const Duration(milliseconds: 50),
          () => http.Response('{}', 200),
        ),
      );
      expect(
        await httpTelemetrySender(
          a,
          client: slow,
          timeout: const Duration(milliseconds: 5),
        )(batch),
        TelemetrySendResult.later,
      );
    });
  });

  test('ids are random version 4 UUIDs from the given source', () {
    final a = Telemetry(random: math.Random(1));
    final b = Telemetry(random: math.Random(1));
    expect(a.sessionId, b.sessionId);
    expect(a.sessionId, matches(uuid));
  });

  group('the setup and matching rules', () {
    OnlineBattleSession session({String? friendId}) => OnlineBattleSession(
      endpoint: Uri.parse('wss://example.com/ws'),
      accessToken: 'test-only',
      character: 'bear',
      exercise: ExerciseType.squat,
    )..friendId = friendId;

    Map<String, Object?> end(Telemetry t) => t.pending.last;

    test('a bot setup has no limit; ready keeps the last thing asked for', () {
      final t = Telemetry();
      final setup = SetupTelemetry.bot(t, ExerciseType.pushUp)
        ..saw(SetupReason.tooFar)
        ..saw(SetupReason.ready)
        ..saw(null);
      expect(t.pending.single['mode'], 'bot');
      setup
        ..ready()
        ..cancelled();
      expect(t.pending, hasLength(2));
      expect(end(t)['result'], 'ready');
      expect(end(t)['limit_ms'], isNull);
      expect(end(t)['last_reason'], 'too_far');
    });

    test('an online setup is ready once the start is set, with the setup '
        'time as its limit', () {
      final t = Telemetry();
      final s = session(friendId: '7');
      final setup = SetupTelemetry.online(t, s);
      expect(t.pending.single['mode'], 'friend');
      expect(t.pending.single['exercise'], 'squat');
      setup.follow(s);
      expect(setup.finished, isFalse);
      s.startAtMs = 1000;
      setup.follow(s);
      expect(end(t)['result'], 'ready');
      expect(end(t)['limit_ms'], 10000);
      expect(end(t)['last_reason'], isNull);
    });

    for (final (reason, result) in [
      ('setup_timeout', 'timeout'),
      ('ready_timeout', 'timeout'),
      ('user_exit', 'cancelled'),
      ('disconnected_before_start', 'cancelled'),
    ]) {
      test('an online setup cancelled with $reason is $result', () {
        final t = Telemetry();
        final s = session();
        final setup = SetupTelemetry.online(t, s);
        s
          ..phase = OnlinePhase.cancelled
          ..result = {'reason': reason};
        setup.follow(s);
        expect(end(t)['result'], result);
        expect(t.pending.first['mode'], 'main');
      });
    }

    test('without telemetry the rules record nothing and never fail', () {
      final setup = SetupTelemetry.bot(null, ExerciseType.squat)..ready();
      expect(setup.finished, isTrue);
      MatchingTelemetry(null, exercise: ExerciseType.squat, friend: false)
        ..follow(session()..phase = OnlinePhase.queued)
        ..stopped();
    });

    test('matching starts at the first queued state only, so a reconnect '
        'does not start another; an opponent ends it found', () {
      final t = Telemetry();
      final s = session();
      final matching = MatchingTelemetry(
        t,
        exercise: ExerciseType.pushUp,
        friend: false,
      );
      matching.follow(s);
      expect(t.pending, isEmpty);
      s.phase = OnlinePhase.queued;
      matching.follow(s);
      expect(matching.searching, isTrue);
      s.phase = OnlinePhase.connecting;
      matching.follow(s);
      s.phase = OnlinePhase.queued;
      matching.follow(s);
      expect(t.pending.single['event'], 'matching_started');
      expect(t.pending.single['kind'], 'main');
      s.opponent = const OnlinePlayer('o', '상대', 'seal');
      matching
        ..follow(s)
        ..stopped();
      expect(end(t)['result'], 'found');
      expect(t.pending, hasLength(2));
      expect(matching.searching, isFalse);
    });

    test('a search that ends without an opponent is an error', () {
      final t = Telemetry();
      final s = session()..phase = OnlinePhase.queued;
      final matching = MatchingTelemetry(
        t,
        exercise: ExerciseType.pushUp,
        friend: false,
      )..follow(s);
      s.phase = OnlinePhase.failed;
      matching.follow(s);
      expect(end(t)['result'], 'error');
    });

    for (final (status, result) in [
      (null, 'error'),
      (InviteStatus.declined, 'cancelled'),
      (InviteStatus.cancelled, 'cancelled'),
      (InviteStatus.expired, 'timeout'),
      (InviteStatus.pending, 'timeout'),
      (InviteStatus.accepted, 'timeout'),
    ]) {
      test('a friend invite ending as $status is $result', () {
        final t = Telemetry();
        MatchingTelemetry(t, exercise: ExerciseType.squat, friend: true)
          ..follow(session()..phase = OnlinePhase.queued)
          ..inviteEnded(status);
        expect(t.pending.first['kind'], 'friend');
        expect(end(t)['result'], result);
      });
    }

    test('the login running out is an error; stopping is cancelled', () {
      final t = Telemetry();
      MatchingTelemetry(t, exercise: ExerciseType.squat, friend: false)
        ..follow(session()..phase = OnlinePhase.queued)
        ..failed();
      expect(end(t)['result'], 'error');
      MatchingTelemetry(t, exercise: ExerciseType.squat, friend: false)
        ..follow(session()..phase = OnlinePhase.queued)
        ..stopped();
      expect(end(t)['result'], 'cancelled');
    });
  });
}
