import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/online/pose_wire.dart';

// Sibling standalone server is intentionally exercised through real sockets.
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/battle_server.dart';

// The same library the server imports: by package: it would be another type.
// ignore: avoid_relative_lib_imports
import '../../../lib/models/battle_rules.dart';

import 'package:gymrats_app/shared/battle_protocol.dart';

Future<void> until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsedMilliseconds > 5000) {
      throw TimeoutException('state not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class Wire {
  static int nextConnection = 0;
  final prefix = 'wire-${nextConnection++}';
  Wire(this.socket) {
    socket.listen(
      (raw) => events.add(
        Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
      ),
    );
  }
  final WebSocket socket;
  final events = <Map<String, dynamic>>[];
  int cursor = 0, sequence = 0;
  String? match;
  static Future<Wire> open(BattleServer server, String token) async {
    final wire = Wire(
      await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/ws/v1/battle',
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    await wire.next('session.welcome');
    return wire;
  }

  Map<String, dynamic> send(
    String type,
    Map<String, dynamic> payload, {
    String? rid,
  }) {
    final message = {
      'v': 1,
      'type': type,
      if (type != 'pose.frame') 'request_id': rid ?? '$prefix-r${++sequence}',
      if (match != null) 'match_id': match,
      'payload': payload,
    };
    socket.add(jsonEncode(message));
    return message;
  }

  Future<Map<String, dynamic>> next(String type) async {
    int index() => events.indexWhere((e) => e['type'] == type, cursor);
    try {
      await until(() => index() >= 0);
    } catch (_) {
      throw StateError(
        'Waiting for $type; received ${events.map((e) => e['type']).toList()}',
      );
    }
    final found = index();
    cursor = found + 1;
    return events[found];
  }

  Future<void> close() => socket.close();
}

void main() {
  test('production battle server defaults to thirty seconds', () async {
    final s = BattleServer(authenticate: (_) => null);
    expect(s.durationMs, 30000);
    await s.close();
  });
  Future<BattleServer> server({
    int duration = 1500,
    int reconnect = 300,
    int ready = 1000,
    BattleRules rules = battleRules,
  }) async {
    final s = BattleServer(
      authenticate: (token) => switch (token) {
        'alpha' => const BattleIdentity('a', 'Alpha'),
        'beta' => const BattleIdentity('b', 'Beta'),
        'third' => const BattleIdentity('c', 'Third'),
        'fourth' => const BattleIdentity('d', 'Fourth'),
        _ => null,
      },
      durationMs: duration,
      countdownMs: 80,
      readyTimeoutMs: ready,
      reconnectMs: reconnect,
      rules: rules,
    );
    await s.start();
    addTearDown(s.close);
    return s;
  }

  test(
    'rejected login token stops connection without retrying as another user',
    () async {
      final s = await server();
      final session = OnlineBattleSession(
        endpoint: Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle'),
        accessToken: 'invalid-token',
        avatar: AvatarModel.astronaut,
        allowInsecureLoopback: true,
      );
      addTearDown(session.dispose);
      await session.connect();
      expect(session.authenticationRejected, isTrue);
      expect(session.phase, OnlinePhase.failed);
      expect(session.connected, isFalse);
      expect(session.playerId, isNull);
    },
  );

  Future<(Wire, Wire)> paired(BattleServer s) async {
    final a = await Wire.open(s, 'alpha'), b = await Wire.open(s, 'beta');
    addTearDown(a.close);
    addTearDown(b.close);
    a.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_02'});
    b.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_04'});
    final found = await a.next('match.found');
    await b.next('match.found');
    a.match = b.match = found['match_id'] as String;
    return (a, b);
  }

  Future<void> ready(Wire a, Wire b) async {
    a.send('match.ready', {'ready': true});
    b.send('match.ready', {'ready': true});
    final x = await a.next('match.start'), y = await b.next('match.start');
    expect(x['payload'], y['payload']);
    await Future<void>.delayed(const Duration(milliseconds: 110));
  }

  Future<void> joinQueue(Wire wire) async {
    wire.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_01'});
    await wire.next('queue.joined');
  }

  List<String> rosterIds(Map<String, dynamic> found) =>
      (found['payload']['players'] as List)
          .map((p) => p['player_id'] as String)
          .toList();

  group('the game on the server', () {
    Map<String, dynamic> rep(
      int seq,
      int elapsed, {
      String? grade,
      String? reason,
    }) => {
      'rep_seq': seq,
      'elapsed_ms': elapsed,
      'valid': reason == null,
      'reason': reason,
      'grade': ?grade,
    };

    Map<String, dynamic> player(Map<String, dynamic> finished, String id) =>
        (finished['payload']['players'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['player_id'] == id);

    test('match.found names the fever start and the KO lead', () async {
      final s = await server();
      final (a, b) = await paired(s);
      for (final wire in [a, b]) {
        final found = wire.events.firstWhere((e) => e['type'] == 'match.found');
        expect(found['payload']['fever_start_ms'], 20000);
        expect(found['payload']['ko_lead'], 100);
      }
    });

    test('points, combo, and the grade reach both players', () async {
      final s = await server();
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10, grade: 'good'));
      final first = (await a.next('rep.accepted'))['payload'];
      expect(first['points'], 10);
      expect(first['combo'], 1);
      expect(first['game_score'], 10);

      a.send('rep.submit', rep(2, 20, grade: 'excellent'));
      final second = (await a.next('rep.accepted'))['payload'];
      expect(second['points'], 20);
      expect(second['combo'], 2);
      expect(second['game_score'], 30);

      await b.next('rep.updated');
      final seen = (await b.next('rep.updated'))['payload'];
      expect(seen['player_id'], 'a');
      expect(seen['grade'], 'excellent');
      expect(seen['combo'], 2);
      expect(seen['points'], 20);
      expect(seen['game_score'], 30);
      expect(seen['valid_reps'], 2);
    });

    test('no grade counts as good; a rejected rep breaks the combo', () async {
      final s = await server();
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10));
      expect((await a.next('rep.accepted'))['payload']['game_score'], 10);

      a.send('rep.submit', rep(2, 20, reason: 'insufficient_depth'));
      final rejected = (await a.next('rep.accepted'))['payload'];
      expect(rejected['points'], 0);
      expect(rejected['combo'], 0);
      expect(rejected['game_score'], 10);

      a.send('rep.submit', rep(3, 30));
      final next = (await a.next('rep.accepted'))['payload'];
      expect(next['points'], 10);
      expect(next['combo'], 1);
    });

    test('a bad grade, or a grade on a rejected rep, is refused', () async {
      final s = await server();
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10, grade: 'perfect'));
      expect((await a.next('error'))['payload']['code'], 'INVALID_PAYLOAD');
      a.send('rep.submit', rep(1, 10, grade: 'good', reason: 'too_fast'));
      expect((await a.next('error'))['payload']['code'], 'INVALID_PAYLOAD');
      a.send('rep.submit', rep(1, 10, grade: 'good'));
      expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    });

    test('a rep from the fever start on scores double', () async {
      final s = await server(
        rules: const BattleRules(feverStart: Duration(milliseconds: 100)),
      );
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 99));
      expect((await a.next('rep.accepted'))['payload']['points'], 10);
      b.send('rep.submit', rep(1, 100));
      expect((await b.next('rep.accepted'))['payload']['points'], 20);
    });

    test('a sent-again rep does not score twice', () async {
      final s = await server();
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10), rid: 'first');
      expect((await a.next('rep.accepted'))['payload']['game_score'], 10);
      a.send('rep.submit', rep(1, 10), rid: 'again');
      expect((await a.next('rep.accepted'))['payload']['game_score'], 10);
    });

    test('at time up the game score decides, not the reps', () async {
      final s = await server(
        duration: 400,
        rules: const BattleRules(excellentPoints: 50),
      );
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10, grade: 'excellent'));
      await a.next('rep.accepted');
      b.send('rep.submit', rep(1, 10));
      await b.next('rep.accepted');
      b.send('rep.submit', rep(2, 20));
      await b.next('rep.accepted');

      final finished = await a.next('match.finished');
      expect(finished['payload']['reason'], 'time_up');
      expect(finished['payload']['winner_id'], 'a');
      expect(player(finished, 'a')['game_score'], 50);
      expect(player(finished, 'a')['valid_reps'], 1);
      expect(player(finished, 'b')['game_score'], 25);
      expect(player(finished, 'b')['outcome'], 'loss');
    });

    test('the same game score goes to more valid reps', () async {
      final s = await server(
        duration: 400,
        rules: const BattleRules(excellentPoints: 25),
      );
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10, grade: 'excellent'));
      await a.next('rep.accepted');
      b.send('rep.submit', rep(1, 10));
      await b.next('rep.accepted');
      b.send('rep.submit', rep(2, 20));
      await b.next('rep.accepted');
      final finished = await a.next('match.finished');
      expect(player(finished, 'a')['game_score'], 25);
      expect(player(finished, 'b')['game_score'], 25);
      expect(finished['payload']['winner_id'], 'b');
    });

    test('the same game score and reps are a draw', () async {
      final s = await server(duration: 400);
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10));
      await a.next('rep.accepted');
      b.send('rep.submit', rep(1, 10));
      await b.next('rep.accepted');
      final finished = await a.next('match.finished');
      expect(finished['payload']['winner_id'], isNull);
      expect(player(finished, 'a')['outcome'], 'draw');
    });

    test('a KO ends the match at once, after the ACK, for both', () async {
      final s = await server(
        duration: 5000,
        rules: const BattleRules(koLead: 20),
      );
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10));
      await a.next('rep.accepted');
      a.send('rep.submit', rep(2, 20));
      expect((await a.next('rep.accepted'))['payload']['game_score'], 25);

      final finished = await a.next('match.finished');
      expect(finished['payload']['reason'], 'ko');
      expect(finished['payload']['winner_id'], 'a');
      expect(player(finished, 'a')['game_score'], 25);
      expect(player(finished, 'b')['outcome'], 'loss');
      await b.next('rep.updated');
      await b.next('rep.updated');
      expect((await b.next('match.finished'))['payload']['reason'], 'ko');

      b.send('rep.submit', rep(1, 30));
      expect((await b.next('error'))['payload']['code'], 'INVALID_STATE');
    });

    test('the KO rep sent again after the end gets its first ACK', () async {
      final s = await server(
        duration: 5000,
        rules: const BattleRules(koLead: 10),
      );
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10));
      final first = (await a.next('rep.accepted'))['payload'];
      await a.next('match.finished');

      a.send('rep.submit', rep(1, 10));
      expect((await a.next('rep.accepted'))['payload'], first);
      expect(
        a.events.where((e) => e['type'] == 'match.finished'),
        hasLength(1),
      );
    });

    test('the same rep with another grade is a conflict', () async {
      final s = await server();
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10, grade: 'good'));
      await a.next('rep.accepted');
      a.send('rep.submit', rep(1, 10, grade: 'excellent'));
      expect((await a.next('error'))['payload']['code'], 'REP_CONFLICT');
    });

    test('the snapshot restores the game score', () async {
      final s = await server(duration: 3000);
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', rep(1, 10, grade: 'excellent'));
      await a.next('rep.accepted');
      a.send('match.resume', {});
      final snapshot = (await a.next('match.snapshot'))['payload'];
      expect(snapshot['scores']['a']['game_score'], 15);
      expect(snapshot['scores']['b']['game_score'], 0);
      expect(snapshot['fever_start_ms'], 20000);
      expect(snapshot['ko_lead'], 100);
    });
  });

  test(
    'all catalog avatars can match and appear on the opponent client',
    () async {
      for (final avatar in AvatarModel.values) {
        final s = BattleServer(
          authenticate: (token) => token == 'alpha'
              ? const BattleIdentity('a', 'Alpha')
              : const BattleIdentity('b', 'Beta'),
          readyTimeoutMs: 10000,
        );
        await s.start();
        final endpoint = Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle');
        final a = OnlineBattleSession(
          endpoint: endpoint,
          accessToken: 'alpha',
          avatar: avatar,
          allowInsecureLoopback: true,
        );
        final b = OnlineBattleSession(
          endpoint: endpoint,
          accessToken: 'beta',
          avatar: AvatarModel.robot,
          allowInsecureLoopback: true,
        );
        try {
          await a.connect();
          await until(() => a.phase == OnlinePhase.queued);
          await b.connect();
          await until(
            () =>
                a.phase == OnlinePhase.preparing &&
                b.phase == OnlinePhase.preparing,
          );
          expect(b.opponent!.avatar, avatar);
          expect(a.error, isNull);
          await a.leave();
          await until(() => b.terminal);
        } finally {
          a.dispose();
          b.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await s.close();
        }
      }
    },
  );

  test('FIFO pairs by queue arrival, not connection order', () async {
    final s = await server(ready: 10000);
    final a = await Wire.open(s, 'alpha');
    final b = await Wire.open(s, 'beta');
    final c = await Wire.open(s, 'third');
    final d = await Wire.open(s, 'fourth');
    for (final wire in [a, b, c, d]) {
      addTearDown(wire.close);
    }
    // Reverse socket order deliberately: C,D must pair, then B,A.
    await joinQueue(c);
    expect(c.events.where((e) => e['type'] == 'match.found'), isEmpty);
    await joinQueue(d);
    final first = await c.next('match.found');
    expect(rosterIds(first), ['c', 'd']);
    expect((await d.next('match.found'))['match_id'], first['match_id']);
    await joinQueue(b);
    await joinQueue(a);
    final second = await b.next('match.found');
    expect(rosterIds(second), ['b', 'a']);
    expect((await a.next('match.found'))['match_id'], second['match_id']);
    expect(second['match_id'], isNot(first['match_id']));
  });

  test(
    'FIFO excludes cancelled waiters and rejoin starts a new queue entry',
    () async {
      final s = await server();
      final a = await Wire.open(s, 'alpha');
      final b = await Wire.open(s, 'beta');
      final c = await Wire.open(s, 'third');
      for (final wire in [a, b, c]) {
        addTearDown(wire.close);
      }
      await joinQueue(a);
      a.send('queue.cancel', {'queue_id': 'a'});
      await a.next('queue.cancelled');
      await joinQueue(b);
      await joinQueue(a);
      expect(rosterIds(await b.next('match.found')), ['b', 'a']);
      await a.next('match.found');
      await joinQueue(c);
      expect(c.events.where((e) => e['type'] == 'match.found'), isEmpty);
    },
  );

  test(
    'FIFO removes disconnected waiters before matching the next player',
    () async {
      final s = await server();
      final a = await Wire.open(s, 'alpha');
      await joinQueue(a);
      await a.close();
      // Open subsequent clients only after the first socket has closed.
      final b = await Wire.open(s, 'beta');
      final c = await Wire.open(s, 'third');
      addTearDown(b.close);
      addTearDown(c.close);
      await joinQueue(b);
      await joinQueue(c);
      expect(rosterIds(await b.next('match.found')), ['b', 'c']);
      await c.next('match.found');
      expect(a.events.where((e) => e['type'] == 'match.found'), isEmpty);
    },
  );

  test(
    'pose wire preserves aspect, z and screen movement; rejects image fields',
    () {
      const frame = PoseFrame(
        imageWidth: 480,
        imageHeight: 640,
        keypoints: {
          BodyLandmark.leftElbow: Keypoint(
            landmark: BodyLandmark.leftElbow,
            x: 240,
            y: 320,
            z: -24,
            likelihood: .9,
          ),
        },
      );
      final packet = encodeBattlePose(frame, sequence: 1, elapsedMs: 20),
          decoded = decodeBattlePose(packet);
      expect(decoded.imageWidth / decoded.imageHeight, .75);
      final elbow = decoded[BodyLandmark.leftElbow]!;
      expect(elbow.x / decoded.imageWidth, .5);
      expect(elbow.y / decoded.imageHeight, .5);
      expect(elbow.z / decoded.imageWidth, -.05);
      expect(
        () => checkedPose({...packet, 'image': 'not-allowed'}),
        throwsA(isA<BattleProtocolError>()),
      );
      expect(
        () => checkedPose({
          ...packet,
          'joints': [
            [13, 0, 0, 0, 1],
            [13, 0, 0, 0, 1],
          ],
        }),
        throwsA(isA<BattleProtocolError>()),
      );
      expect(
        () => checkedPose({
          ...packet,
          'joints': [
            [13, double.nan, 0, 0, 1],
          ],
        }),
        throwsA(isA<BattleProtocolError>()),
      );
      expect(
        encodeBattlePose(null, sequence: 2, elapsedMs: 30)['has_person'],
        false,
      );
    },
  );
  test('authentication required and unknown avatar rejected', () async {
    final s = await server();
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:${s.port}/ws/v1/battle'),
      throwsA(isA<WebSocketException>()),
    );
    final a = await Wire.open(s, 'alpha');
    addTearDown(a.close);
    a.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'evil-url'});
    expect((await a.next('error'))['payload']['code'], 'INVALID_AVATAR');
  });
  test('server deduplicates verdicts, rejects conflicts, relays only pose whitelist', () async {
    final s = await server();
    final (a, b) = await paired(s);
    await ready(a, b);
    final rep = {
      'rep_seq': 1,
      'elapsed_ms': 120,
      'valid': true,
      'reason': null,
    };
    final original = a.send('rep.submit', rep, rid: 'rep-first');
    expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    await b.next('rep.updated');
    a.socket.add(jsonEncode(original));
    expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    a.socket.add(
      jsonEncode({
        for (final key in original.keys.toList().reversed) key: original[key],
      }),
    );
    expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    a.send('rep.submit', rep, rid: 'rep-replay');
    expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    a.send('rep.submit', {
      ...rep,
      'valid': false,
      'reason': 'too_fast',
    }, rid: 'conflict');
    expect((await a.next('error'))['payload']['code'], 'REP_CONFLICT');
    a.send('rep.submit', {...rep, 'rep_seq': 3}, rid: 'out-of-order');
    expect((await a.next('error'))['payload']['code'], 'REP_OUT_OF_ORDER');
    a.send('rep.submit', {...rep, 'rep_seq': 2}, rid: 'rep-first');
    expect((await a.next('error'))['payload']['code'], 'REQUEST_ID_REUSED');
    final pose = {
      'frame_seq': 1,
      'elapsed_ms': 130,
      'aspect_ratio': .75,
      'has_person': true,
      'joints': [
        [13, .4, .5, -.1, .9],
      ],
    };
    a.send('pose.frame', pose);
    final received = await b.next('pose.frame');
    expect(received['payload']['player_id'], 'a');
    expect(received['payload']['joints'], pose['joints']);
    a.send('pose.frame', {...pose, 'frame_seq': 2, 'video': 'forbidden'});
    expect((await a.next('error'))['payload']['code'], 'INVALID_PAYLOAD');
    final result = await b.next('match.finished');
    expect(result['payload']['winner_id'], 'a');
    expect((result['payload']['players'] as List).first['valid_reps'], 1);
  });
  test(
    'ready timeout cancels; leaving preparation never fabricates a win',
    () async {
      final s = await server(ready: 150);
      final (a, b) = await paired(s);
      expect(
        (await a.next('match.cancelled'))['payload']['reason'],
        'ready_timeout',
      );
      expect(
        (await b.next('match.cancelled'))['payload'].containsKey('winner_id'),
        false,
      );
    },
  );
  test(
    'disconnect grace resumes and snapshot restores accepted score',
    () async {
      final s = await server(duration: 2000, reconnect: 800);
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', {
        'rep_seq': 1,
        'elapsed_ms': 120,
        'valid': true,
        'reason': null,
      });
      await a.next('rep.accepted');
      await a.close();
      expect(
        (await b.next('match.connection_state'))['payload']['state'],
        'disconnected',
      );
      final again = await Wire.open(s, 'alpha');
      addTearDown(again.close);
      again.match = a.match;
      again.send('match.resume', {});
      final snapshot = (await again.next('match.snapshot'))['payload'];
      expect(snapshot['scores']['a']['valid_reps'], 1);
      expect(
        (await b.next('match.connection_state'))['payload']['state'],
        'reconnected',
      );
      again.send('match.leave', {'reason': 'user_exit'});
      expect((await b.next('match.finished'))['payload']['winner_id'], 'b');
    },
  );
  test(
    'one lost connection forfeits, two lost connections void rather than win',
    () async {
      final s = await server(duration: 2000);
      final (a, b) = await paired(s);
      await ready(a, b);
      await a.close();
      expect(
        (await b.next('match.finished'))['payload']['reason'],
        'disconnect_timeout',
      );
      expect(
        b.events.lastWhere(
          (e) => e['type'] == 'match.finished',
        )['payload']['winner_id'],
        'b',
      );
      // New match after final result; queued session state is cleared by join.
      final again = await Wire.open(s, 'alpha');
      addTearDown(again.close);
      again.send('queue.join', {
        'exercise': 'push_up',
        'avatar_id': 'avatar_01',
      });
      b.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_02'});
      again.match = (await again.next('match.found'))['match_id'] as String;
      b.match = (await b.next('match.found'))['match_id'] as String;
      await ready(again, b);
      await again.close();
      await b.close();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final resumed = await Wire.open(s, 'alpha');
      addTearDown(resumed.close);
      resumed.match = again.match;
      resumed.send('match.resume', {});
      final p = (await resumed.next('match.snapshot'))['payload'];
      expect(p['status'], 'void');
      expect(p['result']['reason'], 'both_disconnected');
      expect(p['result'].containsKey('winner_id'), false);
    },
  );
  test('two real Flutter sessions match, exchange avatar pose and use server result', () async {
    final s = await server(duration: 1800);
    final uri = Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle');
    final a = OnlineBattleSession(
          endpoint: uri,
          accessToken: 'alpha',
          avatar: AvatarModel.robot,
          allowInsecureLoopback: true,
        ),
        b = OnlineBattleSession(
          endpoint: uri,
          accessToken: 'beta',
          avatar: AvatarModel.humanoid,
          allowInsecureLoopback: true,
        );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.connect();
    await b.connect();
    await until(
      () =>
          a.phase == OnlinePhase.preparing && b.phase == OnlinePhase.preparing,
    );
    expect(a.opponent!.avatar, AvatarModel.humanoid);
    expect(b.opponent!.avatar, AvatarModel.robot);
    a.ready(true);
    b.ready(true);
    await until(() => a.roundRunning && b.roundRunning);
    const frame = PoseFrame(
      imageWidth: 480,
      imageHeight: 640,
      keypoints: {
        BodyLandmark.leftElbow: Keypoint(
          landmark: BodyLandmark.leftElbow,
          x: 200,
          y: 300,
          z: -10,
          likelihood: .9,
        ),
      },
    );
    a.publishPose(frame);
    await until(() => b.opponentFrame != null);
    expect(b.opponentFrame![BodyLandmark.leftElbow]!.likelihood, .9);
    a.submitRep(const RepEvent(index: 99, valid: true, at: Duration.zero));
    await until(() => b.opponentReps == 1 && a.myReps == 1);
    var rejected = 0;
    for (final reason in RejectReason.values) {
      a.submitRep(
        RepEvent(
          index: 100 + rejected,
          valid: false,
          reason: reason,
          at: Duration.zero,
        ),
      );
      rejected++;
      await until(() => a.myInvalidReps == rejected);
      expect(a.error, isNull, reason: 'Server must accept ${reason.name}');
    }
    await until(
      () => b.opponentFrame == null,
    ); // no new camera frame → clear stale pose
    await until(
      () => a.phase == OnlinePhase.finished && b.phase == OnlinePhase.finished,
    );
    expect(a.outcome, 'win');
    expect(b.outcome, 'loss');
    expect(a.result!['result_id'], b.result!['result_id']);
  });
  group('the game on the phones', () {
    const deep = RepEvent(
      index: 1,
      valid: true,
      at: Duration.zero,
      maxDepth: 1.9,
    );
    const normal = RepEvent(
      index: 2,
      valid: true,
      at: Duration.zero,
      maxDepth: 1.4,
    );

    Future<(OnlineBattleSession, OnlineBattleSession)> playing(
      BattleServer s,
    ) async {
      OnlineBattleSession open(String token) {
        final session = OnlineBattleSession(
          endpoint: Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle'),
          accessToken: token,
          avatar: AvatarModel.robot,
          allowInsecureLoopback: true,
        );
        addTearDown(session.dispose);
        return session;
      }

      final a = open('alpha'), b = open('beta');
      await a.connect();
      await b.connect();
      await until(
        () =>
            a.phase == OnlinePhase.preparing &&
            b.phase == OnlinePhase.preparing,
      );
      a.ready(true);
      b.ready(true);
      await until(() => a.roundRunning && b.roundRunning);
      return (a, b);
    }

    test('the phones read the rules from the server', () async {
      final s = await server(
        duration: 5000,
        rules: const BattleRules(feverStart: Duration(seconds: 3), koLead: 70),
      );
      final (a, b) = await playing(s);
      for (final session in [a, b]) {
        expect(session.rules!.feverStart, const Duration(seconds: 3));
        expect(session.rules!.koLead, 70);
        expect(session.fever, isFalse);
        expect(session.myBarShare, .5);
      }
    });

    test('both phones show the same score, the bar mirrored, and +N with its '
        'grade; a deep rep goes as excellent', () async {
      final s = await server(duration: 3000);
      final (a, b) = await playing(s);
      a.submitRep(deep);
      await until(() => a.myScore == 15 && b.opponentScore == 15);
      expect(a.myLastScore!.grade.name, 'excellent');
      expect(a.myLastScore!.points, 15);
      expect(a.myLastScore!.combo, 1);
      expect(a.myLastScore!.fever, isFalse);
      expect(b.opponentLastScore!.grade.name, 'excellent');
      expect(b.opponentLastScore!.points, 15);
      b.submitRep(normal);
      await until(() => b.myScore == 10 && a.opponentScore == 10);
      expect(b.myLastScore!.grade.name, 'good');
      expect(a.opponentLastScore!.grade.name, 'good');
      expect(a.myBarShare, closeTo(.525, 1e-9));
      expect(b.myBarShare, closeTo(.475, 1e-9));
      await until(
        () =>
            a.phase == OnlinePhase.finished && b.phase == OnlinePhase.finished,
      );
      expect(a.myScore, 15);
      expect(a.opponentScore, 10);
      expect(b.myScore, 10);
      expect(b.opponentScore, 15);
      expect(a.outcome, 'win');
      expect(b.outcome, 'loss');
    });

    test('a combo reaches the phones; a rejected rep sends no grade and is '
        'accepted', () async {
      final s = await server(duration: 5000);
      final (a, b) = await playing(s);
      a.submitRep(normal);
      a.submitRep(normal);
      await until(() => a.myScore == 25 && b.opponentScore == 25);
      expect(a.myLastScore!.combo, 2);
      expect(a.myLastScore!.points, 15);
      final last = a.myLastScore;
      a.submitRep(
        const RepEvent(
          index: 3,
          valid: false,
          at: Duration.zero,
          reason: RejectReason.insufficientDepth,
        ),
      );
      await until(() => a.myInvalidReps == 1);
      expect(a.error, isNull);
      expect(a.myScore, 25);
      expect(a.myLastScore, same(last));
    });

    test('fever doubles the points on both phones', () async {
      final s = await server(
        duration: 5000,
        rules: const BattleRules(feverStart: Duration.zero),
      );
      final (a, b) = await playing(s);
      expect(a.fever, isTrue);
      a.submitRep(normal);
      await until(() => a.myScore == 20 && b.opponentScore == 20);
      expect(a.myLastScore!.fever, isTrue);
      expect(b.opponentLastScore!.fever, isTrue);
    });

    test('danger is on for the one far behind, and the same score on both '
        'phones ends in a KO with the same winner', () async {
      final s = await server(
        duration: 5000,
        rules: const BattleRules(excellentPoints: 60, koLead: 100),
      );
      final (a, b) = await playing(s);
      a.submitRep(deep);
      await until(() => a.myScore == 60 && b.opponentScore == 60);
      expect(b.inDanger, isTrue);
      expect(a.inDanger, isFalse);
      a.submitRep(deep);
      await until(
        () =>
            a.phase == OnlinePhase.finished && b.phase == OnlinePhase.finished,
      );
      expect(a.result!['reason'], 'ko');
      expect(b.result!['reason'], 'ko');
      expect(a.result!['result_id'], b.result!['result_id']);
      expect(a.outcome, 'win');
      expect(b.outcome, 'loss');
      // 120 or 125: whether the second rep made the combo depends on timing.
      expect(a.myScore, greaterThanOrEqualTo(120));
      expect(b.opponentScore, a.myScore);
      expect(a.myBarShare, 1);
      expect(b.myBarShare, 0);
      expect(a.error, isNull);
    });

    /// A phone on a hand-written server: [answer] replies to each of its
    /// messages. The phone is player a; every message carries match m.
    Future<OnlineBattleSession> scripted(
      void Function(
        String type,
        Map<String, dynamic> payload,
        void Function(String type, Map<String, dynamic> payload) send,
      )
      answer,
    ) async {
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => http.close(force: true));
      http.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        addTearDown(socket.close);
        void send(String type, Map<String, dynamic> payload) => socket.add(
          jsonEncode({
            'v': 1,
            'type': type,
            'server_time_ms': DateTime.now().millisecondsSinceEpoch,
            if (type != 'session.welcome') 'match_id': 'm',
            'payload': payload,
          }),
        );
        send('session.welcome', {'player_id': 'a'});
        socket.listen((raw) {
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          answer(
            message['type'] as String,
            message['payload'] as Map<String, dynamic>,
            send,
          );
        });
      });
      final session = OnlineBattleSession(
        endpoint: Uri.parse('ws://127.0.0.1:${http.port}/ws/v1/battle'),
        accessToken: 'alpha',
        avatar: AvatarModel.robot,
        allowInsecureLoopback: true,
      );
      addTearDown(session.dispose);
      await session.connect();
      return session;
    }

    const players = [
      {'player_id': 'a', 'display_name': 'A', 'avatar_id': 'avatar_01'},
      {'player_id': 'b', 'display_name': 'B', 'avatar_id': 'avatar_02'},
    ];

    /// Times for a round that began a moment ago.
    Map<String, int> running() {
      final now = DateTime.now().millisecondsSinceEpoch;
      return {'start_at_ms': now - 100, 'end_at_ms': now + 29900};
    }

    test('the snapshot restores the rules and both scores', () async {
      final session = await scripted((type, _, send) {
        if (type != 'queue.join') return;
        // Without the rules, so they can come only from the snapshot.
        send('match.found', {'players': players, 'duration_ms': 30000});
        send('match.snapshot', {
          ...running(),
          'status': 'playing',
          'players': players,
          'duration_ms': 30000,
          'ready_player_ids': <String>[],
          'disconnected_player_ids': <String>[],
          'fever_start_ms': 20000,
          'ko_lead': 80,
          'scores': {
            'a': {
              'valid_reps': 1,
              'invalid_reps': 0,
              'game_score': 15,
              'last_rep_seq': 1,
            },
            'b': {
              'valid_reps': 4,
              'invalid_reps': 1,
              'game_score': 55,
              'last_rep_seq': 5,
            },
          },
        });
      });
      await until(() => session.phase == OnlinePhase.playing);
      expect(session.rules!.koLead, 80);
      expect(session.myScore, 15);
      expect(session.opponentScore, 55);
      expect(session.myBarShare, closeTo(.25, 1e-9));
      expect(session.error, isNull);
    });

    /// The opening a scripted server sends for a match with the game.
    void openGame(void Function(String, Map<String, dynamic>) send) {
      send('match.found', {
        'players': players,
        'duration_ms': 30000,
        'fever_start_ms': 20000,
        'ko_lead': 100,
      });
      send('match.start', running());
    }

    test('+N and its label show at once, before the server answers; the score '
        'and the bar wait for it', () async {
      final session = await scripted((type, _, send) {
        if (type == 'queue.join') openGame(send);
      });
      await until(() => session.roundRunning);
      session.submitRep(deep);
      final shown = session.myLastScore!;
      expect(shown.points, 15);
      expect(shown.grade.name, 'excellent');
      expect(shown.combo, 1);
      expect(session.myScore, 0);
      expect(session.myBarShare, .5);
      session.submitRep(normal);
      expect(session.myLastScore!.points, 15, reason: '10 + combo 5');
      expect(session.myLastScore!.combo, 2);
      session.submitRep(
        const RepEvent(
          index: 3,
          valid: false,
          at: Duration.zero,
          reason: RejectReason.insufficientDepth,
        ),
      );
      session.submitRep(normal);
      expect(
        session.myLastScore!.combo,
        1,
        reason: 'the rejected rep broke the combo',
      );
    });

    test(
      "the server's answer corrects the +N when the numbers differ",
      () async {
        final session = await scripted((type, payload, send) {
          if (type == 'queue.join') {
            openGame(send);
          } else if (type == 'rep.submit') {
            send('rep.accepted', {
              'rep_seq': payload['rep_seq'],
              'valid_reps': 1,
              'invalid_reps': 0,
              'combo': 3,
              'points': 30,
              'game_score': 30,
            });
          }
        });
        await until(() => session.roundRunning);
        session.submitRep(deep);
        expect(session.myLastScore!.points, 15);
        await until(() => session.myScore == 30);
        expect(session.myLastScore!.points, 30);
        expect(session.myLastScore!.combo, 3);
      },
    );

    test(
      'an answer with the same numbers keeps the +N, so it pops up once',
      () async {
        final session = await scripted((type, payload, send) {
          if (type == 'queue.join') {
            openGame(send);
          } else if (type == 'rep.submit') {
            send('rep.accepted', {
              'rep_seq': payload['rep_seq'],
              'valid_reps': 1,
              'invalid_reps': 0,
              'combo': 1,
              'points': 15,
              'game_score': 15,
            });
          }
        });
        await until(() => session.roundRunning);
        session.submitRep(deep);
        final shown = session.myLastScore;
        await until(() => session.myScore == 15);
        expect(session.myLastScore, same(shown));
      },
    );

    test(
      "an answer to an older rep leaves the latest rep's +N alone",
      () async {
        final session = await scripted((type, payload, send) {
          if (type == 'queue.join') {
            openGame(send);
          } else if (type == 'rep.submit' && payload['rep_seq'] == 2) {
            send('rep.accepted', {
              'rep_seq': 1,
              'valid_reps': 1,
              'invalid_reps': 0,
              'combo': 1,
              'points': 99,
              'game_score': 99,
            });
          }
        });
        await until(() => session.roundRunning);
        session.submitRep(deep);
        session.submitRep(normal);
        final shown = session.myLastScore;
        await until(() => session.myScore == 99);
        expect(session.myLastScore, same(shown));
      },
    );

    test('the final scores are the ones in the result; the clock stops at the '
        'end', () async {
      final session = await scripted((type, _, send) {
        if (type != 'queue.join') return;
        openGame(send);
        send('match.finished', {
          'reason': 'ko',
          'ended_at_ms': DateTime.now().millisecondsSinceEpoch + 5000,
          'players': [
            {
              'player_id': 'a',
              'valid_reps': 3,
              'invalid_reps': 1,
              'game_score': 70,
              'outcome': 'win',
            },
            {
              'player_id': 'b',
              'valid_reps': 2,
              'invalid_reps': 0,
              'game_score': 40,
              'outcome': 'loss',
            },
          ],
        });
      });
      await until(() => session.phase == OnlinePhase.finished);
      expect(session.myScore, 70);
      expect(session.opponentScore, 40);
      final left = session.remainingMs;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(session.remainingMs, left);
    });

    test('a second answer to a rep sent again is no new +N', () async {
      final session = await scripted((type, payload, send) {
        if (type == 'queue.join') {
          send('match.found', {
            'players': players,
            'duration_ms': 30000,
            'fever_start_ms': 20000,
            'ko_lead': 100,
          });
          send('match.start', running());
        } else if (type == 'rep.submit') {
          final answer = {
            'rep_seq': payload['rep_seq'],
            'valid_reps': 1,
            'invalid_reps': 0,
            'combo': 1,
            'points': 15,
            'game_score': 15,
          };
          send('rep.accepted', answer);
          // Other numbers, so reading this one as news would show.
          send('rep.accepted', {...answer, 'points': 99, 'game_score': 0});
        }
      });
      await until(() => session.roundRunning);
      session.submitRep(deep);
      await until(() => session.myReps == 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(session.myLastScore!.points, 15);
      expect(session.myScore, 15);
      expect(session.error, isNull);
    });

    test(
      'an older server gets no grade, and the session plays no game',
      () async {
        final submitted = <Map<String, dynamic>>[];
        final session = await scripted((type, payload, send) {
          if (type == 'queue.join') {
            send('match.found', {'players': players, 'duration_ms': 30000});
            send('match.start', running());
          } else if (type == 'rep.submit') {
            submitted.add(payload);
            send('rep.accepted', {
              'rep_seq': payload['rep_seq'],
              'valid_reps': 1,
              'invalid_reps': 0,
            });
            send('rep.updated', {'player_id': 'b', 'valid_reps': 2});
          }
        });
        await until(() => session.roundRunning);
        session.submitRep(deep);
        await until(() => session.myReps == 1 && session.opponentReps == 2);
        expect(submitted.single.containsKey('grade'), isFalse);
        expect(session.rules, isNull);
        expect(session.myScore, 0);
        expect(session.myLastScore, isNull);
        expect(session.fever, isFalse);
        expect(session.inDanger, isFalse);
        expect(session.myBarShare, .5);
        expect(session.error, isNull);
      },
    );
  });
  test(
    'client refuses insecure public endpoint without attempting a socket',
    () async {
      final session = OnlineBattleSession(
        endpoint: Uri.parse('ws://52.78.38.225/ws/v1/battle'),
        accessToken: 'not-sent',
        avatar: AvatarModel.astronaut,
        allowInsecureLoopback: true,
      );
      addTearDown(session.dispose);
      await session.connect();
      expect(session.phase, OnlinePhase.failed);
      expect(session.connected, false);
    },
  );
}
